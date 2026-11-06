# lex-scheduler

Cron, interval and one-shot scheduling for [LegionIO](https://github.com/LegionIO/LegionIO). The scheduler creates an ordinary Sequel task model and publishes its task message directly. Schedule bookkeeping is separate; there are no execution outboxes, occurrence claims, leases or row-lock transactions.

## Installation and operation

```ruby
gem 'lex-scheduler'
```

Requires Ruby 3.4+, legion-settings 1.4.5+, legion-data 1.11.0+ and legion-transport 1.4.32+. Apply Legion's normal Data and extension migrations before starting actors. Scheduler migration `007_schedule_context` adds only context and misfire-policy columns; published migrations 001–006 are unchanged. lex-tasker is not a runtime dependency.

`Actor::RunScheduler` polls `Runners::Schedule#schedule_tasks` under the existing singleton actor. Task consumers use prefetch 1. Scheduling does not run through the ordinary task runner: the target is executed by its own consumer. Do not run competing scheduling polls; the scheduler does not provide distributed claims or concurrent-poll deduplication.

## Schedule definitions

Create a `Legion::Extensions::Scheduler::Data::Model::Schedule` with a name, target `function_id`, and one of:

- Positive integer `interval` in seconds.
- A `cron` expression understood by Fugit, including a duration such as `2m` or an absolute one-shot timestamp.

```ruby
Legion::Extensions::Scheduler::Data::Model::Schedule.create(
  name: 'refresh accounts', function_id: 42, interval: 60,
  payload: Legion::JSON.dump({ account_id: 123 }),
  context: Legion::JSON.dump({ principal_id: 'scheduler-service', principal_type: 'service' })
)
```

`payload` is a JSON object passed as business `args`. It cannot replace the target function, runner or task ID. `context` is a separate JSON object for canonical task metadata: lineage, principal/worker/tenant, correlation, depth/deadline, debug and transformation engine options. The target function row determines dispatch routing. The scheduler assigns the new task ID. Context is privileged control-plane data, not authentication or user-supplied business input.

Optional fields:

- `active`: disable to stop new submissions.
- `transformation`: a nonempty template routes the message through the canonical transform queue.
- `task_ttl`: transport message expiration.
- `misfire_policy`: per-schedule override of the setting below.

New intervals are eligible at creation time. Cron schedules wait for a matching time at or after creation. Absolute timestamps dispatch once, when due. Duration intervals retain their scheduled cadence rather than waiting for previous task completion. A previous task still running does not prevent the next due submission.

## Polling and missed schedules

Settings live under `extensions.scheduler`. `def self.default_settings` is defined in root `scheduler.rb`, which registers defaults once at extension boot. Constructing a client does not change settings.

| Setting | Default | Meaning |
|---|---|---|
| `poll_interval_seconds` | `1` | Scheduler actor polling interval |
| `misfire_policy` | `coalesce` | `coalesce`: latest due slot; `catch_up`: oldest missed slots first; `skip`: advance an overdue slot without dispatching |
| `misfire_grace_seconds` | `60` | Maximum lateness accepted by `skip` |
| `max_catch_up` | `100` | Maximum slots dispatched for one schedule in a catch-up poll |

Invalid definitions and unsupported policies are errors, not fallback schedules. A poll returns `{ success:, recorded:, skipped:, errors: }`: `recorded` counts accepted dispatches whose bookkeeping completed, not task execution success. One failing schedule is logged and reported while the poll continues with other schedules.

`last_run` is the logical scheduled-time cursor. After `publish!` accepts a message, the scheduler creates a `ScheduleLog` through its model and updates the schedule through its model. The log has `status: 'dispatched'` and `success: nil`; it does not claim the task completed. An explicit misfire skip advances the cursor without creating a task or dispatch log.

## Publication and failure boundaries

Direct submissions use `Legion::Data::Model::Task.create`, followed by `Legion::Transport::Messages::Dynamic#publish!` or `SubTask#publish!`. Canonical metadata and routes come from `Legion::Transport::Task::Protocol`. There are no attempt IDs or ownership tokens, and scheduler bookkeeping does not coordinate persistence messages into a multi-model transaction.

Rejected publication raises from `send_task`; a scheduling poll logs it and returns an error without advancing the cursor or writing a dispatch log. The task row was already created and may remain without delivery. Publication and database bookkeeping are intentionally not atomic: a crash or database failure after acceptance can leave an accepted message without an advanced cursor, and a subsequent poll can submit another task. Transport rejection may also be ambiguous about delivery. There is no exactly-once, automatic idempotence or execution recovery guarantee. No completion reconciliation, overlap policy or completion-based interval is maintained.

## Standalone client

Configure Legion data and transport, apply migrations, and load function/runner and scheduler models before use:

```ruby
require 'legion/extensions/scheduler/client'
client = Legion::Extensions::Scheduler::Client.new
client.schedule_tasks
client.send_task(function_id: 42, args: { account_id: 123 },
                 context: { principal_id: 'scheduler-service', principal_type: 'service' })
```

`send_task` publishes synchronously and returns `{ success: true, task: task.values }`. Each call creates a separate task; the former execution-outbox `idempotency_key:` contract is removed. `data_model:` can inject a scheduler model namespace; `fugit:` injects the parser used for due-time evaluation. Both existing client APIs are retained; defaults are registered by root-module boot, not client initialization.

## Operating-mode runners

Optional `ModeScheduler#evaluate_mode`, `ModeTransition#transition(mode:, force: false)` and `EmergencyPromotion#promote(event_type:)` use a connected cache and return Hash outcomes. Mode transitions protect cached critical-task counts unless forced.

Additional settings: `modes` defaults to `active/idle/dream/maintenance`; `default_mode` and `emergency_mode` default to `active`; `emergency_patterns` defaults to `extinction/consent_violation`; `mode_cache_ttl_seconds` defaults to `3600`. `mode_schedule` uses local hours: active 08–17, idle 18–21, dream 22–05, maintenance 06–07. All are configurable through the same settings helper.

Settings arrays retain Legion's additive merge semantics. When mode hour ranges overlap, the first matching mode in the configured map wins; use nonoverlapping definitions where possible.

The former no-op refresh actor, refresh queue and custom SendTask envelope have been removed. Call `schedule_tasks` for an explicit poll rather than publishing refresh messages.

## Development

The Gemfile uses `.ci-dependencies/<repo>` for coordinated PR CI, otherwise the existing legion-settings, legion-data and legion-transport checkouts at the monorepo root. CI pins the coordinated Settings/Data revisions and uses released Transport. Ordinary installations resolve released gems. No Git URL dependencies or generated artifacts belong in the gem.

Specs use a disposable SQLite database with real task and scheduler migrations, plus the in-process transport with a bound target queue and encryption disabled. Broker smoke checks need a bound target queue (and the transform queue when testing templates); accepted publication alone does not execute a target. Run the full RSpec and RuboCop gates before release.

## License

MIT
