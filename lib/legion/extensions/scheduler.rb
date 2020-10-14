# frozen_string_literal: true

require 'legion/extensions/scheduler/version'
require 'legion/extensions'

module Legion
  module Extensions
    module Scheduler
      extend Legion::Extensions::Core

      def data_required?
        true
      end
    end
  end
end
