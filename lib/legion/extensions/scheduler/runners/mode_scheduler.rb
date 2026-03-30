# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Runners
        module ModeScheduler
          include Legion::Extensions::Helpers::Transport
          include Legion::Extensions::Helpers::Cache
          include Legion::Extensions::Helpers::Data
          include Legion::Extensions::Helpers::Lex

          MODES = %w[active idle dream maintenance].freeze

          def evaluate_mode(**)
            schedule = mode_schedule
            return unless schedule

            current_hour = Time.now.hour
            new_mode = determine_mode(current_hour, schedule)
            return unless new_mode

            current_mode = fetch_current_mode
            return if current_mode == new_mode

            execute_mode_change(from: current_mode, to: new_mode)
          end

          def mode_schedule
            return settings.dig(:scheduler, :mode_schedule) if settings.dig(:scheduler, :mode_schedule) # rubocop:disable Legion/Extension/RunnerReturnHash

            default_mode_schedule
          end

          def default_mode_schedule
            {
              active:      (8..17).to_a,
              idle:        (18..21).to_a,
              dream:       [22, 23, 0, 1, 2, 3, 4, 5],
              maintenance: [6, 7]
            }
          end

          def determine_mode(hour, schedule)
            schedule.each do |mode, hours|
              return mode.to_s if hours.include?(hour) # rubocop:disable Legion/Extension/RunnerReturnHash
            end
            nil
          end

          def fetch_current_mode
            cache_get('scheduler_operating_mode') || 'active'
          end

          def execute_mode_change(_from:, to:)
            cache_set('scheduler_operating_mode', to, 3600)
          end
        end
      end
    end
  end
end
