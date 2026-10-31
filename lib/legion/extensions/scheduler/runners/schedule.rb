# frozen_string_literal: true

require 'legion/extensions/scheduler/helpers/schedule'

module Legion
  module Extensions
    module Scheduler
      module Runners
        module Schedule
          extend self # -- Included helpers must also be callable on the runner module.
          include Legion::Extensions::Scheduler::Helpers::Schedule

          def schedule_tasks(now: Time.now, **)
            result = { success: true, recorded: 0, skipped: 0, errors: [] }
            models_class::Schedule.all.each do |row|
              counts = schedule_record_due(schedule: row.values, now: now)
              result[:recorded] += counts[:recorded]
              result[:skipped] += counts[:skipped]
            rescue StandardError => e
              handle_exception(e, level: :error, handled: true, schedule_id: row.values[:id])
              result[:success] = false
              result[:errors] << { schedule_id: row.values[:id], error: e.message }
            end
            result
          end

          def send_task(function_id:, idempotency_key:, args: {}, context: {}, transformation: nil, expiration: nil, **)
            raise ArgumentError, 'args must be a Hash' unless args.is_a?(Hash)
            raise ArgumentError, 'context must be a Hash' unless context.is_a?(Hash)

            options = schedule_envelope(function_id: function_id, args: args, context: context,
                                        transformation: transformation, expiration: expiration)
            task = Legion::Data::TaskExecution.create_task(
              values: schedule_task_values(options: options), idempotency_key: idempotency_key,
              dispatch: { event_key: "#{idempotency_key}:dispatch", message_type: schedule_message_type(options: options), options: options }
            )
            { success: true, created: task[:created], task: task[:task], status: settings[:occurrence_statuses][:recorded] }
          end

          private

          def schedule_record_due(schedule:, now:)
            counts = { recorded: 0, skipped: 0 }
            db = models_class::Schedule.db
            raise ArgumentError, 'scheduler and task storage must share a database' unless db.equal?(data_connection)

            transaction_options = db.database_type == :sqlite ? { mode: :immediate } : {}
            db.transaction(**transaction_options) do
              claimed = db[:schedules].where(id: schedule[:id], lock_version: schedule[:lock_version])
                                      .update(lock_version: schedule[:lock_version] + 1)
              next if claimed.zero?

              schedule = db[:schedules][id: schedule[:id]]
              latest = schedule_reconcile(schedule_id: schedule[:id], db: db)
              next unless schedule[:active]

              policy = schedule_policy(schedule: schedule)
              parsed = schedule_parse(schedule: schedule)
              next if policy[:overlap] == 'forbid' && schedule_outstanding?(schedule_id: schedule[:id], db: db)

              times = schedule_due_times(schedule: schedule, parsed: parsed, policy: policy, latest: latest, now: now)
              times.each do |scheduled_at|
                skipped = policy[:misfire] == 'skip' && now - scheduled_at > settings[:misfire_grace_seconds]
                schedule_record_occurrence(schedule: schedule, scheduled_at: scheduled_at, now: now, skipped: skipped, db: db)
                counts[skipped ? :skipped : :recorded] += 1
                break if !skipped && (policy[:overlap] == 'forbid' || policy[:basis] == 'completed')
              end
            end
            counts
          end

          def schedule_record_occurrence(schedule:, scheduled_at:, now:, skipped:, db:)
            key = "schedule:#{schedule[:id]}:#{schedule[:definition_version]}:#{scheduled_at.getutc.iso8601(6)}"
            return if db[:schedule_occurrences][occurrence_key: key]

            occurrence_id = db[:schedule_occurrences].insert(
              schedule_id: schedule[:id], occurrence_key: key, scheduled_at: scheduled_at, recorded_at: now,
              status: settings[:occurrence_statuses][skipped ? :skipped : :recorded]
            )
            unless skipped
              args = schedule_json_hash(value: schedule[:payload], field: :payload)
              context = schedule_json_hash(value: schedule[:context], field: :context)
              options = schedule_envelope(function_id: schedule[:function_id], args: args, context: context,
                                          transformation: schedule[:transformation], expiration: schedule[:task_ttl])
              options.merge!(schedule_id: schedule[:id], occurrence_id: occurrence_id, definition_version: schedule[:definition_version])
              task = Legion::Data::TaskExecution.create_task(values: schedule_task_values(options: options), idempotency_key: key)
              task_id = task[:task][:id]
              options[:task_id] = task_id
              Legion::Data::TaskExecution.enqueue_dispatch(event_key: "#{key}:dispatch", message_type: schedule_message_type(options: options),
                                                           options: options, task_id: task_id)
              db[:schedule_occurrences].where(id: occurrence_id).update(task_id: task_id)
              db[:schedule_logs].insert(schedule_id: schedule[:id], task_id: task_id, function_id: schedule[:function_id],
                                        success: nil, status: settings[:occurrence_statuses][:recorded], created: now)
            end
            db[:schedules].where(id: schedule[:id]).update(last_run: scheduled_at, updated: now)
            log.debug("Schedule #{schedule[:id]} occurrence #{occurrence_id} #{skipped ? 'skipped' : 'recorded; publication pending'}")
          end

          def schedule_reconcile(schedule_id:, db:)
            db[:schedule_occurrences].where(schedule_id: schedule_id, completed_at: nil).exclude(task_id: nil).each do |occurrence|
              updates = {}
              dispatch = db[:task_dispatches].where(task_id: occurrence[:task_id]).exclude(delivered_at: nil).first
              if dispatch && !occurrence[:delivered_at]
                updates[:delivered_at] = dispatch[:delivered_at]
                updates[:status] = settings[:occurrence_statuses][:delivered]
                log.debug("Schedule #{schedule_id} occurrence #{occurrence[:id]} delivered")
              end
              outcome = schedule_task_outcome(task_id: occurrence[:task_id], db: db, depth: 0)
              if outcome && (outcome[:completed_at] || occurrence[:status] != outcome[:status])
                updates[:completed_at] = outcome[:completed_at]
                updates[:status] = outcome[:status]
                db[:schedule_logs].insert(schedule_id: schedule_id, task_id: occurrence[:task_id], success: outcome[:success],
                                          status: outcome[:status], created: outcome[:completed_at] || Time.now)
                log.debug("Schedule #{schedule_id} occurrence #{occurrence[:id]} outcome #{outcome[:status]}")
              end
              db[:schedule_occurrences].where(id: occurrence[:id]).update(updates) unless updates.empty?
            end
            db[:schedule_occurrences].where(schedule_id: schedule_id).reverse_order(:scheduled_at, :id).first
          end
        end
      end
    end
  end
end
