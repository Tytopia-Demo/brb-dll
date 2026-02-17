# Unified Logging Framework

This document describes the unified logging framework implemented in queue-bus, which provides structured JSON logging with telemetry context tracking.

## Overview

The unified logging framework provides:

- **Structured JSON logging** for consistent log formats across all environments
- **Telemetry context tracking** (request ID, trace ID, user ID, session ID)
- **Request correlation** between frontend and backend using shared identifiers
- **Metadata enrichment** with timestamp, service name, environment, and version
- **Context preservation** across async operations, queues, and event handlers
- **Configurable formatters** for different environments

## Quick Start

### Enable Structured Logging

```ruby
require 'queue-bus'
require 'logger'

# Set up a logger
QueueBus.logger = Logger.new(STDOUT)

# Enable structured JSON logging
QueueBus.enable_structured_logging!(
  service_name: 'my-service',
  environment: 'production',
  version: '1.0.0'
)
```

### Disable Structured Logging (Revert to Plain Text)

```ruby
QueueBus.disable_structured_logging!
```

## Telemetry Context

### Setting Telemetry Context

The framework automatically tracks and propagates telemetry context throughout the application lifecycle:

```ruby
# Set request ID (auto-generated if not provided)
QueueBus.set_request_id
# or with custom ID
QueueBus.set_request_id('custom-request-id')

# Set trace ID
QueueBus.set_trace_id('trace-abc-123')

# Set user ID
QueueBus.set_user_id(42)

# Set session ID
QueueBus.set_session_id('session-xyz')
```

### Getting Current Context

```ruby
request_id = QueueBus.request_id
trace_id = QueueBus.trace_id
user_id = QueueBus.user_id
session_id = QueueBus.session_id
```

### Executing Code with Specific Context

```ruby
QueueBus.with_telemetry_context(
  request_id: 'req-123',
  user_id: 42,
  session_id: 'session-abc'
) do
  # All logs and events within this block will have the specified context
  QueueBus.publish('user_action', action: 'login')
end
```

## Log Output Format

### Structured JSON Format

When structured logging is enabled, all logs are output in JSON format:

```json
{
  "timestamp": "2023-11-15T10:30:45.123Z",
  "severity": "INFO",
  "message": "Event published: user_created",
  "service": "my-service",
  "environment": "production",
  "version": "1.0.0",
  "request_id": "1234567890-abc-def",
  "trace_id": "trace-123",
  "user_id": 42,
  "session_id": "session-xyz",
  "event_type": "user_created",
  "bus_id": "1699960245-uuid-here"
}
```

### Plain Text Format

When structured logging is disabled (default for backward compatibility), logs use the traditional format:

```
I, [2023-11-15T10:30:45.123456 #12345]  INFO -- : Event published: user_created
```

## Context Propagation

Telemetry context is automatically propagated through:

1. **Event Publishing** - Context is injected into event attributes
2. **Queue Workers** - Context is extracted and restored when processing events
3. **Async Operations** - TelemetryMiddleware preserves context across async boundaries

### Event Attributes

When telemetry context is set, it's automatically added to published events:

- `bus_request_id` - The request ID
- `bus_trace_id` - The trace ID
- `bus_user_id` - The user ID
- `bus_session_id` - The session ID

## Configuration Options

### Service Name

Identifies the service in logs:

```ruby
QueueBus.service_name = 'my-queue-service'
```

### Environment

Specifies the environment (development, staging, production):

```ruby
QueueBus.log_environment = 'production'
```

### Version

Tracks the application version in logs:

```ruby
QueueBus.log_version = '2.1.0'
```

## Log Levels

The framework supports standard log levels:

- **DEBUG** - Detailed information for diagnosing problems
- **INFO** - Informational messages about normal operation
- **WARN** - Warning messages about potential issues
- **ERROR** - Error messages about failures
- **FATAL** - Critical errors that may cause the application to stop

## Middleware

### TelemetryMiddleware

Automatically registered in the worker middleware stack, this middleware:

1. Extracts telemetry context from event attributes
2. Sets the context for the duration of worker execution
3. Ensures context is properly cleaned up after execution

To manually register additional middleware:

```ruby
QueueBus.worker_middleware_stack.use(MyCustomMiddleware)
```

## Best Practices

1. **Set Request ID Early** - Set the request ID at the entry point of your application (e.g., in a Rails middleware)
2. **Use Structured Logging in Production** - Enable structured JSON logging in production for better log analysis
3. **Include User Context** - Always set user_id when available for better debugging
4. **Preserve Context** - Use `with_telemetry_context` when spawning threads or background jobs
5. **Use Trace IDs for Distributed Tracing** - Set trace_id when calling external services

## Integration with Logging Tools

The structured JSON format is compatible with popular log aggregation tools:

- **Elasticsearch/Kibana** - Directly ingest JSON logs
- **Splunk** - Use JSON source type
- **Datadog** - Enable JSON log parsing
- **CloudWatch** - Use JSON format for better querying

## Examples

### Rails Integration

```ruby
# config/initializers/queue_bus.rb
require 'queue-bus'

QueueBus.logger = Rails.logger

if Rails.env.production?
  QueueBus.enable_structured_logging!(
    service_name: 'rails-app',
    environment: Rails.env,
    version: Rails.application.version
  )
end

# Middleware to set request context
class QueueBusRequestMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request_id = env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid

    QueueBus.set_request_id(request_id)
    QueueBus.set_user_id(env['warden']&.user&.id)
    QueueBus.set_session_id(env['rack.session']&.id)

    @app.call(env)
  ensure
    QueueBus::Telemetry.clear_context
  end
end

Rails.application.config.middleware.use QueueBusRequestMiddleware
```

### Publishing with Context

```ruby
# The context is automatically included
QueueBus.set_request_id
QueueBus.set_user_id(current_user.id)

QueueBus.publish('user_updated', {
  user_id: current_user.id,
  changes: current_user.previous_changes
})
# Event will include bus_request_id and bus_user_id
```

### Subscribing with Context

```ruby
class UserSubscriber
  include QueueBus::Subscriber
  subscribe :user_updated

  def user_updated(attributes)
    # Telemetry context is automatically restored from event attributes
    # QueueBus.request_id will be available here

    Rails.logger.info("Processing user update", {
      request_id: QueueBus.request_id,
      user_id: QueueBus.user_id
    })

    # Process the event
    User.find(attributes['user_id']).process_update
  end
end
```

## Backward Compatibility

The framework is fully backward compatible:

- Structured logging is **disabled by default**
- Plain text logging continues to work as before
- All existing code continues to function without changes
- Telemetry features are opt-in

To adopt the new features, simply enable structured logging and start setting telemetry context where appropriate.
