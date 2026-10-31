# frozen_string_literal: true

ENV['LEGION_MODE'] = 'lite'

require 'bundler/setup'
require 'fileutils'
require 'tmpdir'
require 'legion/logging'
require 'legion/settings'
Legion::Settings.loader = Legion::Settings::Loader.new
require 'legion/json'
require 'legion/data'
require 'sequel/extensions/migration'

Legion::Logging.setup(level: 'fatal', async: false)
Sequel.default_timezone = :utc

SCHEDULER_SPEC_DIRECTORY = Dir.mktmpdir('lex-scheduler-spec')
SCHEDULER_SPEC_DB = Sequel.sqlite(File.join(SCHEDULER_SPEC_DIRECTORY, 'scheduler.sqlite3'), max_connections: 4, timeout: 5000)
Legion::Data::Connection.sequel = SCHEDULER_SPEC_DB
Sequel::Model.db = SCHEDULER_SPEC_DB

# Apply the real migrations for the task substrate and scheduler, excluding unrelated PostgreSQL-only integrations.
%w[identity_principals identities].each do |table|
  SCHEDULER_SPEC_DB.create_table(table.to_sym) { primary_key :id }
end
data_migrations = File.join(Gem.loaded_specs.fetch('legion-data').full_gem_path, 'lib/legion/data/migrations')
%w[004_add_extensions 005_add_runners 006_add_functions 008_add_tasks 009_add_digital_workers 031_add_task_depth
   032_add_task_cancelled_at 033_add_task_delay 075_add_task_idempotency
   139_add_task_execution 140_create_task_attempts 141_create_task_dispatches].each do |migration|
  load File.join(data_migrations, "#{migration}.rb")
  Sequel::Migration.descendants.pop.apply(SCHEDULER_SPEC_DB, :up)
end
scheduler_migrations = File.expand_path('../lib/legion/extensions/scheduler/data/migrations', __dir__)
Sequel::Migrator.run(SCHEDULER_SPEC_DB, scheduler_migrations)

require 'legion/data/models/function'
require 'legion/data/models/runner'
require 'legion/data/models/extension'
require 'legion/data/models/task'
require 'legion/transport'
require 'legion/extensions/tasker/runners/outbox'
require 'legion/extensions/scheduler'
require 'legion/extensions/scheduler/data/models/schedule'
require 'legion/extensions/scheduler/data/models/schedule_log'
require 'legion/extensions/scheduler/client'

Legion::Transport::Spool.setup(directory: File.join(SCHEDULER_SPEC_DIRECTORY, 'spool'))
Legion::Transport::Connection.setup

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.before do
    Legion::Transport::Local.reset!
    %i[schedule_logs schedule_occurrences task_dispatches task_attempts schedules tasks functions runners extensions].each do |table|
      SCHEDULER_SPEC_DB[table].delete
    end
    Legion::Settings.loader.load_module_default(extensions: { scheduler: Legion::Extensions::Scheduler.default_settings })
  end
  config.after(:suite) do
    Legion::Transport::Connection.shutdown
    Legion::Cache.shutdown if defined?(Legion::Cache) && Legion::Cache.connected?
    SCHEDULER_SPEC_DB.disconnect
    FileUtils.remove_entry(SCHEDULER_SPEC_DIRECTORY)
  end
end
