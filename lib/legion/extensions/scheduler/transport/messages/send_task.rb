module Legion::Extensions::Scheduler::Transport::Messages
  class SendTask < Legion::Transport::Message
    def type
      'task'
    end

    def message
      return @options if routing_key == 'task.subtask.transform'

      {
        args: @options[:args] || @options,
        function: function.values[:name]
      }
    end

    def routing_key
      @routing_key ||= if @options.key?(:routing_key)
                         @options[:routing_key]
                       else
                         "#{function.runner.extension.values[:name]}.#{function.runner.values[:name]}.#{function.values[:name]}" # rubocop:disable Layout/LineLength
                       end
    end

    def exchange
      @exchange ||= if @options.key?(:exchange) && @options[:exchange].is_a?(String)
                      Legion::Transport::Exchange.new(@options[:exchange])
                    else
                      Legion::Transport::Exchange.new(function.runner.extension.values[:exchange])
                    end
    end

    def function
      @function ||= Legion::Data::Model::Function[@options[:function_id]]
    end
  end
end
