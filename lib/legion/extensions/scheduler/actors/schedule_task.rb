# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Actor
        class ScheduleTask < Legion::Extensions::Actors::Every # rubocop:disable Legion/Extension/EveryActorRequiresTime
          def runner_function
            'push_refresh'
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
