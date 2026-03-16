# frozen_string_literal: true

module QueueBus
  # A simple publishing worker for QueueBus. Makes publishing asynchronously possible since
  # it may be enqueued to the background worker with a delay. This will allow the event to
  # be published at a later time.
  class Publisher
    class << self
      def perform(attributes)
        event_type = attributes['bus_event_type']
        correlation_id = attributes['bus_id']

        ::QueueBus.log_worker(
          'Publisher executing delayed publish',
          event_type: event_type,
          correlation_id: correlation_id,
          delayed_until: attributes['bus_delayed_until']
        )

        ::QueueBus.publish(event_type, attributes)
      end
    end
  end
end
