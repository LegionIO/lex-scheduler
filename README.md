# lex-scheduler

Durable cron and interval scheduling for [LegionIO](https://github.com/LegionIO/LegionIO). The scheduler records a logical occurrence, task, and outbox intent in one database transaction. [lex-tasker](https://github.com/LegionIO/lex-tasker) publishes those intents with broker confirmation and recovers rejected or interrupted publications.

## Installation and operation

```bash
gem install lex-scheduler
```

Requires Ruby 3.4+, legion-settings 1.4.3+, legion-data 1.11.0+, legion-transport 1.4.32+, and lex-tasker 0.4.0+. Run Data migrations through 144 and Legion's normal extension migrations before starting actors. Data 144 persists each task's execution-policy snapshot; migration `007_schedule_occurrences` adds scheduler tables/columns without modifying published migrations. Scheduler and task persistence must use the **same database connection**. Enable the Tasker outbox relay; a stopped relay leaves durable work pending rather than losing it. No broker or cache is required merely to record schedules. Cache-backed leader election, when available, is only an optimization: database compare-and-swap and unique occurrence keys prevent two scheduler processes from recording the same occurrence.

`Actor::RunScheduler` polls `Runners::Schedule#schedule_tasks`. It does not run through the ordinary task runner because scheduling is orchestration, not execution of the target task.

## Schedule definitions

```ruby
Legion::Extensions::Scheduler::Data::Model::Schedule.create(
  name: 'reconcile', function_id: 42, interval: 300, active: true,
  payload: Legion::JSON.dump({ account_id: 123 }),
  context: Legion::JSON.dump({ principal_id: 'scheduler-service', principal_type: 'service',
                              correlation_id: 'reconcile-123', tenant_id: 'example' })
)
```

Use exactly one of a positive integer `interval` (seconds) or a nonempty `cron` string. Cron expressions and Fugit duration/natural-language expressions are supported when they resolve to a cron or positive duration. Invalid input, missing functions, unsupported policies and malformed JSON are logged and returned in `errors`; they never create a task or advance `last_run`.

`payload` is the complete business-argument Hash. It is always placed under `args`, including for transformation. Business keys named `function_id`, `function`, `runner_class`, `principal_id` or `task_id` cannot replace dispatch controls. Store execution metadata separately in the JSON `context` column: lineage, principal/worker/tenant, correlation, depth/deadline, debug, engine/schema and engine options are preserved. The function row controls the target function and runner; the scheduler assigns task, schedule, occurrence and definition identities. Treat context and transformation configuration as privileged control-plane data, not user input.

Metadata is not authentication. Protected internal Subscription actors must explicitly opt in to `trusted_internal`; Core supplies its configured service principal and preserves claimed caller identity only as audit origin. The scheduler never grants roles from a payload or context field.

Optional fields:

- `transformation`: template sent to lex-transformer using the canonical transform route; empty values use direct dispatch. ERB runs trusted code and is not a sandbox. Transformer engine policy applies.
- `task_ttl`: broker message expiration in milliseconds; use `context.deadline_at` for an absolute execution deadline, including time spent waiting in the outbox.
- `interval_basis`, `overlap_policy`, `misfire_policy`: per-schedule overrides of the defaults below.
- `definition_version`: increment when materially changing a definition; it participates in the stable occurrence key. Changing a definition does not clear unfinished work or bypass overlap protection.

New interval schedules are eligible at their creation time. New cron schedules wait for a matching time at or after creation. `last_run` is the **logical scheduled-time cursor whose intent was committed**, not proof that a message was delivered or a task succeeded. Never clear it as a publication retry mechanism: the outbox handles retries without creating a second occurrence.

## Scheduling policies

Settings live under `extensions.scheduler`; all defaults are exposed by `Legion::Extensions::Scheduler.default_settings` and read through `Legion::Settings::Helper`.

| Setting | Default | Behavior |
|---|---|---|
| `poll_interval_seconds` | `1` | Scheduler actor tick interval |
| `interval_basis` | `scheduled` | `scheduled`: fixed cadence from the logical cursor. `completed`: wait one interval from persisted terminal task completion; only intervals/durations support this basis |
| `overlap_policy` | `forbid` | `forbid`: wait until prior occurrences finish. `allow`: permit multiple unfinished occurrences; completed-based intervals still wait for their prior completion |
| `misfire_policy` | `coalesce` | `coalesce`: record only the latest due slot. `catch_up`: oldest missed slots first, bounded per poll. `skip`: advance the latest missed slot without executing if older than the grace period |
| `misfire_grace_seconds` | `60` | Maximum lateness accepted by `skip` |
| `max_catch_up` | `100` | Maximum missed slots considered in a catch-up poll; overlap protection may limit this to one |
| `execution.max_depth` | `100` | Local bound on descendant traversal when reconciling multiplied tasks; does not redefine terminal outcomes |

Unsupported policies are errors, not fallback behavior. A completed-based interval uses terminal outcomes (including failure), not only successful completions. A transformed single output retains the occurrence's task ID; multiplied output waits for every descendant target task before the interval restarts. An `unknown` outcome is explicitly recorded but blocks completion/overlap: ambiguous external effects must be reconciled, not blindly repeated. Disabling a schedule stops new occurrences while existing task outcomes continue to be reconciled.

Settings are dynamic process-local policy, not distributed storage. `Legion::Transport::TaskProtocol` owns immutable task statuses, terminal recognition, routes, message types, protocol version, and metadata fields. Scheduler emits canonical `dynamic` and `transform` intents; Tasker owns publication using Transport's `transport.task_publication` defaults. Scheduler bookkeeping identities (`schedule.recorded`, `schedule.delivered`, `schedule.skipped`) are fixed in `Legion::Extensions::Scheduler::OCCURRENCE_STATUSES`, not configurable.

Data owns persisted task/dispatch lifecycle identities and the task's execution-policy snapshot. Stored leases, retry timestamps, idempotency expiry, completion state, and occurrence identity remain authoritative when another process has different local settings. Scheduler-local ancestry, polling, scheduling, and misfire bounds may vary without changing interpretation of durable state.

## Delivery versus completion

- `schedule_occurrences.recorded_at` means task and outbox intent were committed together.
- `delivered_at` is copied only from an acknowledged outbox dispatch. A rejected, nacked, timed-out or unroutable publish stays pending and recoverable.
- `completed_at` and the task outcome come from persisted task execution, never from publishing. Unknown results remain unresolved.
- `schedule_logs.success` is `nil` when recording work, and becomes a separate true/false outcome entry only after task resolution. A delivery confirmation is not a successful task result.

A transaction failure rolls back task, occurrence, intent and cursor together. Poll failures return `{ success: false, recorded:, skipped:, errors: [...] }` and log the real error. Other schedules remain eligible for processing.

## Standalone client

Configure Legion data, load function/runner models and scheduler models, and apply migrations before use:

```ruby
require 'legion/extensions/scheduler/client'
client = Legion::Extensions::Scheduler::Client.new
client.schedule_tasks
client.send_task(function_id: 42, idempotency_key: 'request-123', args: { account_id: 123 },
                 context: { principal_id: 'scheduler-service', principal_type: 'service' })
```

`send_task` records durable work and returns a plain task Hash with `created: true/false`; replaying the same key does not enqueue again. It does not publish synchronously. `data_model:` can inject a scheduler model namespace backed by the same database; `fugit:` injects the actual parser used for due-time evaluation. Defaults are installed without overwriting user settings.

## Operating-mode runners

Optional `ModeScheduler#evaluate_mode`, `ModeTransition#transition(mode:, force: false)` and `EmergencyPromotion#promote(event_type:)` use a connected cache and return Hash outcomes. They do not affect occurrence persistence. Mode transitions protect cached critical-task counts unless forced.

Additional settings: `modes` defaults to `active/idle/dream/maintenance`; `default_mode` and `emergency_mode` default to `active`; `emergency_patterns` defaults to `extinction/consent_violation`; `mode_cache_ttl_seconds` defaults to `3600`. `mode_schedule` uses local hours: active 08–17, idle 18–21, dream 22–05, maintenance 06–07. All are configurable through the same settings helper.

Settings arrays retain Legion's additive merge semantics. When mode hour ranges overlap, the first matching mode in the configured map wins; use nonoverlapping definitions where possible.

The former no-op refresh actor, refresh queue and custom SendTask envelope have been removed. Call `schedule_tasks` for an explicit poll rather than publishing refresh messages.

## Development

The Gemfile uses guarded companion gem paths under `.ci-dependencies/<repo>` for coordinated PR CI, or sibling worktrees when available. Ordinary installations resolve released gem dependencies. No Git URL dependencies or generated artifacts belong in the gem.

## License

MIT
