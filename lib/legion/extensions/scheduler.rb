# frozen_string_literal: true

require 'legion/extensions/scheduler/version'
require 'legion/settings'
require 'legion/settings/helper'
require 'legion/settings/task_execution'
require 'legion/logging/helper'

module Legion
  module Extensions
    module Scheduler
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core, false

      # Migrations 001-007 ship under scheduler/data/migrations; the reminder cop does not inspect the filesystem.
      def self.data_required? # rubocop:disable Legion/Extension/DataRequiredWithoutMigrations
        true
      end

      def self.transport_required?
        false
      end

      def self.default_settings
        {
          poll_interval_seconds:  1,
          interval_basis:         'scheduled',
          overlap_policy:         'forbid',
          misfire_policy:         'coalesce',
          misfire_grace_seconds:  60,
          max_catch_up:           100,
          occurrence_statuses:    { recorded: 'schedule.recorded', delivered: 'schedule.delivered', skipped: 'schedule.skipped' },
          mode_schedule:          {
            active: (8..17).to_a, idle: (18..21).to_a,
            dream: [22, 23, 0, 1, 2, 3, 4, 5], maintenance: [6, 7]
          },
          modes:                  %w[active idle dream maintenance],
          default_mode:           'active',
          emergency_mode:         'active',
          emergency_patterns:     %w[extinction consent_violation],
          mode_cache_ttl_seconds: 3600
        }
      end
    end
  end
end
