# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:schedules) do
      add_column :lock_version, Integer, null: false, default: 0
      add_column :definition_version, Integer, null: false, default: 1
      add_column :context, String, text: true
      add_column :interval_basis, String
      add_column :overlap_policy, String
      add_column :misfire_policy, String
    end

    create_table(:schedule_occurrences) do
      primary_key :id
      foreign_key :schedule_id, :schedules, null: false
      String :occurrence_key, null: false, unique: true
      DateTime :scheduled_at, null: false
      foreign_key :task_id, :tasks
      DateTime :recorded_at, null: false
      DateTime :delivered_at
      DateTime :completed_at
      String :status, null: false
      index %i[schedule_id scheduled_at]
    end
  end
end
