Sequel.migration do
  change do
    add_index :schedules, :last_run, name: 'schedules_last_run_index'
    add_index :schedules, :interval, name: 'schedules_interval_index'
    add_index :schedules, :function_id, name: 'schedules_function_id_index'
    add_index :schedules, :active, name: 'schedules_active_index'
  end
end
