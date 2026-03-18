# frozen_string_literal: true

require 'spec_helper'

# Stub the Every base class before requiring actors
module Legion
  module Extensions
    module Actors
      class Every; end unless defined?(Every) # rubocop:disable Lint/EmptyClass
    end

    module Scheduler
      module Runners
        module Schedule; end unless defined?(Legion::Extensions::Scheduler::Runners::Schedule)
      end
    end
  end
end

# Inject stub into $LOADED_FEATURES so require guards pass
$LOADED_FEATURES << 'legion/extensions/actors/every' unless $LOADED_FEATURES.include?('legion/extensions/actors/every')

require 'legion/extensions/scheduler/actors/run_scheduler'
require 'legion/extensions/scheduler/actors/schedule_task'

RSpec.describe Legion::Extensions::Scheduler::Actor::RunScheduler do
  subject(:actor) { described_class.allocate }

  it 'inherits from Legion::Extensions::Actors::Every' do
    expect(described_class.superclass).to eq(Legion::Extensions::Actors::Every)
  end

  it 'runner_function returns schedule_tasks' do
    expect(actor.runner_function).to eq('schedule_tasks')
  end

  it 'runner_class returns Schedule runner' do
    expect(actor.runner_class).to eq(Legion::Extensions::Scheduler::Runners::Schedule)
  end

  it 'use_runner? returns false' do
    expect(actor.use_runner?).to eq(false)
  end

  it 'check_subtask? returns false' do
    expect(actor.check_subtask?).to eq(false)
  end

  it 'generate_task? returns false' do
    expect(actor.generate_task?).to eq(false)
  end
end

RSpec.describe Legion::Extensions::Scheduler::Actor::ScheduleTask do
  subject(:actor) { described_class.allocate }

  it 'inherits from Legion::Extensions::Actors::Every' do
    expect(described_class.superclass).to eq(Legion::Extensions::Actors::Every)
  end

  it 'runner_function returns push_refresh' do
    expect(actor.runner_function).to eq('push_refresh')
  end

  it 'runner_class returns Schedule runner' do
    expect(actor.runner_class).to eq(Legion::Extensions::Scheduler::Runners::Schedule)
  end

  it 'use_runner? returns false' do
    expect(actor.use_runner?).to eq(false)
  end

  it 'check_subtask? returns false' do
    expect(actor.check_subtask?).to eq(false)
  end

  it 'generate_task? returns false' do
    expect(actor.generate_task?).to eq(false)
  end
end
