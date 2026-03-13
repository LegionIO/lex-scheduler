# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:schedules) do
      add_column :transformation, String, text: true
    end
  end
end
