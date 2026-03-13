# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:schedules) do
      add_column :payload, File, null: false, default: '{}'
    end
  end
end
