# lex-scheduler

Cron and interval task scheduling for [LegionIO](https://github.com/LegionIO/LegionIO). Reads schedule definitions from the database, determines which tasks are due, and publishes them to the message bus. Uses a distributed lock via `legion-cache` to ensure only one node runs the scheduler at a time.

This is a core LEX required for scheduled task execution.

## Installation

```bash
gem install lex-scheduler
```

## Usage

Schedules are stored in the database with either a cron expression or an interval:

- **Interval**: Run every N seconds since the last completion (integer)
- **Cron**: Run at specific times using standard cron syntax (`*/5 * * * *`) or human-readable expressions (`every day at noon`) parsed by `fugit`

Schedules can also carry a `transformation` ERB template. If present, the scheduled task is routed through `lex-transformer` before execution.

### Adding Schedules

Insert records into the `schedules` table via `legion-data`:

```ruby
Legion::Extensions::Scheduler::Data::Models::Schedule.insert(
  function_id: 42,
  interval:    300,          # run every 5 minutes
  active:      1,
  last_run:    Time.now,
  payload:     '{}'
)
```

## Requirements

- Ruby >= 3.4
- [LegionIO](https://github.com/LegionIO/LegionIO) framework
- `legion-data` (schedule persistence)
- `legion-cache` (distributed scheduler lock)
- `fugit` >= 1.9 (cron expression parsing)

## License

MIT
