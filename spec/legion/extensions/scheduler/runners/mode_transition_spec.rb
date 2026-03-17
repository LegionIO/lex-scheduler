# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/scheduler/runners/mode_scheduler'
require 'legion/extensions/scheduler/runners/mode_transition'

RSpec.describe Legion::Extensions::Scheduler::Runners::ModeTransition do
  let(:host) do
    obj = Object.new
    obj.extend(described_class)
    obj.extend(Legion::Extensions::Scheduler::Runners::ModeScheduler)
    obj
  end

  describe '#transition_to' do
    it 'transitions successfully' do
      allow(host).to receive(:current_mode).and_return(:idle)
      allow(host).to receive(:critical_tasks_active?).and_return(false)
      allow(host).to receive(:apply_mode)
      allow(host).to receive(:emit_transition_event)

      result = host.transition_to(target_mode: :active)
      expect(result[:transitioned]).to be true
      expect(result[:from]).to eq(:idle)
      expect(result[:to]).to eq(:active)
    end

    it 'rejects transition to same mode' do
      allow(host).to receive(:current_mode).and_return(:active)
      result = host.transition_to(target_mode: :active)
      expect(result[:transitioned]).to be false
      expect(result[:reason]).to eq('already_in_mode')
    end

    it 'blocks transition when critical tasks active' do
      allow(host).to receive(:current_mode).and_return(:active)
      allow(host).to receive(:critical_tasks_active?).and_return(true)
      result = host.transition_to(target_mode: :dream)
      expect(result[:transitioned]).to be false
      expect(result[:reason]).to eq('blocked_by_critical')
    end

    it 'allows forced transition past critical tasks' do
      allow(host).to receive(:current_mode).and_return(:active)
      allow(host).to receive(:critical_tasks_active?).and_return(true)
      allow(host).to receive(:apply_mode)
      allow(host).to receive(:emit_transition_event)

      result = host.transition_to(target_mode: :dream, force: true)
      expect(result[:transitioned]).to be true
    end
  end

  describe '#current_mode' do
    it 'defaults to active when Gaia is not defined' do
      expect(host.current_mode).to eq(:active)
    end
  end
end
