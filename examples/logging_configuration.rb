# frozen_string_literal: true

# QueueBus Logging Configuration Examples
# This file demonstrates various logging configuration options

require 'queue-bus'

# ============================================================================
# Example 1: Default Configuration (JSON Logging Enabled)
# ============================================================================

# JSON logging is enabled by default, no configuration needed
# Logs will be output to STDOUT in JSON format

# ============================================================================
# Example 2: Custom Log Level
# ============================================================================

# Set log level based on environment
case ENV['RACK_ENV']
when 'production'
  QueueBus.logger.level = QueueBus::JsonLogger::LogLevel::INFO
when 'development'
  QueueBus.logger.level = QueueBus::JsonLogger::LogLevel::DEBUG
when 'test'
  QueueBus.logger.level = QueueBus::JsonLogger::LogLevel::WARN
end

# ============================================================================
# Example 3: Custom Output Destination
# ============================================================================

# Log to a file
log_file = File.open('log/queue_bus.log', 'a')
log_file.sync = true # Ensure immediate writes
QueueBus.logger = QueueBus::JsonLoggerAdapter.new(
  log_file,
  level: QueueBus::JsonLogger::LogLevel::INFO
)

# ============================================================================
# Example 4: Custom Service Name and Metadata
# ============================================================================

logger = QueueBus::JsonLogger.new($stdout)
logger.service_name = 'my-application'
logger.environment = 'staging'
logger.version = '2.0.0'

QueueBus.logger = QueueBus::JsonLoggerAdapter.new(logger)

# ============================================================================
# Example 5: Disable JSON Logging (Plain Text)
# ============================================================================

# For backward compatibility or debugging
QueueBus.use_json_logging = false
QueueBus.logger = Logger.new($stdout, level: Logger::INFO)

# ============================================================================
# Example 6: Rails Integration
# ============================================================================

# In config/initializers/queue_bus.rb
if defined?(Rails)
  QueueBus.logger = QueueBus::JsonLoggerAdapter.new(
    Rails.root.join('log', "queue_bus_#{Rails.env}.log"),
    level: Rails.env.production? ?
      QueueBus::JsonLogger::LogLevel::INFO :
      QueueBus::JsonLogger::LogLevel::DEBUG
  )

  # Optionally set service name to your application name
  QueueBus.logger.json_logger.service_name = Rails.application.class.module_parent_name.underscore
  QueueBus.logger.json_logger.environment = Rails.env
end

# ============================================================================
# Example 7: Environment-Specific Configuration
# ============================================================================

QueueBus.logger = case ENV['RACK_ENV']
when 'production'
  # Production: INFO level, file output, JSON format
  QueueBus::JsonLoggerAdapter.new(
    File.open('log/queue_bus_production.log', 'a'),
    level: QueueBus::JsonLogger::LogLevel::INFO
  )
when 'development'
  # Development: DEBUG level, stdout, JSON format
  QueueBus::JsonLoggerAdapter.new(
    $stdout,
    level: QueueBus::JsonLogger::LogLevel::DEBUG
  )
when 'test'
  # Test: WARN level to reduce noise
  QueueBus::JsonLoggerAdapter.new(
    $stdout,
    level: QueueBus::JsonLogger::LogLevel::WARN
  )
else
  # Default: INFO level, JSON format
  QueueBus::JsonLoggerAdapter.new($stdout)
end
