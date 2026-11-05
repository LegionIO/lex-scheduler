# frozen_string_literal: true

require 'fugit'
require 'time'
require 'legion/extensions/scheduler'
require 'legion/json/helper'
require 'legion/data'
require 'legion/data/models/task'
require 'legion/data/helper'

module Legion
  module Extensions
    module Scheduler
      module Helpers
        module Schedule
          include Legion::Logging::Helper
          include Legion::Transport::Task::Protocol::Helper
          include Legion::Data::Helper
          include Legion::JSON::Helper

          private

          def models_class
            Legion::Extensions::Scheduler::Data::Model
          end

          def schedule_policy(schedule:)
            policy = { misfire: schedule[:misfire_policy] || settings[:misfire_policy] }
            raise ArgumentError, 'unsupported misfire_policy' unless %w[coalesce skip catch_up].include?(policy[:misfire])
            raise ArgumentError, 'max_catch_up must be a positive Integer' unless settings[:max_catch_up].is_a?(Integer) && settings[:max_catch_up].positive?
            unless settings[:misfire_grace_seconds].is_a?(Numeric) && settings[:misfire_grace_seconds] >= 0
              raise ArgumentError, 'misfire_grace_seconds must be nonnegative'
            end

            policy
          end

          def schedule_parse(schedule:)
            interval = schedule[:interval]
            cron = schedule[:cron]
            if interval
              raise ArgumentError, 'specify interval or cron, not both' unless cron.nil? || cron.empty?
              raise ArgumentError, 'interval must be a positive Integer' unless interval.is_a?(Integer) && interval.positive?

              return interval
            end
            raise ArgumentError, 'cron must be a nonempty String' unless cron.is_a?(String) && !cron.strip.empty?

            parsed = (@fugit || Fugit).parse(cron)
            return parsed.to_sec if parsed.respond_to?(:to_sec) && parsed.to_sec.positive?
            return parsed if parsed.respond_to?(:previous_time) && parsed.respond_to?(:next_time)
            return parsed if parsed.respond_to?(:to_t)

            raise ArgumentError, "invalid schedule expression: #{cron.inspect}"
          end

          def schedule_due_times(schedule:, parsed:, policy:, now:)
            if parsed.respond_to?(:to_t)
              due = parsed.to_t
              return !schedule[:last_run] && due <= now ? [due] : []
            end

            anchor = (schedule[:last_run] || schedule[:created]).to_time
            if parsed.is_a?(Numeric)
              due = schedule[:last_run] ? anchor + parsed : anchor
              schedule_interval_times(due: due, interval: parsed, misfire: policy[:misfire], now: now)
            else
              schedule_cron_times(schedule: schedule, cron: parsed, anchor: anchor, misfire: policy[:misfire], now: now)
            end
          end

          def schedule_interval_times(due:, interval:, misfire:, now:)
            return [] if due > now
            return [due + (((now - due) / interval).floor * interval)] unless misfire == 'catch_up'

            count = [((now - due) / interval).floor + 1, settings[:max_catch_up]].min
            Array.new(count) { |index| due + (index * interval) }
          end

          def schedule_cron_times(schedule:, cron:, anchor:, misfire:, now:)
            previous = cron.previous_time(now + 1).to_t
            return [] if previous < anchor || (schedule[:last_run] && previous <= anchor)
            return [previous] unless misfire == 'catch_up'

            times = []
            cursor = schedule[:last_run] ? anchor : anchor - Rational(1, 1_000_000)
            settings[:max_catch_up].times do
              cursor = cron.next_time(cursor).to_t
              break if cursor > now

              times << cursor
            end
            times
          end

          def schedule_json_hash(value:, field:)
            parsed = value.nil? ? {} : json_load(value)
            raise ArgumentError, "schedule #{field} must decode to a Hash" unless parsed.is_a?(Hash)

            parsed
          end

          def schedule_envelope(function_id:, args:, context:, transformation:, expiration:)
            function = Legion::Data::Model::Function[function_id]
            raise ArgumentError, "schedule target function #{function_id.inspect} does not exist" unless function

            metadata = Legion::Transport::Task::Protocol::METADATA_FIELDS
            options = context.each_with_object({}) do |(key, value), selected|
              selected[key.to_sym] = value if metadata.include?(key.to_sym)
            end
            options.reject! { |key, _| %i[task_id schedule_id occurrence_id definition_version].include?(key) }
            options.merge!(function_id: function_id, function: function.values[:name], args: args)
            options[:runner_class] = function.runner.values[:namespace]
            options[:runner_routing_key] = "#{function.runner.extension.values[:name]}.#{function.runner.values[:name]}.#{function.values[:name]}"
            options[:expiration] = expiration unless expiration.nil?
            if transformation && !transformation.strip.empty?
              options[:transformation] = transformation
              options[:routing_key] = task_route(name: :transform)
            end
            options
          end

          def schedule_task_values(options:)
            status = task_status(name: options.key?(:transformation) ? :transformer_queued : :queued)
            values = { function_id: options[:function_id], status: status,
                       function_args: json_dump(options[:args]), payload: json_dump(options) }
            %i[parent_id master_id relationship_id worker_id depth].each do |key|
              values[key] = options[key] if options.key?(key)
            end
            values
          end
        end
      end
    end
  end
end
