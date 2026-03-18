# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:schedules) do
      primary_key :id
      foreign_key :function_id, :functions, null: true
      String :name, null: false
      Integer :interval, null: true
      String :cron, null: true, text: true
      TrueClass :active, default: true
      DateTime :last_run, null: true
      DateTime :created, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated, null: true
    end
  end
end
