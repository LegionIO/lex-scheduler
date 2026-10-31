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

  def create_schedule(**values)
    SCHEDULER_SPEC_DB[:schedules].insert({ name: 'recurring', function_id: function_id, interval: 60, created: now,
                                         payload: Legion::JSON.dump({ value: 7 }) }.merge(values))
  end

  def complete_task(task_id:, status: :completed)
    claim = Legion::Data::TaskExecution.claim_task(task_id: task_id, owner: 'scheduler-spec')
    Legion::Data::TaskExecution.complete_task(task_id: task_id, token: claim[:token],
                                              status: client.task_status(name: status), result: { success: status == :completed })
  end

  it 'records only one logical occurrence, task and dispatch when two schedulers race' do
    schedule_id = create_schedule
    start = Queue.new
    workers = Array.new(2) do
      Thread.new do
        start.pop
        Legion::Extensions::Scheduler::Client.new.schedule_tasks(now: now)
      end
    end
    2.times { start << true }
    results = workers.map(&:value)
    expect(results).to all(include(success: true))
    expect(db[:schedule_occurrences].where(schedule_id: schedule_id).count).to eq(1)
    expect(db[:tasks].count).to eq(1)
    expect(db[:task_dispatches].count).to eq(1)
    expect(client.schedule_tasks(now: now)[:recorded]).to eq(0)
  end

  it 'fails closed on an invalid cron without advancing the cursor or creating an intent' do
    schedule_id = create_schedule(interval: nil, cron: 'not a cron')
    expect(client.schedule_tasks(now: now)).to include(success: false, recorded: 0)
    expect(db[:schedules][id: schedule_id][:last_run]).to be_nil
    expect(db[:schedule_occurrences].count).to eq(0)
    expect(db[:task_dispatches].count).to eq(0)
  end

  it 'rejects conflicting interval and cron definitions' do
    create_schedule(cron: '* * * * *')
    expect(client.schedule_tasks(now: now)).to include(success: false, recorded: 0)
    expect(db[:tasks].count).to eq(0)
  end

  it 'does not repeat the cron boundary when polling at the exact same instant' do
    create_schedule(interval: nil, cron: '* * * * *', created: now - 60, overlap_policy: 'allow')
    expect(client.schedule_tasks(now: now)[:recorded]).to eq(1)
    expect(client.schedule_tasks(now: now)[:recorded]).to eq(0)
    expect(db[:schedule_occurrences].first[:scheduled_at]).to eq(now)
  end

  [nil, '{"value": <%= value %>}'].each do |transformation|
    it "keeps stored business input separate from authoritative target for #{transformation ? 'transform' : 'direct'} dispatch" do
      payload = { function_id: 999, function: 'hijack', runner_class: 'Bad', task_id: 999, principal_id: 'admin', value: 7 }
      context = { function_id: 999, function: 'hijack', runner_class: 'Bad', task_id: 999,
                  principal_id: 'service-id', principal_type: 'service', tenant_id: 'tenant', correlation_id: 'trace',
                  engine: 'erb', schema: { type: 'object' }, engine_options: { strict: true }, depth: 2 }
      create_schedule(payload: Legion::JSON.dump(payload), context: Legion::JSON.dump(context), transformation: transformation)
      expect(client.schedule_tasks(now: now)).to include(success: true, recorded: 1)
      options = Legion::JSON.load(db[:task_dispatches].first[:options])
      expect(options).to include(function_id: function_id, function: 'perform', args: payload, principal_id: 'service-id',
                                 runner_class: 'Legion::Extensions::Example::Runners::Jobs', tenant_id: 'tenant', correlation_id: 'trace',
                                 engine: 'erb', schema: { type: 'object' }, engine_options: { strict: true }, depth: 2)
      expect(options[:task_id]).to eq(db[:tasks].first[:id])
      expect(options[:occurrence_id]).to eq(db[:schedule_occurrences].first[:id])
    end
  end

  it 'records canonical dispatch and occurrence identities despite obsolete local overrides' do
    create_schedule(transformation: '{"value": 7}', context: Legion::JSON.dump({ correlation_id: 'trace' }))
    Legion::Settings.with_overlay(task_execution: { statuses: { transformer_queued: 'local.queued' },
                                                  routes: { transform: 'local.transform' }, message_types: { transform: 'local.transform' },
                                                  protocol: { metadata_fields: [:untrusted] } },
                                  extensions:     { scheduler: { occurrence_statuses: { recorded: 'local.recorded' } } }) do
      expect(client.schedule_tasks(now: now)).to include(success: true, recorded: 1)
    end
    expect(db[:tasks].first[:status]).to eq('transformer.queued')
    expect(db[:schedule_occurrences].first[:status]).to eq('schedule.recorded')
    dispatch = db[:task_dispatches].first
    expect(dispatch[:message_type]).to eq('transform')
    expect(Legion::JSON.load(dispatch[:options])).to include(routing_key: 'task.subtask.transform', correlation_id: 'trace')
  end

  it 'rolls back occurrence, task and cursor if durable intent recording fails' do
    schedule_id = create_schedule
    allow(Legion::Data::TaskExecution).to receive(:enqueue_dispatch).and_raise(Sequel::DatabaseError, 'storage unavailable')
    expect(client.schedule_tasks(now: now)).to include(success: false, recorded: 0)
    expect(db[:schedules][id: schedule_id][:last_run]).to be_nil
    expect(db[:schedule_occurrences].count).to eq(0)
    expect(db[:tasks].count).to eq(0)
  end

  it 'keeps rejected dispatch pending and recoverable without recording delivery or completion' do
    create_schedule
    client.schedule_tasks(now: now)
    relay = Object.new.extend(Legion::Extensions::Tasker::Runners::Outbox)
    Legion::Settings.with_overlay(transport: { messages: { encrypt: false } }) do
      expect(relay.dispatch_pending(owner: 'publisher')).to include(success: false, released: 1, delivered: 0)
    end
    expect(client.schedule_tasks(now: now + 120)[:recorded]).to eq(0)
    expect(db[:schedule_occurrences].first).to include(delivered_at: nil, completed_at: nil)
    expect(db[:schedule_logs].first[:success]).to be_nil
    channel = Legion::Transport::Connection.channel
    queue = channel.queue_declare_without_recording_topology('scheduler-spec')
    queue.bind('example', routing_key: 'example.jobs.perform')
    Legion::Settings.with_overlay(transport: { messages: { encrypt: false } }) do
      expect(relay.dispatch_pending(owner: 'recovery')).to include(success: true, delivered: 1, released: 0)
    end
    client.schedule_tasks(now: now)
    expect(db[:schedule_occurrences].first[:delivered_at]).not_to be_nil
    expect(db[:tasks].count).to eq(1)
  end

  it 'tracks accepted publication separately from actual task completion' do
    create_schedule
    client.schedule_tasks(now: now)
    dispatch = Legion::Data::TaskExecution.claim_dispatches(owner: 'publisher').first
    Legion::Data::TaskExecution.ack_dispatch(dispatch_id: dispatch[:id], token: dispatch[:token])
    Legion::Settings.with_overlay(extensions: { scheduler: { occurrence_statuses: { delivered: 'local.delivered' } } }) do
      client.schedule_tasks(now: now)
    end
    expect(db[:schedule_occurrences].first[:status]).to eq('schedule.delivered')
    expect(db[:schedule_occurrences].first[:delivered_at]).not_to be_nil
    expect(db[:schedule_occurrences].first[:completed_at]).to be_nil
    expect(db[:schedule_logs].where(success: true).count).to eq(0)
  end

  it 'recognizes persisted completion despite different local lifecycle settings' do
    create_schedule(interval_basis: 'completed')
    client.schedule_tasks(now: now)
    expect(client.schedule_tasks(now: now + 600)[:recorded]).to eq(0)
    task_id = db[:tasks].first[:id]
    complete_task(task_id: task_id)
    finished_at = db[:tasks][id: task_id][:completed_at]
    Legion::Settings.with_overlay(task_execution: { statuses: { completed: 'local.completed' }, terminal_statuses: [] }) do
      expect(client.schedule_tasks(now: finished_at + 59)[:recorded]).to eq(0)
      expect(client.schedule_tasks(now: finished_at + 60)[:recorded]).to eq(1)
    end
    expect(db[:schedule_occurrences].order(:id).first[:completed_at]).to eq(finished_at)
  end

  it 'waits for every multiplied child before completing a scheduled occurrence' do
    create_schedule(interval_basis: 'completed')
    client.schedule_tasks(now: now)
    parent = db[:tasks].first
    child = Legion::Data::TaskExecution.create_task(values: { parent_id: parent[:id], function_id: function_id }, idempotency_key: 'fanout-child')[:task]
    complete_task(task_id: parent[:id], status: :multiplied)
    expect(client.schedule_tasks(now: Time.now + 600)[:recorded]).to eq(0)
    complete_task(task_id: child[:id])
    finished_at = db[:tasks][id: child[:id]][:completed_at]
    expect(client.schedule_tasks(now: finished_at + 60)[:recorded]).to eq(1)
  end

  it 'bounds ancestry traversal with current scheduler-local policy without changing persisted outcomes' do
    create_schedule(interval_basis: 'completed')
    client.schedule_tasks(now: now)
    parent = db[:tasks].first
    child = Legion::Data::TaskExecution.create_task(values: { parent_id: parent[:id] }, idempotency_key: 'child')[:task]
    grandchild = Legion::Data::TaskExecution.create_task(values: { parent_id: child[:id] }, idempotency_key: 'grandchild')[:task]
    complete_task(task_id: parent[:id], status: :multiplied)
    complete_task(task_id: child[:id], status: :multiplied)
    complete_task(task_id: grandchild[:id])
    finished_at = db[:tasks][id: grandchild[:id]][:completed_at]

    Legion::Settings.with_overlay(extensions: { scheduler: { execution: { max_depth: 1 } } }) do
      expect(client.schedule_tasks(now: finished_at + 60)).to include(success: false, recorded: 0)
    end
    expect(db[:schedule_occurrences].first[:completed_at]).to be_nil
    expect(db[:tasks][id: grandchild[:id]][:status]).to eq('task.completed')
    Legion::Settings.with_overlay(extensions: { scheduler: { execution: { max_depth: 2 } } }) do
      expect(client.schedule_tasks(now: finished_at + 60)).to include(success: true, recorded: 1)
    end
  end

  it 'does not repeat ambiguous unknown external effects' do
    create_schedule(interval_basis: 'completed')
    client.schedule_tasks(now: now)
    complete_task(task_id: db[:tasks].first[:id], status: :unknown)
    expect(client.schedule_tasks(now: Time.now + 600)[:recorded]).to eq(0)
    expect(db[:schedule_occurrences].first[:completed_at]).to be_nil
    expect(db[:schedule_occurrences].first[:status]).to eq(client.task_status(name: :unknown))
  end

  it 'coalesces missed scheduled intervals to the latest slot' do
    create_schedule(created: now - 600, overlap_policy: 'allow')
    expect(client.schedule_tasks(now: now)[:recorded]).to eq(1)
    expect(db[:schedule_occurrences].first[:scheduled_at]).to eq(now)
  end

  it 'bounds catch-up and preserves remaining slots for later polls' do
    create_schedule(created: now - 180, overlap_policy: 'allow', misfire_policy: 'catch_up')
    Legion::Settings.with_overlay(extensions: { scheduler: { max_catch_up: 2 } }) do
      expect(client.schedule_tasks(now: now)[:recorded]).to eq(2)
      expect(client.schedule_tasks(now: now)[:recorded]).to eq(2)
    end
    expect(db[:schedule_occurrences].order(:scheduled_at).select_map(:scheduled_at)).to eq([now - 180, now - 120, now - 60, now])
  end

  it 'records an old skipped cron occurrence without creating a task' do
    create_schedule(interval: nil, cron: '0 * * * *', created: now - 7200, misfire_policy: 'skip')
    expect(client.schedule_tasks(now: now + 120)).to include(recorded: 0, skipped: 1)
    expect(db[:tasks].count).to eq(0)
    expect(client.schedule_tasks(now: now + 121)).to include(recorded: 0, skipped: 0)
  end

  it 'rejects unsupported policies instead of falling through to dispatch' do
    create_schedule(overlap_policy: 'replace')
    expect(client.schedule_tasks(now: now)).to include(success: false, recorded: 0)
    expect(db[:tasks].count).to eq(0)
  end
end
