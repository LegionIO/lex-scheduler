module Legion::Extensions::Scheduler::Actor
  class RunScheduler < Legion::Extensions::Actors::Every
    def runner_function
      'schedule_tasks'
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
