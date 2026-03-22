# frozen_string_literal: true

require 'spec_helper'
require 'fugit'

# Stub framework dependencies before loading the client
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

  module Extensions
    module Scheduler
      # Stub Data::Model for standalone spec loading (no legion-data)
      module Data
        module Model
          unless defined?(Legion::Extensions::Scheduler::Data::Model::Schedule)
            class Schedule # rubocop:disable Lint/EmptyClass
            end
          end

          unless defined?(Legion::Extensions::Scheduler::Data::Model::ScheduleLog)
            class ScheduleLog
              def self.insert(**); end
            end
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

unless defined?(Sequel)
  module Sequel
    CURRENT_TIMESTAMP = :CURRENT_TIMESTAMP unless defined?(CURRENT_TIMESTAMP)
    def self.lit(str) = str
  end
end

require 'legion/extensions/scheduler/client'

RSpec.describe Legion::Extensions::Scheduler::Client do
  let(:mock_model) do
    mod = Module.new
    mod.const_set(:Schedule, Class.new)
    mod.const_set(:ScheduleLog, Class.new { def self.insert(**); end })
    mod.const_set(:Function, Class.new { def self.[](_id) = nil })
    mod
  end

  subject(:client) { described_class.new(data_model: mock_model) }

  describe '#initialize' do
    it 'creates a client with default data model' do
      c = described_class.new
      expect(c.models_class).to eq(Legion::Extensions::Scheduler::Data::Model)
    end

    it 'accepts an injected data model' do
      expect(client.models_class).to eq(mock_model)
    end

    it 'accepts an injected fugit module' do
      mock_fugit = double('Fugit')
      c = described_class.new(fugit: mock_fugit)
      expect(c).to respond_to(:schedule_tasks)
    end
  end

  describe '#models_class' do
    it 'returns the injected data model' do
      expect(client.models_class).to eq(mock_model)
    end

    it 'returns Legion::Extensions::Scheduler::Data::Model when no injection' do
      c = described_class.new
      expect(c.models_class).to eq(Legion::Extensions::Scheduler::Data::Model)
    end
  end

  describe '#log' do
    it 'returns Legion::Logging when available' do
      expect(client.log).to eq(Legion::Logging)
    end
  end

  describe '#settings' do
    it 'returns a hash with options key' do
      expect(client.settings).to eq({ options: {} })
    end
  end

  describe '#push_refresh' do
    it 'delegates to Runners::Schedule#push_refresh' do
      msg = instance_double(Legion::Extensions::Scheduler::Transport::Messages::Refresh, publish: nil)
      allow(Legion::Extensions::Scheduler::Transport::Messages::Refresh).to receive(:new).and_return(msg)
      client.push_refresh
      expect(Legion::Extensions::Scheduler::Transport::Messages::Refresh).to have_received(:new)
    end
  end

  describe '#refresh' do
    it 'is a no-op (leadership enforced at actor level via Singleton mixin)' do
      expect { client.refresh }.not_to raise_error
    end
  end

  describe '#send_task' do
    context 'without transformation' do
      it 'publishes a Dynamic message' do
        msg = instance_double(Legion::Transport::Messages::Dynamic, publish: nil)
        allow(Legion::Transport::Messages::Dynamic).to receive(:new).and_return(msg)
        client.send_task(function: 'my_func', function_id: 1)
        expect(Legion::Transport::Messages::Dynamic).to have_received(:new)
      end
    end

    context 'with transformation' do
      it 'publishes a SendTask message' do
        msg = instance_double(Legion::Extensions::Scheduler::Transport::Messages::SendTask, publish: nil)
        allow(Legion::Extensions::Scheduler::Transport::Messages::SendTask).to receive(:new).and_return(msg)
        client.send_task(function: 'my_func', function_id: 1, transformation: '{"key":"val"}')
        expect(Legion::Extensions::Scheduler::Transport::Messages::SendTask).to have_received(:new)
      end
    end
  end

  describe '#schedule_tasks' do
    context 'when called' do
      it 'queries for active schedules' do
        expect(mock_model::Schedule).to receive(:where).with(active: true).and_return([])
        client.schedule_tasks
      end

      context 'with an elapsed interval schedule' do
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
                   id:             1
                 })
        end

        before do
          allow(mock_model::Schedule).to receive(:where).with(active: true).and_return([row])
          # Runner hardcodes Legion::Data::Model::Function (not injected model)
          allow(Legion::Data::Model::Function).to receive(:[]).with(1).and_return(func)
          allow(row).to receive(:update)
          allow(Legion::Data::Model::ScheduleLog).to receive(:insert)
        end

        it 'calls send_task' do
          expect(client).to receive(:send_task)
          client.schedule_tasks
        end

        it 'updates last_run after dispatch' do
          allow(client).to receive(:send_task)
          expect(row).to receive(:update).with(last_run: Sequel::CURRENT_TIMESTAMP)
          client.schedule_tasks
        end
      end
    end
  end

  describe 'includes Runners::Schedule' do
    it 'includes the Schedule runner module' do
      expect(described_class.ancestors).to include(Legion::Extensions::Scheduler::Runners::Schedule)
    end
  end
end
