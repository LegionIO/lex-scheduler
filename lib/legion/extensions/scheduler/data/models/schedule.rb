module Legion::Extensions::Scheduler::Data::Model
  class Schedule < Sequel::Model
    one_to_many :schedule_logs
    # many_to_one :task, class: Legion::Data::Model::Task
    many_to_one :function, class: "::Legion::Data::Model::Function"
  end
end
