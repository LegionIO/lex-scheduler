# frozen_string_literal: true

require 'spec_helper'
require 'legion/extensions/scheduler/runners/mode_scheduler'

RSpec.describe Legion::Extensions::Scheduler::Runners::ModeScheduler do
  let(:host) { Object.new.extend(described_class) }

  before do
    allow(Legion::Settings).to receive(:[]).with(:scheduler).and_return({
                                                                          mode_schedule: [
                                                                            { mode: 'active', schedule: 'weekday:8-18', priority: 10 },
                                                                            { mode: 'dream', schedule: 'daily:2-4', priority: 5 },
                                                                            { mode: 'idle', schedule: 'default', priority: 0 }
                                                                          ]
                                                                        })
  end

  describe '#evaluate_schedule' do
    it 'returns active during weekday business hours' do
      tuesday_noon = Time.new(2026, 3, 17, 12, 0, 0) # Tuesday
      result = host.evaluate_schedule(current_time: tuesday_noon)
      expect(result[:mode]).to eq(:active)
    end

    it 'returns dream during 2-4 AM' do
      early_morning = Time.new(2026, 3, 17, 3, 0, 0)
      result = host.evaluate_schedule(current_time: early_morning)
      expect(result[:mode]).to eq(:dream)
    end

    it 'falls back to idle on weekends outside dream hours' do
      saturday_noon = Time.new(2026, 3, 21, 12, 0, 0) # Saturday
      result = host.evaluate_schedule(current_time: saturday_noon)
      expect(result[:mode]).to eq(:idle)
    end

    it 'picks highest priority when multiple match' do
      tuesday_3am = Time.new(2026, 3, 17, 3, 0, 0)
      result = host.evaluate_schedule(current_time: tuesday_3am)
      expect(result[:mode]).to eq(:dream) # priority 5 > default 0
    end

    it 'returns idle when no schedules configured' do
      allow(Legion::Settings).to receive(:[]).with(:scheduler).and_return({})
      result = host.evaluate_schedule(current_time: Time.now)
      expect(result[:mode]).to eq(:idle)
      expect(result[:reason]).to eq('no_matching_schedule')
    end
  end
end
