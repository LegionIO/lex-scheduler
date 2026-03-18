# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Transport
        module Queues
          class Schedule < Legion::Transport::Queue
            def queue_options
              {
                arguments:   {
                  'x-single-active-consumer': true,
                  'x-message-ttl':            5000
                },
                auto_delete: false
              }
            end
          end
        end
      end
    end
  end
end
