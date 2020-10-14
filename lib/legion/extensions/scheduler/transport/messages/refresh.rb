module Legion::Extensions::Scheduler::Transport::Messages
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
        function: 'refresh',
        runner_class: 'Legion::Extensions::Scheduler::Runners::Schedule'
      }
    end

    def message_example
      { function: 'push_cluster_secret',
        node_name: Legion::Settings[:client][:name],
        queue_name: "node.#{Legion::Settings[:client][:name]}",
        runner_class: 'Legion::Extensions::Node::Runners::Crypt',
        # public_key: Base64.encode64(Legion::Crypt.public_key) }
        public_key: Legion::Crypt.public_key }
    end
  end
end
