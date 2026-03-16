# Structured JSON Logging Implementation

## Summary of Changes

This document outlines the changes made to implement structured JSON logging across the QueueBus library, as per the organization's logging standardization initiative.

## Files Modified

### Core Logging Infrastructure

1. **lib/queue_bus/json_logger.rb** (NEW)
   - Implements `JsonLogger` class with structured JSON output
   - Defines standard log levels (DEBUG, INFO, WARN, ERROR, FATAL)
   - Implements `JsonLoggerAdapter` for compatibility with standard Logger API
   - Includes automatic field population (timestamp, level, service, environment, etc.)
   - Supports correlation IDs, trace IDs, and contextual metadata
   - Handles errors with structured stack traces

2. **lib/queue_bus/config.rb** (MODIFIED)
   - Added `use_json_logging` flag (default: true)
   - Updated logger initialization to create JsonLogger by default
   - Modified `log_application` and `log_worker` to accept metadata
   - Added new methods: `log_error`, `log_warn`, `log_fatal`
   - Implemented environment-aware log level configuration

3. **lib/queue-bus.rb** (MODIFIED)
   - Added autoload for `JsonLogger` and `JsonLoggerAdapter`
   - Added delegation for new logging methods
   - Added delegation for `use_json_logging` configuration

### Application Components Updated

4. **lib/queue_bus/driver.rb** (MODIFIED)
   - Updated to use structured logging with metadata
   - Extracts and includes correlation_id, event_type, app_key, queue_name
   - Improved log messages for better observability

5. **lib/queue_bus/publisher.rb** (MODIFIED)
   - Updated to use structured logging
   - Includes correlation_id and delayed_until information

6. **lib/queue_bus/publishing.rb** (MODIFIED)
   - Updated publish and publish_at methods to use structured logging
   - Includes correlation_id, event_type, and timing information

7. **lib/queue_bus/rider.rb** (MODIFIED)
   - Updated to use structured logging with contextual metadata
   - Added error handling with structured error logging
   - Includes correlation_id, event_type, app_key, subscription_key

8. **lib/queue_bus/local.rb** (MODIFIED)
   - Updated to use structured logging
   - Includes local_mode information in logs

9. **lib/queue_bus/task_manager.rb** (MODIFIED)
   - Updated log method to support structured logging
   - Checks use_json_logging flag for compatibility
   - Includes app_key and subscription_count in logs

10. **lib/queue_bus/tasks.rb** (MODIFIED)
    - Updated to use new logging methods
    - Added structured logging for rake tasks

### Documentation and Examples

11. **LOGGING.md** (NEW)
    - Comprehensive documentation of structured logging standards
    - Configuration examples
    - Log schema definition with required and optional fields
    - Usage examples for all log levels
    - Integration guide for log aggregation tools
    - Best practices and troubleshooting

12. **examples/logging_configuration.rb** (NEW)
    - Multiple configuration examples
    - Environment-specific configurations
    - Rails integration examples
    - Custom logger implementations

## Key Features Implemented

### ✓ Standard Logging Library
- Implemented native Ruby JSON logging with `JsonLogger` class
- Compatible with standard Logger API via `JsonLoggerAdapter`

### ✓ Common JSON Schema
Required fields in every log entry:
- `timestamp` - ISO 8601 format with milliseconds
- `level` - DEBUG, INFO, WARN, ERROR, FATAL
- `message` - Human-readable log message
- `service` - Service name (default: "queue-bus")
- `environment` - Runtime environment
- `hostname` - Server hostname
- `version` - QueueBus version
- `pid` - Process ID
- `thread_id` - Thread identifier

### ✓ Structured Logging
- All log statements output valid JSON
- Metadata passed as keyword arguments
- Automatic field extraction and formatting

### ✓ Consistent Log Levels
- DEBUG - Internal operations and detailed flow
- INFO - Application-level events
- WARN - Warnings and retryable errors
- ERROR - Failed operations and exceptions
- FATAL - Critical system failures

### ✓ Contextual Metadata
Optional fields included when relevant:
- `correlation_id` - Event correlation ID (bus_id)
- `request_id` - Request identifier
- `trace_id` - Distributed trace ID
- `user_id` - User identifier
- `event_type` - QueueBus event type
- `app_key` - Application key
- `queue_name` - Queue name
- `subscription_key` - Subscription identifier

### ✓ Error Handling
Structured error information includes:
- Error class name
- Error message
- Stack trace (first 10 lines)

### ✓ Environment Configuration
- Automatic log level adjustment based on environment
- Production: INFO level
- Development/Test: DEBUG level
- Configurable via `QueueBus.logger.level`

### ✓ Legacy Pattern Migration
- Replaced plain text log statements with structured calls
- Updated all logging throughout the codebase
- Maintains backward compatibility with `use_json_logging = false`

### ✓ Documentation
- Comprehensive LOGGING.md guide
- Configuration examples
- Integration instructions for log aggregation tools
- Best practices and troubleshooting

## Backward Compatibility

The implementation maintains full backward compatibility:

1. **Opt-out available**: Set `QueueBus.use_json_logging = false` to use plain text logging
2. **Existing logger support**: Custom loggers can still be set via `QueueBus.logger = your_logger`
3. **CLI output preserved**: `puts` statements in rake tasks remain for human-readable output
4. **Old API works**: Existing logging calls without metadata still function

## Migration Guide

### For Library Users

**No changes required** - JSON logging is enabled by default and works out of the box.

**Optional configuration:**
```ruby
# Customize log level
QueueBus.logger.level = QueueBus::JsonLogger::LogLevel::INFO

# Disable JSON logging if needed
QueueBus.use_json_logging = false

# Set custom logger
QueueBus.logger = your_custom_logger
```

### For Contributors

When adding new logging:
```ruby
# Include contextual metadata
QueueBus.log_application('Event processed',
  event_type: event_type,
  correlation_id: correlation_id,
  processing_time: elapsed_time
)

# Log errors with context
QueueBus.log_error('Processing failed',
  error: exception,
  event_type: event_type
)
```

## Integration with Log Aggregation

The JSON format is compatible with:
- Elasticsearch/ELK Stack
- Splunk
- Datadog
- CloudWatch Logs Insights
- Grafana Loki
- Sumo Logic

Example query (ELK):
```
level:"ERROR" AND event_type:"user_created" AND correlation_id:"abc123"
```

## Testing

To verify the implementation:
```ruby
# Enable JSON logging (default)
QueueBus.publish('test_event', user_id: 123)

# Check output - should be valid JSON with all required fields
# Output example:
# {"timestamp":"2024-01-15T10:30:45.123Z","level":"INFO","message":"Event published",...}
```

## Future Enhancements

Potential improvements for consideration:
- Async logging for high-throughput scenarios
- Log sampling for high-volume events
- Custom field formatters
- OpenTelemetry integration
- Automatic PII redaction
