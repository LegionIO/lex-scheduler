# frozen_string_literal: true

require_relative 'runners/schedule'

module Legion
  module Extensions
    module Scheduler
      class Client
        include Runners::Schedule

        def initialize(data_model: nil, fugit: nil)
          @data_model = data_model
          @fugit = fugit || (require 'fugit'; Fugit)
        end

        def models_class
          @data_model || Data::Model
        end

        def log
          @log ||= defined?(Legion::Logging) ? Legion::Logging : Logger.new($stdout)
        end

        def settings
          { options: {} }
        end
      end
    end
  end
end
