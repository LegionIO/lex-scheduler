# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:schedules) do
      add_column :context, String, text: true
      add_column :misfire_policy, String
    end
  end
end
