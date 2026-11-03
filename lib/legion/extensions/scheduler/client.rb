# frozen_string_literal: true

require 'legion/extensions/scheduler/runners/schedule'

module Legion
  module Extensions
    module Scheduler
      class Client
        include Legion::Settings::Helper
        include Legion::Extensions::Scheduler::Runners::Schedule

        def initialize(data_model: nil, fugit: Fugit)
          @data_model = data_model
          @fugit = fugit
          Legion::Settings.loader.load_module_default(extensions: { scheduler: Legion::Extensions::Scheduler.default_settings })
        end

        def models_class
          @data_model || Legion::Extensions::Scheduler::Data::Model
        end

        def segments
          [:scheduler]
        end
      end
    end
  end
end
