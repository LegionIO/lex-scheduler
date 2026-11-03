# frozen_string_literal: true

require 'legion/extensions/scheduler/helpers/mode'

module Legion
  module Extensions
    module Scheduler
      module Runners
        module ModeTransition
          extend self # rubocop:disable Style/ModuleFunction -- Included helpers must also be callable on the runner module.
          include Legion::Extensions::Scheduler::Helpers::Mode

          def transition(mode:, force: false, **)
            target = mode.to_s
            raise ArgumentError, "unsupported scheduler mode #{target.inspect}" unless settings[:modes].include?(target)

            current = scheduler_current_mode
            return { success: true, changed: false, mode: current } if current == target

            count = cache_get('scheduler_critical_task_count')
            return { success: false, changed: false, mode: current, reason: :critical_tasks_running } if !force && count.is_a?(Integer) && count.positive?

            scheduler_change_mode(from: current, to: target)
          end
        end
      end
    end
  end
end
