# frozen_string_literal: true

require 'spec_helper'
require 'fugit'

# Stub framework dependencies before loading the runner
module Legion
  module Extensions
    module Helpers
      module Transport; end unless defined?(Legion::Extensions::Helpers::Transport)
      module Cache; end unless defined?(Legion::Extensions::Helpers::Cache)
      module Data; end unless defined?(Legion::Extensions::Helpers::Data)
      module Lex; end unless defined?(Legion::Extensions::Helpers::Lex)
    end

    module Scheduler
      module Transport
        module Messages
          unless defined?(Refresh)
            class Refresh
              def initialize(**); end
              def publish; end
            end
          end

          unless defined?(SendTask)
            class SendTask
              def initialize(**); end
              def publish; end
            end
          end
        end
      end
    end
  end

  unless defined?(Legion::Cache)
    module Cache
      def self.set(*); end
      def self.get(_key) = nil
    end
  end

  unless defined?(Legion::Settings)
    module Settings
      def self.[](key)
        @store ||= {}
        @store[key]
      end

      def self.[]=(key, val)
        @store ||= {}
        @store[key] = val
      end
    end
  end

  unless defined?(Legion::Data)
    module Data
      module Model
        unless defined?(Function)
          class Function
            def self.[](_id) = nil
            def values = { name: 'test_func' }
          end
        end

        unless defined?(Schedule)
          class Schedule # rubocop:disable Lint/EmptyClass
          end
        end

        unless defined?(ScheduleLog)
          class ScheduleLog
            def self.insert(**); end
          end
        end
      end
    end
  end

  unless defined?(Legion::Transport)
    module Transport
      module Messages
        unless defined?(Dynamic)
          class Dynamic
            def initialize(**); end
            def publish; end
          end
        end
      end
    end
  end

  unless defined?(Legion::JSON)
    module JSON
      def self.load(str)
        ::JSON.parse(str, symbolize_names: true)
      rescue StandardError
        {}
      end
    end
  end

  unless defined?(Legion::Logging)
    module Logging
      def self.debug(*); end
    end
  end
end

require 'json'

# Stub Sequel constants used in the runner
unless defined?(Sequel)
  module Sequel
    CURRENT_TIMESTAMP = :CURRENT_TIMESTAMP unless defined?(CURRENT_TIMESTAMP)
    def self.lit(str) = str
  end
end

require 'legion/extensions/scheduler/runners/schedule'

