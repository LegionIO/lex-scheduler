# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Actor
        # The instance time method resolves current settings instead of freezing a DSL literal at load time.
        class RunScheduler < Legion::Extensions::Actors::Every # rubocop:disable Legion/Extension/EveryActorRequiresTime -- time reads live settings.
          include Legion::Extensions::Actors::Singleton if defined?(Legion::Extensions::Actors::Singleton)

          def time
            settings[:poll_interval_seconds]
          end

          def runner_function
            'schedule_tasks'
          end

          def runner_class
            Legion::Extensions::Scheduler::Runners::Schedule
          end

          def use_runner?
            false
          end

          def check_subtask?
            false
          end

          def generate_task?
            false
          end
        end
      end
    end
  end
end
