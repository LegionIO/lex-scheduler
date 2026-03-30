# frozen_string_literal: true

require 'legion/extensions/scheduler/version'

module Legion
  module Extensions
    module Scheduler
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core, false

      def self.data_required? # rubocop:disable Legion/Extension/DataRequiredWithoutMigrations
        true
      end
    end
  end
end
