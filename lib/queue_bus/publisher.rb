# frozen_string_literal: true

module QueueBus
  # A simple publishing worker for QueueBus. Makes publishing asynchronously possible since
  # it may be enqueued to the background worker with a delay. This will allow the event to
  # be published at a later time.
  class Publisher
    class << self
      def perform(attributes)
        event_type = attributes['bus_event_type']

        log_context = {
          event_type: event_type,
          bus_id: attributes['bus_id'],
          delayed_until: attributes['bus_delayed_until']
        }
        ::QueueBus.log_worker('Publisher executing delayed event', log_context)

        ::QueueBus.publish(event_type, attributes)
      end
    end
  end
end