RSpec.describe Legion::Extensions::Scheduler::Runners::Schedule do
  let(:runner) do
    klass = Class.new do
      include Legion::Extensions::Scheduler::Runners::Schedule

      def log
        @log ||= Class.new { def debug(*); end }.new
      end

      def models_class
        Legion::Data::Model
      end
    end
    klass.new
  end

  before do
    allow(Legion::Settings).to receive(:[]).with(:client).and_return({ name: 'test-node' })
  end

  describe '#push_refresh' do
    it 'publishes a Refresh message' do
      msg = instance_double(Legion::Extensions::Scheduler::Transport::Messages::Refresh, publish: nil)
      allow(Legion::Extensions::Scheduler::Transport::Messages::Refresh).to receive(:new).and_return(msg)
      runner.push_refresh
      expect(Legion::Extensions::Scheduler::Transport::Messages::Refresh).to have_received(:new)
    end
  end

  describe '#refresh' do
    it 'is a no-op (leadership enforced at actor level via Singleton mixin)' do
      expect { runner.refresh }.not_to raise_error
    end
  end

  describe '#send_task' do
    context 'when no transformation is present' do
      it 'publishes a Dynamic message directly' do
        msg = instance_double(Legion::Transport::Messages::Dynamic, publish: nil)
        allow(Legion::Transport::Messages::Dynamic).to receive(:new).and_return(msg)
        runner.send_task(function: 'my_func', function_id: 1)
        expect(Legion::Transport::Messages::Dynamic).to have_received(:new)
      end

      it 'does not publish a SendTask message' do
        msg = instance_double(Legion::Transport::Messages::Dynamic, publish: nil)
        allow(Legion::Transport::Messages::Dynamic).to receive(:new).and_return(msg)
        expect(Legion::Extensions::Scheduler::Transport::Messages::SendTask).not_to receive(:new)
        runner.send_task(function: 'my_func', function_id: 1)
      end
    end

    context 'when transformation is present' do
      it 'publishes a SendTask message via transform routing' do
        msg = instance_double(Legion::Extensions::Scheduler::Transport::Messages::SendTask, publish: nil)
        allow(Legion::Extensions::Scheduler::Transport::Messages::SendTask).to receive(:new).and_return(msg)
        runner.send_task(function: 'my_func', function_id: 1, transformation: '{"key":"<%= val %>"}')
        expect(Legion::Extensions::Scheduler::Transport::Messages::SendTask).to have_received(:new)
      end

      it 'sets routing_key to task.subtask.transform' do
        msg = instance_double(Legion::Extensions::Scheduler::Transport::Messages::SendTask, publish: nil)
        allow(Legion::Extensions::Scheduler::Transport::Messages::SendTask).to receive(:new) do |**opts|
          expect(opts[:routing_key]).to eq('task.subtask.transform')
          msg
        end
        runner.send_task(function: 'my_func', function_id: 1, transformation: '{"key":"val"}')
      end

      it 'sets exchange to task' do
        msg = instance_double(Legion::Extensions::Scheduler::Transport::Messages::SendTask, publish: nil)
        allow(Legion::Extensions::Scheduler::Transport::Messages::SendTask).to receive(:new) do |**opts|
          expect(opts[:exchange]).to eq('task')
          msg
        end
        runner.send_task(function: 'my_func', function_id: 1, transformation: '{"key":"val"}')
      end

      it 'does not publish a Dynamic message' do
        msg = instance_double(Legion::Extensions::Scheduler::Transport::Messages::SendTask, publish: nil)
        allow(Legion::Extensions::Scheduler::Transport::Messages::SendTask).to receive(:new).and_return(msg)
        expect(Legion::Transport::Messages::Dynamic).not_to receive(:new)
        runner.send_task(function: 'my_func', function_id: 1, transformation: '{"key":"val"}')
      end
    end

    it 'passes all opts (including extra keys) through to the Dynamic message' do
      msg = instance_double(Legion::Transport::Messages::Dynamic, publish: nil)
      allow(Legion::Transport::Messages::Dynamic).to receive(:new) do |**opts|
        expect(opts).to have_key(:relationship_id)
        expect(opts[:relationship_id]).to eq(99)
        msg
      end
      runner.send_task(function: 'my_func', function_id: 1, relationship_id: 99)
    end
  end

  describe '#schedule_tasks' do
    # Leadership is now enforced at the actor level via Singleton mixin.
    # The runner always executes when called — the actor decides whether to call it.

    context 'when called' do
      it 'queries for active schedules' do
        expect(Legion::Data::Model::Schedule).to receive(:where).with(active: 1).and_return([])
        runner.schedule_tasks
      end

      context 'with an interval-based schedule that has not elapsed' do
        let(:row) do
          double('row', values: {
                   interval:       60,
                   cron:           nil,
                   last_run:       Time.now - 10,
                   function_id:    1,
                   payload:        '{}',
                   transformation: nil,
                   task_ttl:       nil
                 })
        end

        before do
          allow(Legion::Data::Model::Schedule).to receive(:where).with(active: 1).and_return([row])
        end

        it 'skips the schedule' do
          expect(runner).not_to receive(:send_task)
          runner.schedule_tasks
        end
      end

      context 'with an interval-based schedule whose interval has elapsed' do
        let(:func) { double('function', values: { name: 'run_job' }) }
        let(:row) do
          double('row', values: {
                   interval:       30,
                   cron:           nil,
                   last_run:       Time.now - 60,
                   function_id:    1,
                   payload:        '{}',
                   transformation: nil,
                   task_ttl:       nil
                 })
        end

        before do
          allow(Legion::Data::Model::Schedule).to receive(:where).with(active: 1).and_return([row])
          allow(Legion::Data::Model::Function).to receive(:[]).with(1).and_return(func)
          allow(row).to receive(:update)
        end

        it 'calls send_task' do
          expect(runner).to receive(:send_task)
          runner.schedule_tasks
        end

        it 'updates last_run after dispatching' do
          allow(runner).to receive(:send_task)
          expect(row).to receive(:update).with(last_run: Sequel::CURRENT_TIMESTAMP)
          runner.schedule_tasks
        end
      end

      context 'with a cron-based schedule' do
        let(:func) { double('function', values: { name: 'cron_job' }) }

        it 'skips when last_run is after the previous cron time' do
          # A schedule that just ran - last_run is very recent
          row = double('row', values: {
                         interval:       nil,
                         cron:           '*/5 * * * *',
                         last_run:       Time.now,
                         function_id:    1,
                         payload:        '{}',
                         transformation: nil,
                         task_ttl:       nil
                       })
          allow(Legion::Data::Model::Schedule).to receive(:where).with(active: 1).and_return([row])
          expect(runner).not_to receive(:send_task)
          runner.schedule_tasks
        end

        it 'dispatches when last_run is before the previous cron time' do
          func = double('function', values: { name: 'cron_job' })
          # last_run is long ago, so previous cron time has passed since then
          row = double('row', values: {
                         interval:       nil,
                         cron:           '*/5 * * * *',
                         last_run:       Time.now - 3600,
                         function_id:    1,
                         payload:        '{}',
                         transformation: nil,
                         task_ttl:       nil
                       })
          allow(Legion::Data::Model::Schedule).to receive(:where).with(active: 1).and_return([row])
          allow(Legion::Data::Model::Function).to receive(:[]).with(1).and_return(func)
          allow(row).to receive(:update)
          allow(Legion::Data::Model::ScheduleLog).to receive(:insert)
          expect(runner).to receive(:send_task)
          runner.schedule_tasks
        end
      end

      context 'with a schedule that has nil last_run (new schedule)' do
        let(:func) { double('function', values: { name: 'new_job' }) }
        let(:row) do
          double('row', values: {
                   interval:       60,
                   cron:           nil,
                   last_run:       nil,
                   function_id:    1,
                   payload:        '{}',
                   transformation: nil,
                   task_ttl:       nil
                 })
        end

        before do
          allow(Legion::Data::Model::Schedule).to receive(:where).with(active: 1).and_return([row])
          allow(Legion::Data::Model::Function).to receive(:[]).with(1).and_return(func)
          allow(row).to receive(:update)
          allow(Legion::Data::Model::ScheduleLog).to receive(:insert)
        end

        it 'dispatches without crashing' do
          expect { runner.schedule_tasks }.not_to raise_error
        end

        it 'calls send_task' do
          expect(runner).to receive(:send_task)
          runner.schedule_tasks
        end
      end

      context 'with a schedule whose function_id returns nil' do
        let(:row) do
          double('row', values: {
                   interval:       60,
                   cron:           nil,
                   last_run:       Time.now - 120,
                   function_id:    999,
                   payload:        '{}',
                   transformation: nil,
                   task_ttl:       nil
                 })
        end

        before do
          allow(Legion::Data::Model::Schedule).to receive(:where).with(active: 1).and_return([row])
          allow(Legion::Data::Model::Function).to receive(:[]).with(999).and_return(nil)
        end

        it 'skips the schedule without crashing' do
          expect(runner).not_to receive(:send_task)
          expect { runner.schedule_tasks }.not_to raise_error
        end
      end

      context 'with an interval-based schedule that dispatches' do
        let(:func) { double('function', values: { name: 'run_job' }) }
        let(:row) do
          double('row', values: {
                   interval:       30,
                   cron:           nil,
                   last_run:       Time.now - 60,
                   function_id:    1,
                   payload:        '{}',
                   transformation: nil,
                   task_ttl:       nil,
                   id:             42
                 })
        end

        before do
          allow(Legion::Data::Model::Schedule).to receive(:where).with(active: 1).and_return([row])
          allow(Legion::Data::Model::Function).to receive(:[]).with(1).and_return(func)
          allow(row).to receive(:update)
          allow(runner).to receive(:send_task)
        end

        it 'writes a ScheduleLog entry after dispatching' do
          expect(Legion::Data::Model::ScheduleLog).to receive(:insert).with(
            hash_including(schedule_id: 42, function_id: 1, success: true, status: 'dispatched')
          )
          runner.schedule_tasks
        end
      end
    end
  end
end
