# frozen_string_literal: true

require 'legion/extensions/scheduler/helpers/mode'

module Legion
  module Extensions
    module Scheduler
      module Runners
        module EmergencyPromotion
          extend self # rubocop:disable Style/ModuleFunction -- Included helpers must also be callable on the runner module.
          include Legion::Extensions::Scheduler::Helpers::Mode

          def promote(event_type:, **)
            current = scheduler_current_mode
            target = settings[:emergency_mode]
            matches = settings[:emergency_patterns].any? { |pattern| event_type.to_s.include?(pattern) }
            return { success: true, changed: false, mode: current } unless matches && current != target

            log.warn("Scheduler emergency promotion due to #{event_type}")
            scheduler_change_mode(from: current, to: target)
          end
        end
      end
    end
  end
end
