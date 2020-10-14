Sequel.migration do
  change do
    add_index :schedule_logs, :schedule_id
    add_index :schedule_logs, :task_id
    add_index :schedule_logs, :status
  end
end
