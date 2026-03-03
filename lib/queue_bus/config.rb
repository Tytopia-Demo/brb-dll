# frozen_string_literal: true

require 'socket'
require 'logger'

module QueueBus
  # This class contains all the configuration for a running queue bus application.
  class Config
    attr_accessor :default_queue, :hostname, :incoming_queue, :logger
    attr_accessor :structured_logging, :service_name, :environment, :log_version

    attr_reader :worker_middleware_stack
    attr_writer :local_mode, :context

    def initialize
      @worker_middleware_stack = QueueBus::Middleware::Stack.new
      @incoming_queue = 'bus_incoming'
      @hostname = Socket.gethostname
      @structured_logging = false # default to plain text for backwards compatibility
      @service_name = nil
      @environment = nil
      @log_version = nil
    end

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

    # Get structured logger instance
    def structured_logger
      @structured_logger ||= begin
        if @structured_logging
          ::QueueBus::StructuredLogger.new(
            @logger,
            service_name: @service_name,
            environment: @environment,
            version: @log_version
          )
        else
          ::QueueBus::PlainTextLogger.new(@logger)
        end
      end
    end

    # Reset structured logger (useful when config changes)
    def reset_logger!
      @structured_logger = nil
    end

    def log_application(message, metadata = {})
      structured_logger.info(message, metadata)
    end

    def log_worker(message, metadata = {})
      structured_logger.debug(message, metadata)
    end

    # Get current telemetry context as hash
    def telemetry_context
      context = ::QueueBus::Telemetry.current_context
      context&.to_h || {}
    end
  end
end
