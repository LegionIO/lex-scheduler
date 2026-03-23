# frozen_string_literal: true

require 'spec_helper'

# Stub transport base class before requiring messages.
# Must be defined in Legion::Transport namespace before the message files are loaded.
module Legion
  module Transport
    unless defined?(Legion::Transport::Message)
      class Message
        def initialize(**opts)
          @options = opts
        end

        def publish; end
      end
    end

    unless defined?(Legion::Transport::Exchange)
      class Exchange
        def initialize(_name); end
      end
    end
  end

  module Data
    module Model
      unless defined?(Legion::Data::Model::Function)
        class Function
          def self.[](_id) = nil
        end
      end
    end
  end
end

# Remove stub Refresh/SendTask defined by runner_spec (plain class, wrong superclass)
# so the real implementations can load correctly.
if defined?(Legion::Extensions::Scheduler::Transport::Messages::Refresh) &&
   Legion::Extensions::Scheduler::Transport::Messages::Refresh.superclass == Object
  Legion::Extensions::Scheduler::Transport::Messages.send(:remove_const, :Refresh)
end

if defined?(Legion::Extensions::Scheduler::Transport::Messages::SendTask) &&
   Legion::Extensions::Scheduler::Transport::Messages::SendTask.superclass == Object
  Legion::Extensions::Scheduler::Transport::Messages.send(:remove_const, :SendTask)
end

require 'legion/extensions/scheduler/transport/messages/refresh'
require 'legion/extensions/scheduler/transport/messages/send_task'

RSpec.describe Legion::Extensions::Scheduler::Transport::Messages::Refresh do
  subject(:message) { described_class.new }

  it 'has routing_key "schedule"' do
    expect(message.routing_key).to eq('schedule')
  end

  it 'has type "task"' do
    expect(message.type).to eq('task')
  end

  it 'has expiration 5000' do
    expect(message.expiration).to eq(5000)
  end

  it 'does not encrypt' do
    expect(message.encrypt?).to eq(false)
  end

  it 'includes function and runner_class in message body' do
    body = message.message
    expect(body[:function]).to eq('refresh')
    expect(body[:runner_class]).to eq('Legion::Extensions::Scheduler::Runners::Schedule')
  end

  it 'responds to publish' do
    expect(message).to respond_to(:publish)
  end
end

RSpec.describe Legion::Extensions::Scheduler::Transport::Messages::SendTask do
  subject(:message) { described_class.new(routing_key: 'task.subtask.transform', exchange: 'task', function_id: 1) }

  it 'has type "task"' do
    expect(message.type).to eq('task')
  end

  it 'returns @options as message body when routing_key is task.subtask.transform' do
    body = message.message
    expect(body).to include(routing_key: 'task.subtask.transform')
  end

  it 'returns the injected routing_key' do
    expect(message.routing_key).to eq('task.subtask.transform')
  end

  it 'builds an Exchange for a string exchange option' do
    expect(Legion::Transport::Exchange).to receive(:new).with('task').and_return(double('exchange'))
    message.exchange
  end

  it 'responds to publish' do
    expect(message).to respond_to(:publish)
  end
end
