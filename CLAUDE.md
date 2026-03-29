# lex-scheduler: Cron and Interval Task Scheduling for LegionIO

**Repository Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-core/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Core Legion Extension that manages scheduled, delayed, and cron-style task execution. Reads schedule definitions from the database (interval seconds or cron expressions via `fugit`), determines which tasks are due, and publishes them to the message bus. Uses the `Singleton` actor mixin to ensure only one node in the cluster runs the scheduler at a time. Requires `legion-data` (`data_required? true`).

**GitHub**: https://github.com/LegionIO/lex-scheduler
**License**: MIT
**Version**: 0.3.3

## Architecture

```
Legion::Extensions::Scheduler
├── Actors/
│   ├── RunScheduler       # Every-type actor with Singleton mixin: calls schedule_tasks
│   └── ScheduleTask       # Every-type actor: publishes refresh messages
├── Runners/
│   └── Schedule           # Core scheduling logic
│       ├── schedule_tasks   # Queries DB for due schedules, publishes task messages
│       ├── send_task        # Routes to Dynamic or SendTask (transformation path)
│       ├── refresh          # No-op (leadership enforced by RunScheduler Singleton mixin)
│       └── push_refresh     # Broadcasts refresh message to cluster
├── Data/
│   ├── Models/
│   │   ├── Schedule       # Sequel model: function_id, interval, cron, active, last_run,
│   │   │                  #   task_ttl, payload (JSON), transformation (ERB)
│   │   └── ScheduleLog    # Execution history
│   └── Migrations/
│       ├── 001_schedule_table
│       ├── 002_schedule_log
│       ├── 003_schedule_indexes
│       ├── 004_schedule_logs_indexes
│       ├── 005_add_payload_column
│       └── 006_add_transform_to_schedule
├── Client                 # Standalone client including Schedule runner; accepts injected data_model and fugit
└── Transport/
    ├── Queues/Schedule    # Schedule queue
    └── Messages/
        ├── Refresh        # Cluster-wide refresh notification
        └── SendTask       # Task execution message (transformation path)
```

## Key Design Patterns

### Distributed Leadership (Singleton Mixin)

`RunScheduler` actor includes `Legion::Extensions::Actors::Singleton` (when available). The Singleton mixin ensures only one node in the cluster holds the actor active at a time. Previous cache-lock approach (`Legion::Cache.set('scheduler_schedule_lock', ...)`) was replaced in v0.3.2 — `refresh` is now a no-op and `schedule_tasks` no longer checks the cache lock key.

### Dual Schedule Types

- **Interval**: Integer seconds since last run (`row.interval > 0`)
- **Cron**: Cron expression string parsed by `Fugit.parse`. Supports both duration strings (`Fugit::Duration`, responds to `to_sec`) and standard cron expressions (`Fugit::Cron`, responds to `previous_time`)

### Active Filter

`schedule_tasks` queries with `active: true` (boolean). Previous versions used `active: 1` (integer) which broke on PostgreSQL — fixed in v0.3.2.

### Transformation Support

Scheduled tasks can include an ERB `transformation` column. If present, `send_task` routes through `task.subtask.transform` (via `lex-transformer`) instead of `Legion::Transport::Messages::Dynamic`.

## Dependencies

| Gem | Purpose |
|-----|---------|
| `fugit` (>= 1.9) | Cron expression parsing (supports duration and cron syntax) |
| `legion-data` | Required — schedule persistence |
| `legion-cache` | Used by `Singleton` mixin when available; not directly required by runner |

## Database Schema

**schedules**: `id`, `function_id`, `interval`, `cron`, `active`, `last_run`, `task_ttl`, `payload` (JSON), `transformation` (ERB template)

**schedule_logs**: Execution history linked to schedules

## Testing

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

Spec files include `fugit_spec.rb` for cron expression parsing.

---

**Maintained By**: Matthew Iverson (@Esity)
