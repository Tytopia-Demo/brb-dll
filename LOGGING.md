# QueueBus Structured JSON Logging Standards

## Overview

QueueBus now implements structured JSON logging to provide consistent, machine-readable logs across all operations. This enables better log parsing, searching, analysis, and integration with log aggregation tools.

## Features

- **Structured JSON Output**: All logs are emitted as valid JSON objects
- **Standard Log Levels**: DEBUG, INFO, WARN, ERROR, FATAL
- **Required Fields**: timestamp, level, message, service, environment, hostname
- **Contextual Metadata**: Automatic inclusion of correlation IDs, event types, app keys
- **Error Details**: Stack traces and error information in structured format
- **Environment-Aware**: Automatically adjusts log levels based on environment

## Configuration

### Enabling JSON Logging (Default)

```ruby
require 'queue-bus'

# JSON logging is enabled by default
# No additional configuration needed
```

### Disabling JSON Logging

If you need to use plain text logging for compatibility:

```ruby
QueueBus.use_json_logging = false
QueueBus.logger = Logger.new($stdout)
```

### Setting Custom Logger

```ruby
# Use custom logger instance
QueueBus.logger = QueueBus::JsonLoggerAdapter.new($stdout)

# Or use a custom output destination
QueueBus.logger = QueueBus::JsonLoggerAdapter.new(File.open('log/queue_bus.log', 'a'))
```

### Environment-Specific Configuration

JSON logger automatically adjusts log levels based on environment:

- **Production**: INFO level and above
- **Development/Test**: DEBUG level and above

Override the log level:

```ruby
QueueBus.logger.level = QueueBus::JsonLogger::LogLevel::DEBUG
```

## Log Schema

### Required Fields

Every log entry includes these standard fields:

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string | ISO 8601 timestamp with milliseconds (UTC) |
| `level` | string | Log level: DEBUG, INFO, WARN, ERROR, FATAL |
| `message` | string | Human-readable log message |
| `service` | string | Service name (default: "queue-bus") |
| `environment` | string | Environment (production, development, etc.) |
| `hostname` | string | Server hostname |
| `version` | string | QueueBus version |
| `pid` | integer | Process ID |
| `thread_id` | integer | Thread object ID |

### Optional Contextual Fields

Additional fields are included when relevant:

| Field | Type | Description |
|-------|------|-------------|
| `correlation_id` | string | Event correlation ID (bus_id) |
| `request_id` | string | Request identifier |
| `trace_id` | string | Distributed trace identifier |
| `user_id` | string | User identifier |
| `event_type` | string | QueueBus event type |
| `app_key` | string | Application key |
| `queue_name` | string | Queue name |
| `subscription_key` | string | Subscription identifier |

### Error Fields

When logging errors, additional structured information is included:

```json
{
  "error": {
    "class": "StandardError",
    "message": "Error message",
    "backtrace": ["line1", "line2", "..."]
  }
}
```

### Context Object

Any additional metadata is stored in a `context` object:

```json
{
  "context": {
    "custom_field": "value",
    "another_field": 123
  }
}
```

## Usage Examples

### Basic Logging

```ruby
# Info level (application events)
QueueBus.log_application('Event published', event_type: 'user_created')

# Debug level (worker/internal operations)
QueueBus.log_worker('Processing subscription', subscription_key: 'my_sub')

# Warning level
QueueBus.log_warn('Retry attempt', attempt_number: 3)

# Error level with exception
begin
  # code
rescue StandardError => e
  QueueBus.log_error('Failed to process event', error: e, event_type: 'user_created')
end

# Fatal level
QueueBus.log_fatal('Critical system error', error: e)
```

### Direct Logger Access

```ruby
# Access the logger directly for more control
logger = QueueBus.logger

logger.debug('Debug message', custom: 'metadata')
logger.info('Info message', event_type: 'test')
logger.warn('Warning message')
logger.error('Error message', error: exception)
logger.fatal('Fatal message')
```

### Including Correlation IDs

