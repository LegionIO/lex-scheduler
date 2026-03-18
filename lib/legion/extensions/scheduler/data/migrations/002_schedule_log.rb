# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:schedule_logs) do
      primary_key :id
      foreign_key :schedule_id, :schedules, null: true
      foreign_key :task_id, :tasks, null: true
      foreign_key :function_id, :functions, null: true
      TrueClass :success, null: true
      String :status, null: true
      DateTime :created, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
