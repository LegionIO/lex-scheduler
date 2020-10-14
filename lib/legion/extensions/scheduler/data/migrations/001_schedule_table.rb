Sequel.migration do
  up do
    run '
      create table schedules (
        id int auto_increment,
        function_id int null,
        active tinyint default 1 not null,
        `interval` int null,
        cron varchar(255) null,
        name varchar(255) null,
        description blob null,
        task_ttl int null,
        last_run datetime null,
        created datetime default CURRENT_TIMESTAMP not null,
        updated datetime null,
        constraint schedules_pk
          primary key (id)
      );'
  end

  down do
    drop_table :schedules
  end
end
