module Legion
  module Extensions
    module Scheduler
      module Runners
        module Schedule
          include Legion::Extensions::Helpers::Transport
          include Legion::Extensions::Helpers::Cache
          include Legion::Extensions::Helpers::Data

          include Legion::Extensions::Helpers::Lex
          def push_refresh(**)
            Legion::Extensions::Scheduler::Transport::Messages::Refresh.new.publish
          end

          def refresh(**)
            Legion::Cache.set('scheduler_schedule_lock', Legion::Settings[:client][:name], 5)
          end

          def schedule_tasks(**)
            return unless Legion::Cache.get('scheduler_schedule_lock') == Legion::Settings[:client][:name]

            models_class::Schedule.where(active: 1).each do |row|
              next unless row.values[:interval].positive?
              next if (Time.now - row.values[:last_run]) < row.values[:interval]

              send_task(function_id: row.values[:function_id], **Legion::JSON.load(row.values[:payload]))
              row.update(last_run: Sequel::CURRENT_TIMESTAMP)
            end
          end

          def send_task(**opts)
            payload = {}
            %i[runner_class function_id function debug args].each do |thing|
              payload[thing] = opts[thing] if opts.key? thing
            end

            Legion::Extensions::Scheduler::Transport::Messages::SendTask.new(**payload).publish
          end
        end
      end
    end
  end
end
