# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Runners
        module ModeTransition
          def transition_to(target_mode:, reason: 'scheduled', force: false, **)
            current = current_mode
            target = target_mode.to_sym

            return { transitioned: false, reason: 'already_in_mode' } if current == target
            return { transitioned: false, reason: 'blocked_by_critical' } if !force && critical_tasks_active?

            apply_mode(target)
            emit_transition_event(from: current, to: target, reason: reason)
            { transitioned: true, from: current, to: target, reason: reason }
          end

          def current_mode(**)
            if defined?(Legion::Gaia) && Legion::Gaia.respond_to?(:mode)
              Legion::Gaia.mode
            else
              :active
            end
          end

          private

          def critical_tasks_active?
            return false unless defined?(Legion::Data::Model::Task)

            Legion::Data::Model::Task.where(status: 'running', priority: 'critical').any?
          rescue StandardError
            false
          end

          def apply_mode(mode)
            config = ModeScheduler::MODES[mode] || ModeScheduler::MODES[:idle]
            return unless defined?(Legion::Gaia) && Legion::Gaia.respond_to?(:heartbeat_interval=)

            Legion::Gaia.heartbeat_interval = config[:tick_interval]
          end

          def emit_transition_event(from:, to:, reason:)
            return unless defined?(Legion::Events)

            Legion::Events.emit('scheduler.mode_changed', {
                                  from: from, to: to, reason: reason, changed_at: Time.now.utc
                                })
          end
        end
      end
    end
  end
end
