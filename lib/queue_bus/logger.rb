# frozen_string_literal: true

require 'logger'
require 'json'

module QueueBus
  # Structured JSON logger with telemetry context tracking
  class StructuredLogger
    LEVELS = {
      debug: Logger::DEBUG,
      info: Logger::INFO,
      warn: Logger::WARN,
      error: Logger::ERROR,
      fatal: Logger::FATAL
    }.freeze

    attr_accessor :logger, :service_name, :environment, :version

    def initialize(logger = nil, service_name: nil, environment: nil, version: nil)
      @logger = logger || Logger.new($stdout)
      @service_name = service_name || 'queue-bus'
      @environment = environment || ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      @version = version || QueueBus::VERSION

      # Set default formatter for non-structured loggers
      if @logger.respond_to?(:formatter=) && @logger.formatter.nil?
        @logger.formatter = proc do |severity, datetime, progname, msg|
          "#{datetime.iso8601} #{severity} #{progname}: #{msg}\n"
        end
      end
    end

    # Log with structured JSON format
    def log(level, message, metadata = {})
      return unless @logger

      log_entry = build_log_entry(level, message, metadata)

      # Output as JSON
      json_log = JSON.generate(log_entry)

      # Use appropriate log level
      case level.to_sym
      when :debug
        @logger.debug(json_log)
      when :info
        @logger.info(json_log)
      when :warn
        @logger.warn(json_log)
      when :error
        @logger.error(json_log)
      when :fatal
        @logger.fatal(json_log)
      else
        @logger.info(json_log)
      end
    end

    # Convenience methods for different log levels
    def debug(message, metadata = {})
      log(:debug, message, metadata)
    end

    def info(message, metadata = {})
      log(:info, message, metadata)
    end

    def warn(message, metadata = {})
      log(:warn, message, metadata)
    end

    def error(message, metadata = {})
      log(:error, message, metadata)
    end

    def fatal(message, metadata = {})
      log(:fatal, message, metadata)
    end

    private

    def build_log_entry(level, message, metadata)
      entry = {
        timestamp: Time.now.utc.iso8601(3),
        level: level.to_s.upcase,
        message: message,
        service: @service_name,
        environment: @environment,
        version: @version,
        hostname: ::QueueBus.hostname
      }

      # Add telemetry context if available
      telemetry = ::QueueBus.telemetry_context
      entry.merge!(telemetry) if telemetry && !telemetry.empty?

      # Add any additional metadata
      entry.merge!(metadata) if metadata && !metadata.empty?

      entry
    end
  end

  # Backwards-compatible plain text logger wrapper
  class PlainTextLogger
    attr_accessor :logger

    def initialize(logger = nil)
      @logger = logger || Logger.new($stdout)
    end

    def debug(message, _metadata = {})
      @logger&.debug(message)
    end

    def info(message, _metadata = {})
      @logger&.info(message)
    end

    def warn(message, _metadata = {})
      @logger&.warn(message)
    end

    def error(message, _metadata = {})
      @logger&.error(message)
    end

    def fatal(message, _metadata = {})
      @logger&.fatal(message)
    end
  end
end
