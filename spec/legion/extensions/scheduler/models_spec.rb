# frozen_string_literal: true

require 'spec_helper'
require 'sequel'

# Use an in-memory SQLite database to test the models
DB = Sequel.sqlite unless defined?(DB)

DB.create_table?(:functions) do
  primary_key :id
  String :name, null: false
end

DB.create_table?(:schedules) do
  primary_key :id
  foreign_key :function_id, :functions, null: true
  String :name, null: false
  Integer :interval, null: true
  String :cron, null: true
  Integer :task_ttl, null: true
  TrueClass :active, default: true
  DateTime :last_run, null: true
  DateTime :created, null: true
  DateTime :updated, null: true
  String :payload, null: true
  String :transformation, null: true
end

DB.create_table?(:schedule_logs) do
  primary_key :id
  foreign_key :schedule_id, :schedules, null: true
  foreign_key :function_id, :functions, null: true
  TrueClass :success, null: true
  String :status, null: true
  DateTime :created, null: true
end

# Define Sequel models against the in-memory DB
module SchedulerModels
  class Schedule < Sequel::Model(DB[:schedules])
    one_to_many :schedule_logs, class: 'SchedulerModels::ScheduleLog'
  end

  class ScheduleLog < Sequel::Model(DB[:schedule_logs])
    many_to_one :schedule, class: 'SchedulerModels::Schedule'
  end
end

RSpec.describe 'Schedule model' do
  before do
    DB[:schedule_logs].delete
    DB[:schedules].delete
    DB[:functions].delete
  end

  describe 'create and read' do
    it 'creates a schedule record' do
      s = SchedulerModels::Schedule.create(name: 'test_schedule', active: true, interval: 60)
      expect(s.id).not_to be_nil
      expect(s.name).to eq('test_schedule')
      expect(s.interval).to eq(60)
      expect(s.active).to eq(true)
    end

    it 'reads a schedule by id' do
      created = SchedulerModels::Schedule.create(name: 'read_test', active: true, interval: 30)
      found = SchedulerModels::Schedule[created.id]
      expect(found).not_to be_nil
      expect(found.name).to eq('read_test')
    end

    it 'finds active schedules' do
      SchedulerModels::Schedule.create(name: 'active_one', active: true, interval: 60)
      SchedulerModels::Schedule.create(name: 'inactive_one', active: false, interval: 120)
      active = SchedulerModels::Schedule.where(active: true).all
      expect(active.map(&:name)).to include('active_one')
      expect(active.map(&:name)).not_to include('inactive_one')
    end
  end

  describe 'update' do
    it 'updates a schedule record' do
      s = SchedulerModels::Schedule.create(name: 'update_test', active: true, interval: 60)
      s.update(interval: 120)
      refreshed = SchedulerModels::Schedule[s.id]
      expect(refreshed.interval).to eq(120)
    end

    it 'updates last_run' do
      s = SchedulerModels::Schedule.create(name: 'run_test', active: true, interval: 30)
      expect(s.last_run).to be_nil
      now = Time.now
      s.update(last_run: now)
      refreshed = SchedulerModels::Schedule[s.id]
      expect(refreshed.last_run).not_to be_nil
    end
  end

  describe 'delete' do
    it 'deletes a schedule record' do
      s = SchedulerModels::Schedule.create(name: 'delete_test', active: true, interval: 60)
      id = s.id
      s.destroy
      expect(SchedulerModels::Schedule[id]).to be_nil
    end
  end

  describe 'cron field' do
    it 'stores a cron expression' do
      s = SchedulerModels::Schedule.create(name: 'cron_test', active: true, cron: '*/5 * * * *')
      found = SchedulerModels::Schedule[s.id]
      expect(found.cron).to eq('*/5 * * * *')
    end
  end

  describe 'payload field' do
    it 'stores a JSON payload string' do
      s = SchedulerModels::Schedule.create(name: 'payload_test', active: true, interval: 60,
                                           payload: '{"key":"value"}')
      found = SchedulerModels::Schedule[s.id]
      expect(found.payload).to eq('{"key":"value"}')
    end
  end

  describe 'transformation field' do
    it 'stores an ERB transformation string' do
      transform = '{"result":"<%= value %>"}'
      s = SchedulerModels::Schedule.create(name: 'transform_test', active: true, interval: 60,
                                           transformation: transform)
      found = SchedulerModels::Schedule[s.id]
      expect(found.transformation).to eq(transform)
    end
  end
end

RSpec.describe 'ScheduleLog model' do
  before do
    DB[:schedule_logs].delete
    DB[:schedules].delete
    DB[:functions].delete
  end

  describe 'create and read' do
    it 'creates a schedule log entry' do
      s = SchedulerModels::Schedule.create(name: 'log_parent', active: true, interval: 60)
      log = SchedulerModels::ScheduleLog.create(schedule_id: s.id, success: true, status: 'dispatched')
      expect(log.id).not_to be_nil
      expect(log.success).to eq(true)
      expect(log.status).to eq('dispatched')
    end

    it 'reads a log by id' do
      s = SchedulerModels::Schedule.create(name: 'log_read', active: true, interval: 60)
      log = SchedulerModels::ScheduleLog.create(schedule_id: s.id, success: false, status: 'failed')
      found = SchedulerModels::ScheduleLog[log.id]
      expect(found).not_to be_nil
      expect(found.status).to eq('failed')
    end

    it 'stores success flag correctly' do
      s = SchedulerModels::Schedule.create(name: 'success_test', active: true, interval: 60)
      log_true = SchedulerModels::ScheduleLog.create(schedule_id: s.id, success: true, status: 'ok')
      log_false = SchedulerModels::ScheduleLog.create(schedule_id: s.id, success: false, status: 'err')
      expect(SchedulerModels::ScheduleLog[log_true.id].success).to eq(true)
      expect(SchedulerModels::ScheduleLog[log_false.id].success).to eq(false)
    end
  end

  describe 'delete' do
    it 'deletes a log entry' do
      s = SchedulerModels::Schedule.create(name: 'del_log', active: true, interval: 60)
      log = SchedulerModels::ScheduleLog.create(schedule_id: s.id, success: true, status: 'done')
      id = log.id
      log.destroy
      expect(SchedulerModels::ScheduleLog[id]).to be_nil
    end
  end

  describe 'multiple logs per schedule' do
    it 'creates multiple log entries for the same schedule' do
      s = SchedulerModels::Schedule.create(name: 'multi_log', active: true, interval: 60)
      3.times { |i| SchedulerModels::ScheduleLog.create(schedule_id: s.id, success: true, status: "run_#{i}") }
      logs = SchedulerModels::ScheduleLog.where(schedule_id: s.id).all
      expect(logs.size).to eq(3)
    end
  end
end
