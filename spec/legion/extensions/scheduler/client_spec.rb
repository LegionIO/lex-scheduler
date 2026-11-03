# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Scheduler::Client do
  let(:db) { SCHEDULER_SPEC_DB }
  let(:now) { Time.utc(2026, 10, 30, 12) }
  let(:function_id) do
    extension_id = db[:extensions].insert(name: 'example', namespace: 'Legion::Extensions::Example')
    runner_id = db[:runners].insert(extension_id: extension_id, name: 'jobs', namespace: 'Legion::Extensions::Example::Runners::Jobs')
    db[:functions].insert(runner_id: runner_id, name: 'perform')
  end

  it 'actually uses the injected parser when deciding whether to dispatch' do
    parser = Class.new do
      def self.parse(_expression)
        Fugit.parse('2m')
      end
    end
    db[:schedules].insert(name: 'injected-parser', function_id: function_id, cron: 'external syntax', created: now - 60, last_run: now - 60)
    client = described_class.new(fugit: parser)
    expect(client.schedule_tasks(now: now)).to include(success: true, recorded: 0)
    expect(client.schedule_tasks(now: now + 60)).to include(success: true, recorded: 1)
  end

  it 'uses real settings overlays to change interval overlap behavior' do
    db[:schedules].insert(name: 'overlay', function_id: function_id, interval: 60, created: now)
    client = described_class.new
    client.schedule_tasks(now: now)
    expect(client.schedule_tasks(now: now + 60)[:recorded]).to eq(0)
    Legion::Settings.with_overlay(extensions: { scheduler: { overlap_policy: 'allow' } }) do
      expect(client.schedule_tasks(now: now + 60)[:recorded]).to eq(1)
    end
  end

  it 'makes direct durable submissions idempotent and returns plain task hashes' do
    client = described_class.new
    first = client.send_task(function_id: function_id, idempotency_key: 'manual-request', args: { value: 7 })
    second = client.send_task(function_id: function_id, idempotency_key: 'manual-request', args: { value: 9 })
    expect(first).to include(success: true, created: true, task: a_kind_of(Hash))
    expect(second).to include(success: true, created: false)
    expect(second[:task][:id]).to eq(first[:task][:id])
    expect(db[:task_dispatches].count).to eq(1)
    expect(Legion::JSON.load(db[:task_dispatches].first[:options])[:args]).to eq(value: 7)
  end

  it 'rejects missing targets before creating durable work' do
    client = described_class.new
    expect { client.send_task(function_id: 999, idempotency_key: 'missing') }.to raise_error(ArgumentError, /target function/)
    expect(db[:tasks].count).to eq(0)
  end
end
