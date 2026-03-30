# Changelog

## [0.3.4] - 2026-03-30

### Changed
- update to rubocop-legion 0.1.7, resolve all offenses

## [0.3.3] - 2026-03-22

### Changed
- Add legion-cache, legion-crypt, legion-data, legion-json, legion-logging, legion-settings, legion-transport as runtime dependencies
- Replace direct `Legion::JSON.load` call in `Runners::Schedule#schedule_tasks` with `json_load` helper
- Update spec_helper with real sub-gem helper requires and `Helpers::Lex` stub
- Update spec stubs to use specific constant guards (`defined?(Legion::Data::Model::*)`) instead of broad `defined?(Legion::Data)` guards

## [0.3.2] - 2026-03-22

### Fixed
- `schedule_tasks` query uses `active: true` instead of `active: 1` for PostgreSQL boolean compatibility

### Changed
- `RunScheduler` actor now uses `Singleton` mixin for leader election instead of soft cache lock
- `refresh` runner is now a no-op (leadership enforcement moved to actor level)
- `schedule_tasks` no longer checks `scheduler_schedule_lock` cache key (leadership enforced by Singleton mixin)

## [0.3.0] - 2026-03-18

### Fixed
- Migrations 001/002 rewritten as Sequel DSL (cross-DB: SQLite, PostgreSQL, MySQL)
- Migration 005 column type `File` -> `String, text: true`
- ScheduleLog model class name (was defining duplicate `Schedule`)
- Queue TTL from 5ms to 5000ms (messages were expiring instantly)
- Nil guard on `last_run` (was TypeError on new schedules)
- Nil guard on function lookup (was NoMethodError on missing function)
- Removed dead cron guard (`Time.now < previous_time` was always false)
- ScheduleLog records now created after each dispatch
- Entry point `data_required?` is now class method only (framework requirement)

### Added
- Standalone `Scheduler::Client` for programmatic schedule management
- Comprehensive spec coverage (92%+)

### Removed
- ModeScheduler, ModeTransition, EmergencyPromotion runners (dead code, no actor wiring)
- Dead `message_example` in Refresh message (copy-paste from lex-node)

## [0.2.0] - 2026-03-17

### Added
- `Runners::ModeScheduler`: time-based operating mode evaluation (active/idle/dream/maintenance)
- `Runners::ModeTransition`: orchestrated mode transitions with critical task blocking and force override
- `Runners::EmergencyPromotion`: immediate active mode promotion on critical events (extinction, consent violation)
- Configurable schedules, emergency patterns, and transition settings

### Fixed
- Emergency promotion logging uses safe method dispatch for private `Legion::Logging.warn`

## [0.1.4] - 2026-03-13

### Added
- Initial release
