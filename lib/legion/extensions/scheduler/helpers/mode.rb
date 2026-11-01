# frozen_string_literal: true

require 'legion/extensions/scheduler'
require 'legion/cache'
require 'legion/cache/helper'

module Legion
  module Extensions
    module Scheduler
      module Helpers
        module Mode
          include Legion::Logging::Helper
          include Legion::Cache::Helper

          private

          def scheduler_current_mode
            raise ArgumentError, 'scheduler operating modes require connected cache' unless Legion::Cache.respond_to?(:connected?) && cache_connected?

            cache_get('scheduler_operating_mode') || settings[:default_mode]
          end

          def scheduler_change_mode(from:, to:)
            raise ArgumentError, "unsupported scheduler mode #{to.inspect}" unless settings[:modes].include?(to)

            cache_set('scheduler_operating_mode', to, ttl: settings[:mode_cache_ttl_seconds])
            log.info("Scheduler mode changed from #{from} to #{to}")
            { success: true, changed: true, previous_mode: from, mode: to }
          end
        end
      end
    end
  end
end
