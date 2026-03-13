# lex-scheduler

Cron and interval task scheduling for [LegionIO](https://github.com/LegionIO/LegionIO). Reads schedule definitions from the database, determines which tasks are due, and publishes them to the message bus. Uses a distributed lock via `legion-cache` to ensure only one node runs the scheduler at a time.

This is a core LEX required for scheduled task execution.

## Installation

```bash
gem install lex-scheduler
```

## Usage

Schedules are stored in the database with either a cron expression or interval:

- **Interval**: Run every N seconds after the last completion
- **Cron**: Run at specific times (`*/5 * * * *` or verbose like `every day at noon`)

Cron parsing is handled by `fugit`, which supports both standard cron syntax and human-readable expressions.

## Requirements

- Ruby >= 3.4
- [LegionIO](https://github.com/LegionIO/LegionIO) framework
- `legion-data` (schedule persistence)
- `legion-cache` (distributed scheduler lock)
- `fugit` (cron expression parsing)

## License

MIT
