# frozen_string_literal: true

require 'json'
require 'logger'
require 'socket'

module QueueBus
  # A structured JSON logger that outputs logs in a consistent, machine-readable format.
  # Implements standardized logging with required fields including timestamp, level, message,
  # service name, correlation ID, and environment metadata.
  class JsonLogger
    # Standard log levels matching common observability standards
    module LogLevel
      DEBUG = 0
      INFO = 1
      WARN = 2
      ERROR = 3
      FATAL = 4
      UNKNOWN = 5
    end

    LEVEL_NAMES = {
      LogLevel::DEBUG => 'DEBUG',
      LogLevel::INFO => 'INFO',
      LogLevel::WARN => 'WARN',
      LogLevel::ERROR => 'ERROR',
      LogLevel::FATAL => 'FATAL',
      LogLevel::UNKNOWN => 'UNKNOWN'
    }.freeze

    attr_accessor :level, :service_name, :environment, :version
    attr_reader :output

    def initialize(output = $stdout, level: LogLevel::INFO)
      @output = output
      @level = level
      @service_name = 'queue-bus'
      @environment = ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      @version = QueueBus::VERSION
      @hostname = Socket.gethostname
    end

    # Log a message at DEBUG level
    def debug(message, **metadata)
      log(LogLevel::DEBUG, message, **metadata)
    end

    # Log a message at INFO level
    def info(message, **metadata)
      log(LogLevel::INFO, message, **metadata)
    end

    # Log a message at WARN level
    def warn(message, **metadata)
      log(LogLevel::WARN, message, **metadata)
    end

    # Log a message at ERROR level
    def error(message, **metadata)
      log(LogLevel::ERROR, message, **metadata)
    end

    # Log a message at FATAL level
    def fatal(message, **metadata)
      log(LogLevel::FATAL, message, **metadata)
    end

    # Main logging method that outputs structured JSON
    def log(severity, message, **metadata)
      return if severity < @level

      log_entry = build_log_entry(severity, message, metadata)
      output.puts(JSON.generate(log_entry))
    rescue StandardError => e
      # Fallback to plain text if JSON serialization fails
      output.puts("[JSON Logger Error] #{e.message}: #{message}")
    end

    private

    def build_log_entry(severity, message, metadata)
      entry = {
        timestamp: Time.now.utc.iso8601(3),
        level: LEVEL_NAMES[severity] || 'UNKNOWN',
        message: message.to_s,
        service: @service_name,
        environment: @environment,
        hostname: @hostname,
        version: @version,
        pid: Process.pid,
        thread_id: Thread.current.object_id
      }

      # Add correlation/request IDs if present
      entry[:correlation_id] = metadata.delete(:correlation_id) if metadata[:correlation_id]
      entry[:request_id] = metadata.delete(:request_id) if metadata[:request_id]
      entry[:trace_id] = metadata.delete(:trace_id) if metadata[:trace_id]

      # Add user context if present
      entry[:user_id] = metadata.delete(:user_id) if metadata[:user_id]

      # Add event context if present
      entry[:event_type] = metadata.delete(:event_type) if metadata[:event_type]
      entry[:app_key] = metadata.delete(:app_key) if metadata[:app_key]
      entry[:queue_name] = metadata.delete(:queue_name) if metadata[:queue_name]

      # Add error details if present
      if metadata[:error]
        error = metadata.delete(:error)
        entry[:error] = {
          class: error.class.name,
          message: error.message,
          backtrace: error.backtrace&.first(10)
        }
      end

      # Add stack trace if explicitly provided
      entry[:stack_trace] = metadata.delete(:stack_trace) if metadata[:stack_trace]

      # Add any remaining metadata as 'context'
      entry[:context] = metadata unless metadata.empty?

      entry
    end
  end

  # A logger adapter that wraps the standard Ruby Logger to provide structured JSON output
  class JsonLoggerAdapter
    attr_accessor :level

    def initialize(logger_or_output = $stdout, level: JsonLogger::LogLevel::INFO)
      @json_logger = if logger_or_output.is_a?(JsonLogger)
                       logger_or_output
                     elsif logger_or_output.is_a?(Logger)
                       # Wrap existing logger
                       JsonLogger.new(logger_or_output.instance_variable_get(:@logdev)&.dev || $stdout, level: level)
                     else
                       JsonLogger.new(logger_or_output, level: level)
                     end
      @level = level
    end

    # Delegate standard Logger methods to JsonLogger
    def debug(message = nil, **metadata, &block)
      message = yield if block_given? && message.nil?
      @json_logger.debug(message, **metadata)
    end

    def info(message = nil, **metadata, &block)
      message = yield if block_given? && message.nil?
      @json_logger.info(message, **metadata)
    end

    def warn(message = nil, **metadata, &block)
      message = yield if block_given? && message.nil?
      @json_logger.warn(message, **metadata)
    end

    def error(message = nil, **metadata, &block)
      message = yield if block_given? && message.nil?
      @json_logger.error(message, **metadata)
    end

    def fatal(message = nil, **metadata, &block)
      message = yield if block_given? && message.nil?
      @json_logger.fatal(message, **metadata)
    end

    # Support for standard Logger level setting
    def level=(level)
      @level = level
      @json_logger.level = level
    end

    # Query methods for log levels
    def debug?
      @level <= JsonLogger::LogLevel::DEBUG
    end

    def info?
      @level <= JsonLogger::LogLevel::INFO
    end

    def warn?
      @level <= JsonLogger::LogLevel::WARN
    end

    def error?
      @level <= JsonLogger::LogLevel::ERROR
    end

    def fatal?
      @level <= JsonLogger::LogLevel::FATAL
    end

    # For compatibility with code expecting standard Logger methods
    def add(severity, message = nil, progname = nil, &block)
      return true if severity < @level

      message = block.call if message.nil? && block_given?
      message = progname if message.nil?

      case severity
      when JsonLogger::LogLevel::DEBUG
        debug(message)
      when JsonLogger::LogLevel::INFO
        info(message)
      when JsonLogger::LogLevel::WARN
        warn(message)
      when JsonLogger::LogLevel::ERROR
        error(message)
      when JsonLogger::LogLevel::FATAL
        fatal(message)
      else
        info(message)
      end
    end

    # Provide access to the underlying JsonLogger
    def json_logger
      @json_logger
    end
  end
end
