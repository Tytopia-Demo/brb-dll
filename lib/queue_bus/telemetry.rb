# frozen_string_literal: true

module QueueBus
  # Telemetry context tracking for request ID, user ID, session ID, and trace ID
  module Telemetry
    TELEMETRY_VAR = :queue_bus_telemetry_context

    # Thread-safe wrapper for telemetry context
    TelemetryContext = Struct.new(:request_id, :user_id, :session_id, :trace_id, :parent_span_id) do
      def to_h
        hash = {}
        hash[:request_id] = request_id if request_id
        hash[:user_id] = user_id if user_id
        hash[:session_id] = session_id if session_id
        hash[:trace_id] = trace_id if trace_id
        hash[:parent_span_id] = parent_span_id if parent_span_id
        hash
      end
    end

    module_function

    # Get current telemetry context
    def current_context
      if Thread.current.thread_variable_get(TELEMETRY_VAR).is_a?(TelemetryContext)
        Thread.current.thread_variable_get(TELEMETRY_VAR)
      else
        nil
      end
    end

    # Set telemetry context
    def set_context(request_id: nil, user_id: nil, session_id: nil, trace_id: nil, parent_span_id: nil)
      context = TelemetryContext.new(
        request_id || generate_request_id,
        user_id,
        session_id,
        trace_id || request_id || generate_request_id,
        parent_span_id
      )
      Thread.current.thread_variable_set(TELEMETRY_VAR, context)
      context
    end

    # Update existing context with new values
    def update_context(request_id: nil, user_id: nil, session_id: nil, trace_id: nil, parent_span_id: nil)
      context = current_context || TelemetryContext.new

      context.request_id = request_id if request_id
      context.user_id = user_id if user_id
      context.session_id = session_id if session_id
      context.trace_id = trace_id if trace_id
      context.parent_span_id = parent_span_id if parent_span_id

      Thread.current.thread_variable_set(TELEMETRY_VAR, context)
      context
    end

    # Clear telemetry context
    def clear_context
      Thread.current.thread_variable_set(TELEMETRY_VAR, nil)
    end

    # Execute block with telemetry context
    def with_context(request_id: nil, user_id: nil, session_id: nil, trace_id: nil, parent_span_id: nil)
      previous = Thread.current.thread_variable_get(TELEMETRY_VAR)
      set_context(
        request_id: request_id,
        user_id: user_id,
        session_id: session_id,
        trace_id: trace_id,
        parent_span_id: parent_span_id
      )
      yield if block_given?
    ensure
      Thread.current.thread_variable_set(TELEMETRY_VAR, previous)
    end

    # Generate a unique request ID
    def generate_request_id
      require 'securerandom' unless defined?(SecureRandom)
      SecureRandom.uuid
    rescue StandardError
      # Fallback if SecureRandom is not available
      "#{Time.now.to_i}-#{rand(1_000_000)}"
    end

    # Extract telemetry context from attributes hash (for event propagation)
    def extract_from_attributes(attributes)
      return nil unless attributes.is_a?(Hash)

      TelemetryContext.new(
        attributes['bus_request_id'] || attributes['request_id'],
        attributes['bus_user_id'] || attributes['user_id'],
        attributes['bus_session_id'] || attributes['session_id'],
        attributes['bus_trace_id'] || attributes['trace_id'],
        attributes['bus_parent_span_id'] || attributes['parent_span_id']
      )
    end

    # Inject telemetry context into attributes hash (for event propagation)
    def inject_into_attributes(attributes, context = nil)
      context ||= current_context
      return attributes unless context

      hash = context.to_h
      attributes['bus_request_id'] = hash[:request_id] if hash[:request_id]
      attributes['bus_user_id'] = hash[:user_id] if hash[:user_id]
      attributes['bus_session_id'] = hash[:session_id] if hash[:session_id]
      attributes['bus_trace_id'] = hash[:trace_id] if hash[:trace_id]
      attributes['bus_parent_span_id'] = hash[:parent_span_id] if hash[:parent_span_id]

      attributes
    end
  end
end
