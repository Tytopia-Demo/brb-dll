# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Unified Logging Framework**: Implemented structured JSON logging with telemetry context tracking for distributed tracing and improved observability
  - Added `QueueBus::StructuredLogger` for JSON log output with metadata enrichment
  - Added `QueueBus::PlainTextLogger` for backwards-compatible plain text logging
  - Added `QueueBus::Telemetry` module for request ID, user ID, session ID, and trace ID tracking
  - Telemetry context is automatically injected into published events and restored in workers
  - All log entries now include configurable metadata: service name, environment, version, hostname
  - Log methods (`log_application`, `log_worker`) now accept optional metadata hashes
  - Added configuration options: `structured_logging`, `service_name`, `environment`, `log_version`
  - Added telemetry context methods: `set_telemetry_context`, `update_telemetry_context`, `clear_telemetry_context`, `with_telemetry_context`
  - Added `generate_request_id` method for generating unique request identifiers
  - Added `reset_logger!` method to reinitialize logger with new configuration
  - See [LOGGING.md](LOGGING.md) for complete documentation

### Changed

- Enhanced log output across all components to include structured metadata when enabled
- Updated `publish_metadata` to inject telemetry context into event attributes
- Updated `QueueBus::Worker` to restore telemetry context when processing events
- Updated `QueueBus::Driver`, `QueueBus::Rider`, `QueueBus::Publisher`, and `QueueBus::Local` to use structured logging

### Notes

- All changes are **backwards compatible** - structured logging is disabled by default
- Existing applications continue to work without any code changes
- New features are opt-in through configuration

## [0.13.2]

### Fixes

- Properly passes the attributes down to the subscription when using `on_heartbeat`

## [0.13.1]

### Fixes

- Allows matching on 0 via the `on_heartbeat` subscription

### Added

- Allows matching on `wday` via the `on_heartbeat` subscription

## [0.13.0]

### Added

- Adds `Dispatch#on_heartbeat` which is a helper function for specifying heartbeat subscriptions.

## [0.12.0]

### Changed
- Pipelines fetching all queue subscriptions when using `QueueBus::Application.all`

## [0.11.0]

### Added

- Adds `QueueBus.in_context` method. Useful when working with a multithreaded environment to add a description for all events published within this scope.

## [0.10.0]

### Added
- Ability to unsubscribe from specific queues in an application (`Application#unsubscribe_queue`).
- `rake queuebus:unsubscribe` can now take two parameters to unsubscribe from specific queues, e.g. `rake queuebus:unsubscribe[my_app_key, my_queue_name]`.

## [0.9.1]

### Added
- Documented some of the major classes and modules

### Fixed
- Ran the rubocop autocorrect on the entire codebase.
- Fixed issue that prevented heartbeat events from firing under certain conditions

## [0.9.0]

### Added
- Adds rake tasks to list scheduled jobs as csv

## [0.8.1]

### Fixed
- `with_local_mode` breaks subsequent calls to `local_mode` on versions less than 2.6.

## [0.8.0]

### Added
- Adds `QueueBus.with_local_mode` method. Useful when working with a multithreaded environment.

## [0.7.0]

### Added
- Adds `QueueBus.has_adapter?` to check whether the adapter is set.

### Changed
- Now uses `Process.hostname` to determine hostname versus relying on unix shell.
- Rubocop is now a dev dependency.
- Accessors to config are now done with actual attrs.
- Logging with the adapter will use the logger if present.

### Fixed
- Passing a class to `adapter=` would error on a `NameError`.

## [0.6.0]

### Added
- New middleware implementation that allows middleware to wrap the execution of work from the `QueueBus::Worker`
- Changelog!

### Changed
- Specs are now using the `expect` syntax instead of `should`. This more closely aligns with the rspec recommendations.
