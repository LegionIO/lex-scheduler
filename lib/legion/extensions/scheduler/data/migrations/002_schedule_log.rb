Sequel.migration do
  up do
    run '
      create table schedule_logs (
        id int auto_increment,
        schedule_id int not null,
        status varchar(255) null,
        time_queued datetime default CURRENT_TIMESTAMP not null,
        task_id int null,
        created datetime default CURRENT_TIMESTAMP not null,
        updated datetime null,
        constraint schedule_logs_pk primary key (id)
      );'
  end

  down do
    drop_table :schedule_logs
  end
end
