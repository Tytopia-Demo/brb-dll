# frozen_string_literal: true

module QueueBus
  # Middleware that preserves telemetry context across async operations.
  # Extracts context from event attributes and sets it for the duration of the worker execution.
  class TelemetryMiddleware < Middleware::Abstract
    def call(attributes)
      # Extract telemetry context from attributes
      telemetry_context = Telemetry.extract_from_attributes(attributes)

      # Execute the worker with telemetry context
      Telemetry.with_context(telemetry_context) do
        @app.call
      end
    end
  end
end
