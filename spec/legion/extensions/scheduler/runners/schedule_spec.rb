# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Scheduler::Runners::Schedule do
  subject(:client) { Legion::Extensions::Scheduler::Client.new }

  let(:db) { SCHEDULER_SPEC_DB }
  let(:now) { Time.utc(2026, 10, 30, 12) }
  let(:function_id) do
    extension_id = db[:extensions].insert(name: 'example', namespace: 'Legion::Extensions::Example', exchange: 'example')
    runner_id = db[:runners].insert(extension_id: extension_id, name: 'jobs', namespace: 'Legion::Extensions::Example::Runners::Jobs')
    db[:functions].insert(runner_id: runner_id, name: 'perform')
  end
  let(:deliveries) { [] }
  let(:queue) { Legion::Transport::Connection.channel.queue_declare_without_recording_topology('scheduler-spec') }

  before do
    queue.bind('example', routing_key: 'example.jobs.perform')
    queue.bind('task', routing_key: 'task.subtask.transform')
    queue.subscribe(manual_ack: false) { |info, properties, payload| deliveries << [info, properties, Legion::JSON.load(payload)] }
  end

  def create_schedule(**values)
    SCHEDULER_SPEC_DB[:schedules].insert({ name: 'recurring', function_id: function_id, interval: 60, created: now,
                                         payload: Legion::JSON.dump({ value: 7 }) }.merge(values))
  end

  it 'publishes an interval once per due slot and logs dispatch without claiming task completion' do
    schedule_id = create_schedule
    expect(client.schedule_tasks(now: now)).to include(success: true, recorded: 1)
    expect(client.schedule_tasks(now: now + 59)[:recorded]).to eq(0)
    expect(client.schedule_tasks(now: now + 60)[:recorded]).to eq(1)
    expect(deliveries.size).to eq(2)
    expect(db[:tasks].count).to eq(2)
    expect(db[:schedule_logs].where(schedule_id: schedule_id).all).to all(include(success: nil, status: 'dispatched'))
    expect(db[:schedules][id: schedule_id][:last_run]).to eq(now + 60)
  end

  it 'fails on an invalid cron without advancing the cursor or creating a task' do
    schedule_id = create_schedule(interval: nil, cron: 'not a cron')
    expect(client.schedule_tasks(now: now)).to include(success: false, recorded: 0)
    expect(db[:schedules][id: schedule_id][:last_run]).to be_nil
    expect(db[:tasks].count).to eq(0)
    expect(deliveries).to be_empty
  end

  it 'rejects conflicting interval and cron definitions' do
    create_schedule(cron: '* * * * *')
    expect(client.schedule_tasks(now: now)).to include(success: false, recorded: 0)
    expect(db[:tasks].count).to eq(0)
  end

  it 'does not repeat the cron boundary when polling at the exact same instant' do
    schedule_id = create_schedule(interval: nil, cron: '* * * * *', created: now - 60)
    expect(client.schedule_tasks(now: now)[:recorded]).to eq(1)
    expect(client.schedule_tasks(now: now)[:recorded]).to eq(0)
    expect(db[:schedules][id: schedule_id][:last_run]).to eq(now)
    expect(deliveries.size).to eq(1)
  end

  it 'waits for a one-shot timestamp and does not dispatch it again' do
    create_schedule(interval: nil, cron: '2026-10-30 12:01:00 UTC')
    expect(client.schedule_tasks(now: now)[:recorded]).to eq(0)
    expect(client.schedule_tasks(now: now + 60)[:recorded]).to eq(1)
    expect(client.schedule_tasks(now: now + 3600)[:recorded]).to eq(0)
    expect(deliveries.size).to eq(1)
  end

  it 'does not dispatch an inactive schedule' do
    create_schedule(active: false)
    expect(client.schedule_tasks(now: now)).to include(success: true, recorded: 0)
    expect(db[:tasks].count).to eq(0)
  end

  [nil, '{"value": <%= value %>}'].each do |transformation|
    it "keeps business input separate from authoritative target for #{transformation ? 'transform' : 'direct'} dispatch" do
      payload = { function_id: 999, function: 'hijack', runner_class: 'Bad', task_id: 999, principal_id: 'admin', value: 7 }
      context = { function_id: 999, function: 'hijack', runner_class: 'Bad', task_id: 999,
                  principal_id: 'service-id', principal_type: 'service', correlation_id: 'trace',
                  engine: 'erb', schema: { type: 'object' }, engine_options: { strict: true }, depth: 2 }
      create_schedule(payload: Legion::JSON.dump(payload), context: Legion::JSON.dump(context), transformation: transformation)
      expect(client.schedule_tasks(now: now)).to include(success: true, recorded: 1)
      info, properties, options = deliveries.fetch(0)
      expect(options).to include(function_id: function_id, function: 'perform', args: payload, principal_id: 'service-id',
                                 runner_class: 'Legion::Extensions::Example::Runners::Jobs', correlation_id: 'trace',
                                 engine: 'erb', schema: { type: 'object' }, engine_options: { strict: true }, depth: 2)
      expect(options[:task_id]).to eq(db[:tasks].first[:id])
      expect(properties.headers[:task_id]).to eq(options[:task_id])
      expect(info.routing_key).to eq(transformation ? 'task.subtask.transform' : 'example.jobs.perform')
      expect(db[:tasks].first[:status]).to eq(transformation ? 'transformer.queued' : 'task.queued')
      expect(Legion::JSON.load(db[:tasks].first[:function_args])).to eq(payload)
    end
  end

  it 'reports rejected publication without a dispatch log or advancing the schedule' do
    schedule_id = create_schedule
    queue.unbind('example', routing_key: 'example.jobs.perform')
    result = client.schedule_tasks(now: now)
    expect(result).to include(success: false, recorded: 0)
    expect(result[:errors]).to contain_exactly(include(schedule_id: schedule_id))
    expect(db[:schedules][id: schedule_id][:last_run]).to be_nil
    expect(db[:schedule_logs].count).to eq(0)
    expect(db[:tasks].count).to eq(1)
    expect(deliveries).to be_empty
  end

  it 'continues processing valid schedules after another definition fails' do
    create_schedule(interval: nil, cron: 'not a cron')
    create_schedule(name: 'valid')
    expect(client.schedule_tasks(now: now)).to include(success: false, recorded: 1)
    expect(deliveries.size).to eq(1)
  end

  it 'coalesces missed intervals to the latest slot' do
    schedule_id = create_schedule(created: now - 600)
    expect(client.schedule_tasks(now: now)[:recorded]).to eq(1)
    expect(db[:schedules][id: schedule_id][:last_run]).to eq(now)
  end

  it 'bounds catch-up and preserves remaining slots for later polls' do
    schedule_id = create_schedule(created: now - 180, misfire_policy: 'catch_up')
    Legion::Settings.with_overlay(extensions: { scheduler: { max_catch_up: 2 } }) do
      expect(client.schedule_tasks(now: now)[:recorded]).to eq(2)
      expect(db[:schedules][id: schedule_id][:last_run]).to eq(now - 120)
      expect(client.schedule_tasks(now: now)[:recorded]).to eq(2)
    end
    expect(db[:schedules][id: schedule_id][:last_run]).to eq(now)
    expect(deliveries.size).to eq(4)
  end

  it 'advances an old skipped cron slot without creating a task' do
    schedule_id = create_schedule(interval: nil, cron: '0 * * * *', created: now - 7200, misfire_policy: 'skip')
    expect(client.schedule_tasks(now: now + 120)).to include(recorded: 0, skipped: 1)
    expect(db[:schedules][id: schedule_id][:last_run]).to eq(now)
    expect(db[:tasks].count).to eq(0)
    expect(client.schedule_tasks(now: now + 121)).to include(recorded: 0, skipped: 0)
  end

  it 'rejects unsupported misfire policies instead of falling through to dispatch' do
    create_schedule(misfire_policy: 'replace')
    expect(client.schedule_tasks(now: now)).to include(success: false, recorded: 0)
    expect(db[:tasks].count).to eq(0)
  end
end
