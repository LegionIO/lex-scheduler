# frozen_string_literal: true

require 'legion/extensions/scheduler/helpers/schedule'
require 'legion/transport'
require 'legion/transport/messages/dynamic'
require 'legion/transport/messages/subtask'

module Legion
  module Extensions
    module Scheduler
      module Runners
        module Schedule
          extend self # rubocop:disable Style/ModuleFunction -- Client includes these public runner methods.

          include Legion::Extensions::Scheduler::Helpers::Schedule

          def schedule_tasks(now: Time.now, **)
            result = { success: true, recorded: 0, skipped: 0, errors: [] }
            models_class::Schedule.where(active: true).each do |row|
              schedule = row.values
              policy = schedule_policy(schedule: schedule)
              parsed = schedule_parse(schedule: schedule)
              schedule_due_times(schedule: schedule, parsed: parsed, policy: policy, now: now).each do |scheduled_at|
                skipped = policy[:misfire] == 'skip' && now - scheduled_at > settings[:misfire_grace_seconds]
                unless skipped
                  dispatched = send_task(function_id: schedule[:function_id],
                                         args: schedule_json_hash(value: schedule[:payload], field: :payload),
                                         context: schedule_json_hash(value: schedule[:context], field: :context),
                                         transformation: schedule[:transformation], expiration: schedule[:task_ttl])
                  models_class::ScheduleLog.create(schedule_id: schedule[:id], task_id: dispatched[:task][:id],
                                                   function_id: schedule[:function_id], success: nil, status: 'dispatched', created: now)
                end
                row.update(last_run: scheduled_at, updated: now)
                result[skipped ? :skipped : :recorded] += 1
              end
            rescue StandardError => e
              handle_exception(e, level: :error, handled: true, schedule_id: row.values[:id])
              result[:success] = false
              result[:errors] << { schedule_id: row.values[:id], error: e.message }
            end
            result
          end

          def send_task(function_id:, args: {}, context: {}, transformation: nil, expiration: nil, **)
            raise ArgumentError, 'args must be a Hash' unless args.is_a?(Hash)
            raise ArgumentError, 'context must be a Hash' unless context.is_a?(Hash)

            options = schedule_envelope(function_id: function_id, args: args, context: context,
                                        transformation: transformation, expiration: expiration)
            task = Legion::Data::Model::Task.create(schedule_task_values(options: options))
            options[:task_id] = task.values[:id]
            message_class = options.key?(:transformation) ? Legion::Transport::Messages::SubTask : Legion::Transport::Messages::Dynamic
            message_class.new(**options).publish!
            { success: true, task: task.values }
          end
        end
      end
    end
  end
end
