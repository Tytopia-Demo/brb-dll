# frozen_string_literal: true

require 'socket'
require 'logger'

module QueueBus
  # This class contains all the configuration for a running queue bus application.
  class Config
    attr_accessor :default_queue, :hostname, :incoming_queue
    attr_reader :worker_middleware_stack
    attr_writer :local_mode, :context

    # Structured logging configuration
    attr_accessor :structured_logging_enabled, :service_name, :log_environment, :log_version

    def initialize
      @worker_middleware_stack = QueueBus::Middleware::Stack.new
      @incoming_queue = 'bus_incoming'
      @hostname = Socket.gethostname
      @structured_logging_enabled = false
      @service_name = 'queue-bus'
      @log_environment = nil
      @log_version = nil

      # Register telemetry middleware by default
      @worker_middleware_stack.use(QueueBus::TelemetryMiddleware)
    end

    # Get or set the logger
    def logger=(logger_instance)
      @logger = logger_instance
      @structured_logger = nil # Reset structured logger when logger changes
    end

    def logger
      @logger
    end

    # Get the structured logger instance
    def structured_logger
      @structured_logger ||= create_structured_logger
    end

    private

    def create_structured_logger
      return nil unless @logger

      QueueBus::StructuredLogger.new(
        @logger,
        service_name: @service_name,
        environment: @log_environment,
        version: @log_version
      )
    end

    public

    # A wrapper that is always "truthy" but can contain an inner value. This is useful for
    # checking that a thread local variable is set to a value, even if that value happens to
    # be nil. This is important because setting a thread local value to nil will cause it to
    # be deleted.
    Wrap = Struct.new(:value)

    LOCAL_MODE_VAR = :queue_bus_local_mode
    CONTEXT_VAR = :queue_bus_context

    # Returns the current local mode of QueueBus
    def local_mode
      if Thread.current.thread_variable_get(LOCAL_MODE_VAR).is_a?(Wrap)
        Thread.current.thread_variable_get(LOCAL_MODE_VAR).value
      else
        @local_mode
      end
    end

    # Returns the current context of QueueBus
    def context
      if Thread.current.thread_variable_get(CONTEXT_VAR).is_a?(Wrap)
        Thread.current.thread_variable_get(CONTEXT_VAR).value
      else
        @context
      end
    end

    # Overrides the current local mode for the duration of a block. This is a threadsafe
    # implementation. After, the global setting will be resumed.
    #
    # @param mode [Symbol] the mode to switch to
    def with_local_mode(mode)
      previous = Thread.current.thread_variable_get(LOCAL_MODE_VAR)
      Thread.current.thread_variable_set(LOCAL_MODE_VAR, Wrap.new(mode))
      yield if block_given?
    ensure
      Thread.current.thread_variable_set(LOCAL_MODE_VAR, previous)
    end

    # Overrides the current bus context (if any) for the duration of a block, adding a
    # `bus_context` attribute set to this value for all events published in this scope. 
    # This is a threadsafe implementation. After, the global setting will be resumed.
    def in_context(context)
      previous = Thread.current.thread_variable_get(CONTEXT_VAR)
      Thread.current.thread_variable_set(CONTEXT_VAR, Wrap.new(context))
      yield if block_given?
    ensure
      Thread.current.thread_variable_set(CONTEXT_VAR, previous)
    end

    def adapter=(val)
      raise "Adapter already set to #{@adapter_instance.class.name}" if has_adapter?

      @adapter_instance =
        if val.is_a?(Class)
          val.new
        elsif val.is_a?(::QueueBus::Adapters::Base)
          val
        else
          class_name = ::QueueBus::Util.classify(val)
          ::QueueBus::Util.constantize("::QueueBus::Adapters::#{class_name}").new
        end
    end

    def adapter
      return @adapter_instance if has_adapter?

      raise 'no adapter has been set'
    end

    # Checks whether an adapter is set and returns true if it is.
    def has_adapter? # rubocop:disable Naming/PredicateName
      !@adapter_instance.nil?
    end

    def redis(&block)
      # TODO: could allow setting for non-redis adapters
      adapter.redis(&block)
    end

    attr_reader :default_app_key
    def default_app_key=(val)
      @default_app_key = Application.normalize(val)
    end

    def before_publish=(callback)
      @before_publish_callback = callback
    end

    def before_publish_callback(attributes)
      @before_publish_callback&.call(attributes)
    end

    def log_application(message, context = {})
      if @structured_logging_enabled && structured_logger
        structured_logger.info(message, context)
      else
        logger&.info(message)
      end
    end

    def log_worker(message, context = {})
      if @structured_logging_enabled && structured_logger
        structured_logger.debug(message, context)
      else
        logger&.debug(message)
      end
    end

    # Enable structured JSON logging
    def enable_structured_logging!(service_name: 'queue-bus', environment: nil, version: nil)
      @structured_logging_enabled = true
      @service_name = service_name
      @log_environment = environment
      @log_version = version
      @structured_logger = nil # Force recreation with new settings
    end

    # Disable structured JSON logging (revert to plain text)
    def disable_structured_logging!
      @structured_logging_enabled = false
      @structured_logger = nil
    end
  end
end
