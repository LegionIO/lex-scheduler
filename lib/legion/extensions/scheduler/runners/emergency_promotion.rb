# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Runners
        module EmergencyPromotion
          include Legion::Extensions::Helpers::Transport
          include Legion::Extensions::Helpers::Cache
          include Legion::Extensions::Helpers::Data
          include Legion::Extensions::Helpers::Lex

          EMERGENCY_PATTERNS = %w[extinction consent_violation].freeze

          def promote(**opts)
            event_type = opts[:event_type] || opts['event_type']
            return unless emergency_event?(event_type)

            current_mode = fetch_current_mode
            return if current_mode == 'active'

            execute_emergency_promotion(from: current_mode, event_type: event_type)
          end

          def emergency_event?(event_type)
            return false unless event_type

            patterns = emergency_patterns
            patterns.any? { |pattern| event_type.to_s.include?(pattern) }
          end

          def emergency_patterns
            return settings.dig(:scheduler, :emergency_patterns) if settings.dig(:scheduler, :emergency_patterns)

            EMERGENCY_PATTERNS
          end

          def fetch_current_mode
            Legion::Cache.get('scheduler_operating_mode') || 'active'
          end

          def execute_emergency_promotion(from:, event_type:)
            Legion::Cache.set('scheduler_operating_mode', 'active', 3600)
            Legion::Logging.send(:warn, "Emergency promotion to active from #{from} due to #{event_type}") if defined?(Legion::Logging)
          end
        end
      end
    end
  end
end
