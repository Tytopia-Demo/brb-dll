# Unified Logging Framework

This document describes the unified logging framework implemented in queue-bus, which provides structured JSON logging with telemetry context tracking for distributed tracing.

## Features

### 1. Structured JSON Logging

The framework supports both plain text (backwards compatible) and structured JSON logging formats.

#### Configuration

```ruby
# Enable structured JSON logging
QueueBus.structured_logging = true

# Configure service metadata
QueueBus.service_name = 'my-service'
QueueBus.environment = 'production'
QueueBus.log_version = '1.0.0'

# Set a logger (defaults to stdout)
QueueBus.logger = Logger.new('log/queue-bus.log')
```

#### Log Format

When structured logging is enabled, all log entries are output as JSON:

```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "level": "INFO",
  "message": "Event published: user_created",
  "service": "my-service",
  "environment": "production",
  "version": "1.0.0",
  "hostname": "app-server-01",
  "event_type": "user_created",
  "bus_id": "1705318245-uuid-here",
  "request_id": "req-123-456",
  "user_id": "user-789",
  "trace_id": "trace-abc-def"
}
```

### 2. Telemetry Context Tracking

The framework automatically tracks and propagates telemetry context across async operations and queue workers.

#### Setting Telemetry Context

```ruby
# Set complete telemetry context
QueueBus.set_telemetry_context(
  request_id: 'req-123-456',
  user_id: 'user-789',
  session_id: 'session-xyz',
  trace_id: 'trace-abc-def',
  parent_span_id: 'span-parent-id'
)

# Update specific fields
QueueBus.update_telemetry_context(user_id: 'user-789')

# Clear telemetry context
QueueBus.clear_telemetry_context
```

#### Using Telemetry Context in a Block

```ruby
# Execute code with specific telemetry context
QueueBus.with_telemetry_context(
  request_id: 'req-123-456',
  user_id: 'user-789'
) do
  # All events published and logs written in this block
  # will include the telemetry context
  QueueBus.publish('user_action', action: 'login')
end
```

### 3. Automatic Context Propagation

Telemetry context is automatically:

- **Injected into events** when published
- **Preserved in delayed jobs** via `publish_at`
- **Restored in workers** when processing events
- **Included in all log entries**

```ruby
# In a web request handler
QueueBus.set_telemetry_context(
  request_id: request.uuid,
  user_id: current_user.id,
  session_id: session.id
)

# Publish an event - telemetry context is automatically included
QueueBus.publish('user_updated', user_id: current_user.id)

# When the worker processes this event, the telemetry context is restored
# and all logs will include the original request_id, user_id, and session_id
```

### 4. Log Levels

The framework supports standard log levels:

- `DEBUG` - Detailed worker and driver information
- `INFO` - Application events (publishing, scheduling)
- `WARN` - Warning conditions
- `ERROR` - Error conditions
- `FATAL` - Critical errors

```ruby
# Application logs use INFO level
QueueBus.log_application("Event published", event_type: "user_created")

# Worker logs use DEBUG level
QueueBus.log_worker("Processing event", event_id: "123")
```

### 5. Metadata Enrichment

All log entries automatically include:

- **timestamp** - ISO8601 format with milliseconds
- **level** - Log level (DEBUG, INFO, WARN, ERROR, FATAL)
- **message** - Human-readable message
- **service** - Service name (configurable)
- **environment** - Environment (development, staging, production)
- **version** - Application version
- **hostname** - Server hostname
- **request_id** - Request identifier (from telemetry context)
- **user_id** - User identifier (from telemetry context)
- **session_id** - Session identifier (from telemetry context)
- **trace_id** - Distributed trace identifier (from telemetry context)

Additional metadata can be passed to any log call:

```ruby
QueueBus.log_application("Custom event", {
  custom_field: "value",
  count: 42,
  tags: ["important", "urgent"]
})
```

## Integration Examples

### Rails Integration

```ruby
# config/initializers/queue_bus.rb
QueueBus.configure do |config|
  # Enable structured logging in production
  config.structured_logging = Rails.env.production?
  config.service_name = 'my-rails-app'
  config.environment = Rails.env
  config.log_version = MyApp::VERSION
  config.logger = Rails.logger
end

# In a controller
class UsersController < ApplicationController
  before_action :set_telemetry_context

  def create
    @user = User.create!(user_params)

    # Telemetry context is automatically included
    QueueBus.publish('user_created', user_id: @user.id)

    render json: @user
  end

  private

  def set_telemetry_context
    QueueBus.set_telemetry_context(
      request_id: request.uuid,
      user_id: current_user&.id,
      session_id: session.id
    )
  end
end
```

### Middleware for Automatic Context

```ruby
# lib/middleware/telemetry_context_middleware.rb
class TelemetryContextMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    QueueBus.set_telemetry_context(
      request_id: request_id_from_header(request) || QueueBus.generate_request_id,
      trace_id: trace_id_from_header(request),
      user_id: extract_user_id(env),
      session_id: extract_session_id(env)
    )

    @app.call(env)
  ensure
    QueueBus.clear_telemetry_context
  end

  private

  def request_id_from_header(request)
    request.env['HTTP_X_REQUEST_ID']
  end

  def trace_id_from_header(request)
    request.env['HTTP_X_TRACE_ID']
  end

  def extract_user_id(env)
    # Extract from session, JWT, etc.
  end

  def extract_session_id(env)
    # Extract from cookie, etc.
  end
end

# In config.ru or application.rb
use TelemetryContextMiddleware
```

### Log Aggregation

The structured JSON format makes it easy to aggregate and analyze logs with tools like:

- **ELK Stack** (Elasticsearch, Logstash, Kibana)
- **Splunk**
- **DataDog**
- **CloudWatch Logs Insights**
- **Grafana Loki**

Example Elasticsearch query to trace a request:

```json
{
  "query": {
    "term": {
      "request_id": "req-123-456"
    }
  }
}
```

This will return all log entries across all services for that specific request.

## Backwards Compatibility

By default, structured logging is **disabled** to maintain backwards compatibility. The framework uses plain text logging unless explicitly enabled:

```ruby
# Default (backwards compatible) - plain text logs
QueueBus.structured_logging = false  # or not set

# Example output:
# I, [2024-01-15T10:30:45.123456]  INFO -- : Event published: user_created {"event_type":"user_created","bus_id":"1705318245-uuid"}

# Structured logging - JSON output
QueueBus.structured_logging = true

# Example output:
# {"timestamp":"2024-01-15T10:30:45.123Z","level":"INFO","message":"Event published: user_created","service":"queue-bus",...}
```

## Best Practices

1. **Always set telemetry context at entry points** (web requests, API calls, CLI commands)
2. **Use descriptive log messages** that are human-readable
3. **Include relevant metadata** to aid debugging
4. **Enable structured logging in production** for better observability
5. **Configure log aggregation** to correlate logs across services
6. **Use trace_id consistently** across your entire stack
7. **Clean up context** after processing to avoid leakage between requests

## Performance Considerations

- JSON serialization adds minimal overhead (~0.1-0.5ms per log entry)
- Telemetry context uses thread-local storage (thread-safe)
- Context propagation adds ~0.01ms per event publish/consume
- No performance impact when structured logging is disabled
