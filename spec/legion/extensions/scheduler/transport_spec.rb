# frozen_string_literal: true

require 'spec_helper'

# Stub transport base class in the exact namespace before requiring queue file
module Legion
  module Transport
    class Queue; end unless defined?(Legion::Transport::Queue) # rubocop:disable Lint/EmptyClass
  end
end

require 'legion/extensions/scheduler/transport/queues/schedule'

RSpec.describe Legion::Extensions::Scheduler::Transport::Queues::Schedule do
  subject(:queue) { described_class.allocate }

  it 'inherits from Legion::Transport::Queue' do
    expect(described_class.superclass).to eq(Legion::Transport::Queue)
  end

  describe '#queue_options' do
    let(:options) { queue.queue_options }

    it 'has x-single-active-consumer set to true' do
      expect(options[:arguments][:'x-single-active-consumer']).to eq(true)
    end

    it 'has x-message-ttl of 5000ms' do
      expect(options[:arguments][:'x-message-ttl']).to eq(5000)
    end

    it 'has auto_delete false' do
      expect(options[:auto_delete]).to eq(false)
    end
  end
end
