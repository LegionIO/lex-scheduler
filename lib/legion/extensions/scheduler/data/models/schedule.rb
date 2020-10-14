module Legion::Extensions::Scheduler::Data::Model
  class Schedule < Sequel::Model
    one_to_many :schedule_logs
    many_to_one :task
    many_to_one :function
  end
end
