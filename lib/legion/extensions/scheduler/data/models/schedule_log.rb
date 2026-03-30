# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Data
        module Model
          class ScheduleLog < Sequel::Model(:schedule_logs) # rubocop:disable Legion/Framework/EagerSequelModel
            many_to_one :schedule, class: '::Legion::Extensions::Scheduler::Data::Model::Schedule'
          end
        end
      end
    end
  end
end
