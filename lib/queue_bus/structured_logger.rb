# frozen_string_literal: true

require 'json'
require 'logger'

module QueueBus
  # A structured JSON logger that provides consistent log formatting across the application.
  # Outputs logs in JSON format with telemetry context and metadata enrichment.
  class StructuredLogger
    SEVERITY_MAPPING = {
      'DEBUG' => :debug,
      'INFO' => :info,
      'WARN' => :warn,
      'ERROR' => :error,
      'FATAL' => :fatal
    }.freeze

    attr_reader :logger
    attr_accessor :service_name, :environment, :version

    def initialize(logger = nil, service_name: 'queue-bus', environment: nil, version: nil)
      @logger = logger || Logger.new($stdout)
      @service_name = service_name
      @environment = environment || ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
      @version = version || QueueBus::VERSION

      # Set up JSON formatter for the underlying logger
      setup_json_formatter
    end

    # Log at different severity levels
    def debug(message = nil, context = {}, &block)
      log(:debug, message, context, &block)
    end

    def info(message = nil, context = {}, &block)
      log(:info, message, context, &block)
    end

    def warn(message = nil, context = {}, &block)
      log(:warn, message, context, &block)
    end

    def error(message = nil, context = {}, &block)
      log(:error, message, context, &block)
    end

    def fatal(message = nil, context = {}, &block)
      log(:fatal, message, context, &block)
    end

    # Main logging method that enriches with telemetry context
    def log(severity, message = nil, context = {})
      return unless @logger

      message = yield if block_given? && message.nil?

      log_entry = build_log_entry(severity, message, context)

      @logger.send(severity, log_entry.to_json)
    end

    private

    def setup_json_formatter
      return unless @logger

      @logger.formatter = proc do |_severity, _datetime, _progname, msg|
        # If message is already JSON, just add newline
        # Otherwise, keep it as-is for backwards compatibility
        "#{msg}\n"
      end
    end

    def build_log_entry(severity, message, context)
      {
        timestamp: Time.now.utc.iso8601(3),
        severity: severity.to_s.upcase,
        message: message.to_s,
        service: @service_name,
        environment: @environment,
        version: @version
      }.merge(extract_telemetry_context)
        .merge(context)
        .compact
    end

    def extract_telemetry_context
      context = {}

      # Get request ID from thread-local storage
      if Thread.current.thread_variable_get(:queue_bus_request_id)
        context[:request_id] = Thread.current.thread_variable_get(:queue_bus_request_id)
      end

      # Get trace ID from thread-local storage
      if Thread.current.thread_variable_get(:queue_bus_trace_id)
        context[:trace_id] = Thread.current.thread_variable_get(:queue_bus_trace_id)
      end

      # Get user ID from thread-local storage
      if Thread.current.thread_variable_get(:queue_bus_user_id)
        context[:user_id] = Thread.current.thread_variable_get(:queue_bus_user_id)
      end

      # Get session ID from thread-local storage
      if Thread.current.thread_variable_get(:queue_bus_session_id)
        context[:session_id] = Thread.current.thread_variable_get(:queue_bus_session_id)
      end

      context
    end
  end
end
