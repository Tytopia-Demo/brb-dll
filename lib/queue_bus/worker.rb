# frozen_string_literal: true

module QueueBus
  class Worker
    def self.perform(json)
      klass = nil
      attributes = ::QueueBus::Util.decode(json)

      # Extract and restore telemetry context from event attributes
      telemetry_context = ::QueueBus::Telemetry.extract_from_attributes(attributes)

      ::QueueBus::Telemetry.with_context(
        request_id: telemetry_context&.request_id,
        user_id: telemetry_context&.user_id,
        session_id: telemetry_context&.session_id,
        trace_id: telemetry_context&.trace_id,
        parent_span_id: telemetry_context&.parent_span_id
      ) do
        begin
          class_name = attributes['bus_class_proxy']
          klass = ::QueueBus::Util.constantize(class_name)
        rescue NameError
          # not there anymore
          return
        end

        QueueBus.worker_middleware_stack.run(attributes) do
          klass.perform(attributes)
        end
      end
    end

    # all our workers include this one
    def perform(json)
      # instance method level support for sidekiq
      self.class.perform(json)
    end
  end
end
