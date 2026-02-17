# frozen_string_literal: true

module QueueBus
  # Manages telemetry context throughout the application lifecycle.
  # Provides thread-safe context propagation for request tracing and observability.
  module Telemetry
    CONTEXT_VARS = {
      request_id: :queue_bus_request_id,
      trace_id: :queue_bus_trace_id,
      user_id: :queue_bus_user_id,
      session_id: :queue_bus_session_id
    }.freeze

    class << self
      # Set telemetry context for the current thread
      def set_context(context = {})
        context.each do |key, value|
          if CONTEXT_VARS.key?(key.to_sym)
            Thread.current.thread_variable_set(CONTEXT_VARS[key.to_sym], value)
          end
        end
      end

      # Get current telemetry context
      def get_context
        context = {}
        CONTEXT_VARS.each do |key, var|
          value = Thread.current.thread_variable_get(var)
          context[key] = value if value
        end
        context
      end

      # Clear telemetry context for the current thread
      def clear_context
        CONTEXT_VARS.each_value do |var|
          Thread.current.thread_variable_set(var, nil)
        end
      end

      # Execute a block with specific telemetry context
      def with_context(context = {})
        previous = get_context
        set_context(context)
        yield
      ensure
        clear_context
        set_context(previous)
      end

      # Generate a new request ID
      def generate_request_id
        require 'securerandom' unless defined?(SecureRandom)
        SecureRandom.uuid
      rescue StandardError
        # Fallback if SecureRandom is not available
        "#{Time.now.to_i}-#{rand(999999)}-#{rand(999999)}"
      end

      # Set request ID (generate if not provided)
      def set_request_id(request_id = nil)
        request_id ||= generate_request_id
        Thread.current.thread_variable_set(:queue_bus_request_id, request_id)
        request_id
      end

      # Get current request ID
      def request_id
        Thread.current.thread_variable_get(:queue_bus_request_id)
      end

      # Set trace ID
      def set_trace_id(trace_id)
        Thread.current.thread_variable_set(:queue_bus_trace_id, trace_id)
      end

      # Get current trace ID
      def trace_id
        Thread.current.thread_variable_get(:queue_bus_trace_id)
      end

      # Set user ID
      def set_user_id(user_id)
        Thread.current.thread_variable_set(:queue_bus_user_id, user_id)
      end

      # Get current user ID
      def user_id
        Thread.current.thread_variable_get(:queue_bus_user_id)
      end

      # Set session ID
      def set_session_id(session_id)
        Thread.current.thread_variable_set(:queue_bus_session_id, session_id)
      end

      # Get current session ID
      def session_id
        Thread.current.thread_variable_get(:queue_bus_session_id)
      end

      # Extract telemetry context from event attributes
      def extract_from_attributes(attributes)
        context = {}

        # Map bus_id to request_id if present
        context[:request_id] = attributes['bus_request_id'] || attributes['bus_id'] if attributes['bus_id']
        context[:trace_id] = attributes['bus_trace_id'] if attributes['bus_trace_id']
        context[:user_id] = attributes['bus_user_id'] if attributes['bus_user_id']
        context[:session_id] = attributes['bus_session_id'] if attributes['bus_session_id']

        context
      end

      # Inject telemetry context into event attributes
      def inject_into_attributes(attributes)
        context = get_context

        attributes['bus_request_id'] = context[:request_id] if context[:request_id]
        attributes['bus_trace_id'] = context[:trace_id] if context[:trace_id]
        attributes['bus_user_id'] = context[:user_id] if context[:user_id]
        attributes['bus_session_id'] = context[:session_id] if context[:session_id]

        attributes
      end
    end
  end
end
