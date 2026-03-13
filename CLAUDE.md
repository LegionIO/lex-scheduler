# lex-scheduler: Cron and Interval Task Scheduling for LegionIO

**Repository Level 3 Documentation**
- **Category**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Core Legion Extension that manages scheduled, delayed, and cron-style task execution. Reads schedule definitions from the database (interval seconds or cron expressions via `fugit`), determines which tasks are due, and publishes them to the message bus. Uses a distributed lock via Legion::Cache to ensure only one node runs the scheduler at a time.

**License**: MIT

## Architecture

```
Legion::Extensions::Scheduler
├── Actors/
│   ├── RunScheduler       # Every-type actor: periodically calls schedule_tasks
│   └── ScheduleTask       # Every-type actor: periodically publishes refresh messages
├── Runners/
│   └── Schedule           # Core scheduling logic
│       ├── schedule_tasks   # Queries DB for due schedules, publishes task messages
│       ├── send_task        # Publishes Dynamic or SendTask messages
│       ├── refresh          # Acquires distributed scheduler lock via cache
│       └── push_refresh     # Broadcasts refresh message to cluster
├── Data/
│   ├── Models/
│   │   ├── Schedule       # Sequel model (cron, interval, function_id, payload, transformation, active, last_run)
│   │   └── ScheduleLog    # Execution log
│   └── Migrations/
│       ├── 001_schedule_table
│       ├── 002_schedule_log
│       ├── 003_schedule_indexes
│       ├── 004_schedule_logs_indexes
│       ├── 005_add_payload_column
│       └── 006_add_transform_to_schedule
└── Transport/
    ├── Queues/Schedule    # Schedule queue
    └── Messages/
        ├── Refresh        # Cluster-wide refresh notification
        └── SendTask       # Task execution message
```

## Key Design Patterns

### Distributed Lock
Uses `Legion::Cache.set('scheduler_schedule_lock', node_name, ttl=2)` to ensure only one node in the cluster runs `schedule_tasks` at a time. The lock has a 2-second TTL, refreshed each cycle.

### Dual Schedule Types
- **Interval**: Integer seconds since last run (`row.interval > 0`)
- **Cron**: Cron expression string parsed by `Fugit.parse` (supports both duration and cron syntax)

### Transformation Support
Scheduled tasks can include an ERB transformation template. If present, the task is routed through `lex-transformer` before execution.

## Dependencies

| Gem | Purpose |
|-----|---------|
| `fugit` (>= 1.3.9) | Cron expression parsing (built on `rufus-scheduler`) |
| `legion-data` | Required - schedule persistence |
| `legion-cache` | Required - distributed scheduler lock |

## Database Schema

**schedules table**: `id`, `function_id`, `interval`, `cron`, `active`, `last_run`, `task_ttl`, `payload` (JSON), `transformation` (ERB template)

**schedule_logs table**: Execution history linked to schedules

## Testing

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

---

**Maintained By**: Matthew Iverson (@Esity)