```ruby
QueueBus.log_application(
  'Processing event',
  event_type: 'user_created',
  correlation_id: event_attributes['bus_id'],
  user_id: user.id
)
```

## Log Levels

### DEBUG
- Internal operations and detailed execution flow
- Worker processing details
- Subscription matching

### INFO
- Application-level events
- Event publishing
- Subscription registration
- Task completion

### WARN
- Retryable errors
- Deprecated feature usage
- Performance warnings
- Missing subscriptions

### ERROR
- Failed operations
- Exception handling
- Invalid configurations
- Processing failures

### FATAL
- Critical system failures
- Unrecoverable errors
- Service shutdown events

## Example Log Output

### Event Publication

```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "level": "INFO",
  "message": "Event published",
  "service": "queue-bus",
  "environment": "production",
  "hostname": "app-server-01",
  "version": "0.14.0",
  "pid": 12345,
  "thread_id": 47361234567890,
  "event_type": "user_created",
  "correlation_id": "1705318245-a1b2c3d4-e5f6-7890",
  "local_mode": false
}
```

### Error with Stack Trace

```json
{
  "timestamp": "2024-01-15T10:30:45.456Z",
  "level": "ERROR",
  "message": "Error executing subscription",
  "service": "queue-bus",
  "environment": "production",
  "hostname": "app-server-01",
  "version": "0.14.0",
  "pid": 12345,
  "thread_id": 47361234567890,
  "event_type": "user_created",
  "correlation_id": "1705318245-a1b2c3d4-e5f6-7890",
  "app_key": "my_application",
  "subscription_key": "user_notification",
  "error": {
    "class": "StandardError",
    "message": "Failed to send notification",
    "backtrace": [
      "app/workers/notification.rb:42:in `perform'",
      "lib/queue_bus/rider.rb:37:in `perform'"
    ]
  }
}
```

## Integration with Log Aggregation Tools

The structured JSON format is compatible with:

- **Elasticsearch/ELK Stack**: Direct ingestion via Logstash or Filebeat
- **Splunk**: Automatic field extraction
- **Datadog**: Native JSON log support
- **CloudWatch Logs Insights**: JSON query support
- **Grafana Loki**: Label extraction from JSON
- **Sumo Logic**: JSON parser support

## Querying Logs

### Find all errors for a specific event type
```
level:"ERROR" AND event_type:"user_created"
```

### Track an event through the system by correlation ID
```
correlation_id:"1705318245-a1b2c3d4-e5f6-7890"
```

### Find slow processing (custom metrics)
```
context.processing_time_ms:>5000
```

## Best Practices

1. **Always include correlation IDs**: Helps track events across the system
2. **Use appropriate log levels**: Don't log everything at ERROR
3. **Include relevant context**: Add metadata that helps debugging
4. **Avoid sensitive data**: Don't log passwords, tokens, or PII
5. **Keep messages concise**: The message should summarize the event
6. **Use structured fields**: Put data in metadata, not in the message string

## Migration from Plain Text Logging

If you have existing code using the old logging style:

**Before:**
```ruby
QueueBus.logger.info("Event published: #{event_type}")
```

**After:**
```ruby
QueueBus.log_application('Event published', event_type: event_type)
```

The new methods accept keyword arguments for metadata, which become structured fields in the JSON output.

## Backward Compatibility

- Old Logger API still works if you disable JSON logging
- Existing code will continue to function
- Gradual migration is supported
- `puts` statements in tasks are preserved for CLI output

## Troubleshooting

### Logs not appearing

Check that your logger is configured:
```ruby
QueueBus.logger # Should not be nil
```

### JSON parsing errors

Verify your log aggregator supports multi-line JSON or configure single-line output.

### Missing fields

Ensure you're passing metadata as keyword arguments:
```ruby
# Correct
QueueBus.log_application('Message', field: 'value')

# Incorrect (field won't be captured)
QueueBus.log_application("Message with field value")
```

## Future Enhancements

- Async logging for high-throughput scenarios
- Log sampling for high-volume events
- Custom field formatters
- Integration with OpenTelemetry
- Automatic PII redaction
