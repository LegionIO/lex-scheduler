# Changelog

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
