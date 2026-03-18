# frozen_string_literal: true

module Legion
  module Extensions
    module Scheduler
      module Transport
        module Messages
          class Refresh < Legion::Transport::Message
            def routing_key
              'schedule'
            end

            def type
              'task'
            end

            def expiration
              5000
            end

            def encrypt?
              false
            end

            def message
              {
                function:     'refresh',
                runner_class: 'Legion::Extensions::Scheduler::Runners::Schedule'
              }
            end
          end
        end
      end
    end
  end
end
