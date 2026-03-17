# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Runners
        module ModeScheduler
          MODES = {
            active:      { tick_interval: 1, cognitive: true, dream: false },
            idle:        { tick_interval: 5, cognitive: true, dream: false },
            dream:       { tick_interval: 10, cognitive: false, dream: true },
            maintenance: { tick_interval: 0, cognitive: false, dream: false }
          }.freeze

          def evaluate_schedule(current_time: Time.now, **)
            schedules = load_schedules
            applicable = schedules.select { |s| matches_time?(s[:schedule], current_time) }

            return { mode: :idle, reason: 'no_matching_schedule', mode_config: MODES[:idle] } if applicable.empty?

            winner = applicable.max_by { |s| s[:priority] || 0 }
            mode = winner[:mode].to_sym
            { mode: mode, reason: 'scheduled', schedule: winner, mode_config: MODES[mode] || MODES[:idle] }
          end

          private

          def matches_time?(schedule, time)
            case schedule
            when 'default'
              true
            when /\Aweekday:(\d+)-(\d+)\z/
              start_h = ::Regexp.last_match(1).to_i
              end_h = ::Regexp.last_match(2).to_i
              (1..5).include?(time.wday) && time.hour >= start_h && time.hour < end_h
            when /\Aweekend:(\d+)-(\d+)\z/
              start_h = ::Regexp.last_match(1).to_i
              end_h = ::Regexp.last_match(2).to_i
              [0, 6].include?(time.wday) && time.hour >= start_h && time.hour < end_h
            when /\Adaily:(\d+)-(\d+)\z/
              start_h = ::Regexp.last_match(1).to_i
              end_h = ::Regexp.last_match(2).to_i
              time.hour >= start_h && time.hour < end_h
            else
              false
            end
          end

          def load_schedules
            settings = scheduler_settings
            raw = settings[:mode_schedule]
            return [] unless raw.is_a?(Array)

            raw.map { |s| s.transform_keys(&:to_sym) }
          end

          def scheduler_settings
            settings = Legion::Settings[:scheduler]
            settings.is_a?(Hash) ? settings : {}
          rescue StandardError
            {}
          end
        end
      end
    end
  end
end
