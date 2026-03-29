# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Runners
        module ModeTransition
          include Legion::Extensions::Helpers::Transport
          include Legion::Extensions::Helpers::Cache
          include Legion::Extensions::Helpers::Data
          include Legion::Extensions::Helpers::Lex

          VALID_MODES = %w[active idle dream maintenance].freeze

          def transition(**opts)
            target_mode = opts[:mode] || opts['mode']
            return unless target_mode
            return unless valid_mode?(target_mode)

            force = opts[:force] || opts['force'] || false
            current_mode = fetch_current_mode
            return if current_mode == target_mode.to_s

            return if !force && critical_tasks_running?

            execute_transition(from: current_mode, to: target_mode.to_s)
          end

          def valid_mode?(mode)
            VALID_MODES.include?(mode.to_s)
          end

          def critical_tasks_running?
            count = Legion::Cache.get('scheduler_critical_task_count')
            count.is_a?(Integer) ? count.positive? : false
          end

          def fetch_current_mode
            Legion::Cache.get('scheduler_operating_mode') || 'active'
          end

          def execute_transition(from:, to:)
            Legion::Cache.set('scheduler_operating_mode', to, 3600)
          end
        end
      end
    end
  end
end
