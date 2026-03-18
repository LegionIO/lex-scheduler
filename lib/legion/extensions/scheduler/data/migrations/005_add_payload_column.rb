# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:schedules) do
      add_column :payload, String, text: true, null: true, default: '{}'
    end
  end
end
