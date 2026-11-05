# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Scheduler::Client do
  let(:db) { SCHEDULER_SPEC_DB }
  let(:now) { Time.utc(2026, 10, 30, 12) }
  let(:function_id) do
    extension_id = db[:extensions].insert(name: 'example', namespace: 'Legion::Extensions::Example', exchange: 'example')
    runner_id = db[:runners].insert(extension_id: extension_id, name: 'jobs', namespace: 'Legion::Extensions::Example::Runners::Jobs')
    db[:functions].insert(runner_id: runner_id, name: 'perform')
  end
  let(:deliveries) { [] }

  before do
    queue = Legion::Transport::Connection.channel.queue_declare_without_recording_topology('scheduler-client-spec')
    queue.bind('example', routing_key: 'example.jobs.perform')
    queue.subscribe(manual_ack: false) { |_info, _properties, payload| deliveries << Legion::JSON.load(payload) }
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

  it 'uses real settings overlays to skip missed intervals' do
    schedule_id = db[:schedules].insert(name: 'overlay', function_id: function_id, interval: 60, created: now - 90)
    client = described_class.new
    Legion::Settings.with_overlay(extensions: { scheduler: { misfire_policy: 'skip', misfire_grace_seconds: 10 } }) do
      expect(client.schedule_tasks(now: now)).to include(recorded: 0, skipped: 1)
    end
    expect(db[:schedules][id: schedule_id][:last_run]).to eq(now - 30)
    expect(deliveries).to be_empty
    expect(client.schedule_tasks(now: now + 30)[:recorded]).to eq(1)
  end

  it 'publishes direct submissions and returns plain persisted task hashes' do
    client = described_class.new
    first = client.send_task(function_id: function_id, args: { value: 7 })
    second = client.send_task(function_id: function_id, args: { value: 9 })
    expect(first).to include(success: true, task: a_kind_of(Hash))
    expect(second).to include(success: true, task: a_kind_of(Hash))
    expect(second[:task][:id]).not_to eq(first[:task][:id])
    expect(deliveries.map { |message| message[:args] }).to eq([{ value: 7 }, { value: 9 }])
    expect(db[:tasks].count).to eq(2)
  end

  it 'rejects missing targets before creating a task' do
    client = described_class.new
    expect { client.send_task(function_id: 999) }.to raise_error(ArgumentError, /target function/)
    expect(db[:tasks].count).to eq(0)
  end
end
