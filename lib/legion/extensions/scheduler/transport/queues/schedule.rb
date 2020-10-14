module Legion::Extensions::Scheduler
  module Transport
    module Queues
      class Schedule < Legion::Transport::Queue
        def queue_options
          {
            arguments: {
              'x-single-active-consumer': true,
              'x-max-priority': 255,
              'x-message-ttl': 5
            },
            auto_delete: false
          }
        end
      end
    end
  end
end
