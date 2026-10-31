# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/scheduler/runners/mode_transition'
require 'legion/extensions/scheduler/runners/mode_scheduler'
require 'legion/extensions/scheduler/runners/emergency_promotion'

RSpec.describe 'Scheduler operating mode policy' do
  let(:runner) do
    Class.new do
      include Legion::Extensions::Scheduler::Runners::ModeTransition
      include Legion::Extensions::Scheduler::Runners::ModeScheduler
      include Legion::Extensions::Scheduler::Runners::EmergencyPromotion

      def segments
        [:scheduler]
      end
    end.new
  end

  before do
    Legion::Cache.setup
    runner.cache_delete('scheduler_operating_mode')
    runner.cache_delete('scheduler_critical_task_count')
  end

  it 'blocks normal transitions during critical work but permits an explicitly forced transition' do
    runner.cache_set('scheduler_critical_task_count', 1)
    expect(runner.transition(mode: 'idle')).to include(success: false, changed: false, reason: :critical_tasks_running)
    expect(runner.transition(mode: 'idle', force: true)).to include(success: true, changed: true, mode: 'idle')
    expect(runner.cache_get('scheduler_operating_mode')).to eq('idle')
  end

  it 'uses configured hour and emergency policies rather than hardcoded active mode' do
    Legion::Settings.with_overlay(extensions: { scheduler: { mode_schedule: { active: [3] }, default_mode: 'maintenance',
                                                           emergency_mode: 'idle', emergency_patterns: ['priority'] } }) do
      expect(runner.evaluate_mode(now: Time.utc(2026, 10, 30, 3))).to include(success: true, mode: 'active')
      expect(runner.promote(event_type: 'priority-event')).to include(success: true, mode: 'idle')
      expect(runner.cache_get('scheduler_operating_mode')).to eq('idle')
    end
  end
end
