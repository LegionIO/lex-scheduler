# frozen_string_literal: true

require 'legion/extensions/scheduler/helpers/mode'

module Legion
  module Extensions
    module Scheduler
      module Runners
        module ModeScheduler
          extend self # rubocop:disable Style/ModuleFunction -- Included helpers must also be callable on the runner module.
          include Legion::Extensions::Scheduler::Helpers::Mode

          def evaluate_mode(now: Time.now, **)
            entry = settings[:mode_schedule].find { |_mode, hours| hours.include?(now.hour) }
            current_mode = scheduler_current_mode
            return { success: true, changed: false, mode: current_mode } unless entry && entry.first.to_s != current_mode

            scheduler_change_mode(from: current_mode, to: entry.first.to_s)
          end
        end
      end
    end
  end
end
