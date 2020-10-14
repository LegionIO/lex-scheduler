module Legion::Extensions::Scheduler::Actor
  class ScheduleTask < Legion::Extensions::Actors::Every
    def runner_function
      'push_refresh'
    end

    def runner_class
      Legion::Extensions::Scheduler::Runners::Schedule
    end

    def use_runner?
      false
    end

    def check_subtask?
      false
    end

    def generate_task?
      false
    end
  end
end
