# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/scheduler/runners/mode_scheduler'
require 'legion/extensions/scheduler/runners/mode_transition'
require 'legion/extensions/scheduler/runners/emergency_promotion'

module Legion
  module Logging
    def self.warn(*_args); end unless respond_to?(:warn)
  end
end

RSpec.describe Legion::Extensions::Scheduler::Runners::EmergencyPromotion do
  let(:host) do
    obj = Object.new
    obj.extend(described_class)
    obj.extend(Legion::Extensions::Scheduler::Runners::ModeTransition)
    obj.extend(Legion::Extensions::Scheduler::Runners::ModeScheduler)
    obj
  end

  before do
    allow(host).to receive(:apply_mode)
    allow(host).to receive(:emit_transition_event)
    allow(Legion::Settings).to receive(:[]).with(:scheduler).and_return({})
    allow(Legion::Logging).to receive(:warn)
  end

  describe '#check_emergency' do
    it 'promotes on extinction event' do
      allow(host).to receive(:current_mode).and_return(:dream)
      result = host.check_emergency(event_name: 'extinction.triggered')
      expect(result[:promoted]).to be true
      expect(result[:event]).to eq('extinction.triggered')
    end

    it 'promotes on consent violation event' do
      allow(host).to receive(:current_mode).and_return(:idle)
      result = host.check_emergency(event_name: 'governance.consent_violation')
      expect(result[:promoted]).to be true
    end

    it 'skips non-emergency events' do
      result = host.check_emergency(event_name: 'runner.completed')
      expect(result[:promoted]).to be false
      expect(result[:reason]).to eq('not_emergency')
    end

    it 'skips if already active' do
      allow(host).to receive(:current_mode).and_return(:active)
      result = host.check_emergency(event_name: 'extinction.triggered')
      expect(result[:promoted]).to be false
      expect(result[:reason]).to eq('already_active')
    end

    it 'uses custom emergency patterns from settings' do
      allow(Legion::Settings).to receive(:[]).with(:scheduler).and_return({
                                                                            emergency_patterns: %w[custom.critical]
                                                                          })
      allow(host).to receive(:current_mode).and_return(:dream)
      result = host.check_emergency(event_name: 'custom.critical')
      expect(result[:promoted]).to be true
    end
  end
end
