# frozen_string_literal: true

# Example configuration for enabling structured JSON logging with telemetry context

# Basic configuration (backwards compatible - plain text logging)
QueueBus.logger = Logger.new($stdout)

# Enable structured JSON logging (opt-in)
QueueBus.structured_logging = true

# Configure service metadata (recommended for structured logging)
QueueBus.service_name = 'my-application'
QueueBus.environment = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
QueueBus.log_version = '1.0.0' # Your application version

# After changing logging configuration, reset the logger instance
QueueBus.reset_logger!

# Example: Setting telemetry context at application entry points
# (e.g., in a Rails controller or Rack middleware)
QueueBus.set_telemetry_context(
  request_id: 'req-abc-123',
  user_id: 'user-456',
  session_id: 'session-789',
  trace_id: 'trace-xyz'
)

# Example: Publishing an event with telemetry context
QueueBus.publish('user_created', user_id: 42, name: 'John Doe')
# The telemetry context is automatically included in the event

# Example: Using telemetry context in a block
QueueBus.with_telemetry_context(request_id: 'req-def-456', user_id: 'user-999') do
  # All events published in this block will have this telemetry context
  QueueBus.publish('order_placed', order_id: 123)
  QueueBus.publish('inventory_updated', item_id: 456)
end
# Context is automatically cleared after the block

# Example: Generating a request ID
request_id = QueueBus.generate_request_id
QueueBus.set_telemetry_context(request_id: request_id)

# Example: Rails initializer
# config/initializers/queue_bus.rb (Rails)
if defined?(Rails)
  QueueBus.structured_logging = Rails.env.production?
  QueueBus.service_name = 'my-rails-app'
  QueueBus.environment = Rails.env
  QueueBus.log_version = Rails.application.config.version rescue '1.0.0'
  QueueBus.logger = Rails.logger
  QueueBus.reset_logger!
end

# Example: Rack middleware for automatic telemetry context
class QueueBusTelemetryMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Extract or generate request ID
    request_id = request.env['HTTP_X_REQUEST_ID'] || QueueBus.generate_request_id

    # Extract trace ID from headers (for distributed tracing)
    trace_id = request.env['HTTP_X_TRACE_ID'] || request_id

    # Set telemetry context for this request
    QueueBus.set_telemetry_context(
      request_id: request_id,
      trace_id: trace_id,
      # Extract user_id and session_id from your authentication system
      # user_id: extract_user_id(env),
      # session_id: extract_session_id(env)
    )

    # Add request ID to response headers for client-side correlation
    status, headers, body = @app.call(env)
    headers['X-Request-ID'] = request_id
    [status, headers, body]
  ensure
    QueueBus.clear_telemetry_context
  end
end
