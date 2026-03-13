# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Data
        module Model
          class Schedule < Sequel::Model
            one_to_many :schedule_logs
            many_to_one :task
            many_to_one :function
          end
        end
      end
    end
  end
end
