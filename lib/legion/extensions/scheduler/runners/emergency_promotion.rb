# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Runners
        module EmergencyPromotion
          DEFAULT_PATTERNS = %w[extinction.* governance.consent_violation governance.shadow_ai_detected].freeze

          def check_emergency(event_name:, **)
            return { promoted: false, reason: 'not_emergency' } unless emergency_pattern?(event_name)
            return { promoted: false, reason: 'already_active' } if current_mode == :active

            result = transition_to(target_mode: :active, reason: "emergency:#{event_name}", force: true)
            log_emergency(event_name)
            { promoted: result[:transitioned], event: event_name, transition: result }
          end

          private

          def emergency_pattern?(event_name)
            patterns = emergency_patterns
            patterns.any? { |p| File.fnmatch?(p, event_name) }
          end

          def log_emergency(event_name)
            return unless defined?(Legion::Logging) && Legion::Logging.respond_to?(:warn, true)

            Legion::Logging.send(:warn, "[scheduler] Emergency promotion: #{event_name}")
          end

          def emergency_patterns
            settings = scheduler_settings
            patterns = settings[:emergency_patterns]
            patterns.is_a?(Array) ? patterns : DEFAULT_PATTERNS
          end
        end
      end
    end
  end
end
