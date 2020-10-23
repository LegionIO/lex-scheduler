require 'fugit'

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
            Legion::Cache.set('scheduler_schedule_lock', Legion::Settings[:client][:name], 2)
          end

          def schedule_tasks(**)
            return unless Legion::Cache.get('scheduler_schedule_lock') == Legion::Settings[:client][:name]

            models_class::Schedule.where(active: 1).each do |row|
              if row.values[:interval].is_a?(Integer) && row.values[:interval].positive?
                next if (Time.now - row.values[:last_run]) < row.values[:interval]
              elsif row.values[:cron].is_a? String
                cron_class = Fugit.parse(row.values[:cron])
                if cron_class.respond_to? :to_sec
                  next if (Time.now - row.values[:last_run]) < cron_class.to_sec
                elsif cron_class.respond_to? :previous_time
                  next if Time.now < Time.parse(cron_class.previous_time.to_s)
                  next if row.values[:last_run] > Time.parse(cron_class.previous_time.to_s)
                end
              end

              function = Legion::Data::Model::Function[row.values[:function_id]]

              send_task(transformation: row.values[:transformation],
                        function_id: row.values[:function_id],
                        expiration: row.values[:task_ttl],
                        function: function.values[:name],
                        **Legion::JSON.load(row.values[:payload]))
              row.update(last_run: Sequel::CURRENT_TIMESTAMP)
            end
          end

          def send_task(**opts)
            payload = {}
            %i[runner_class function_id function debug args expiration].each do |thing|
              payload[thing] = opts[thing] if opts.key? thing
            end

            return Legion::Transport::Messages::Dynamic.new(**opts).publish if opts[:transformation].nil?
            payload[:exchange] = 'task'
            payload[:routing_key] = 'task.subtask.transform'
            payload[:transformation] = opts[:transformation]

            Legion::Extensions::Scheduler::Transport::Messages::SendTask.new(**payload).publish
          end
        end
      end
    end
  end
end
