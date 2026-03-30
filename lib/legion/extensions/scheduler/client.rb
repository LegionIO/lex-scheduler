# frozen_string_literal: true

require 'fugit'
require_relative 'runners/schedule'

module Legion
  module Extensions
    module Scheduler
      class Client
        include Runners::Schedule

        def initialize(data_model: nil, fugit: nil)
          @data_model = data_model
          @fugit = fugit || Fugit
        end

        def models_class
          @data_model || Data::Model
        end

        def log
          @log ||= Legion::Logging
        end

        def settings
          { options: {} }
        end
      end
    end
  end
end
