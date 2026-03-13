# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Data
        module Model
          class Schedule < Sequel::Model
            one_to_many :schedule_logs
            # many_to_one :task, class: Legion::Data::Model::Task
            many_to_one :function, class: '::Legion::Data::Model::Function'
          end
        end
      end
    end
  end
end
