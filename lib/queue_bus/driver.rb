# frozen_string_literal: true

module QueueBus
  # Fans out an event to multiple queues
  #
  # When a single event is broadcast, it may have zero to many subscriptions attached to it.
  # The Driver is what is run in order to look up the subscription matches and enqueue each
  # of the jobs. It uses the class_name supplied by the subscription to know which class will
  # be performed.
  class Driver
    class << self
      def subscription_matches(attributes)
        out = []
        Application.all.each do |app|
          subs = app.subscription_matches(attributes)
          out.concat(subs)
        end
        out
      end

      def perform(attributes = {})
        raise 'No attributes passed' if attributes.empty?

        event_type = attributes['bus_event_type']
        correlation_id = attributes['bus_id']

        ::QueueBus.log_worker(
          'Driver processing event',
          event_type: event_type,
          correlation_id: correlation_id,
          attributes_count: attributes.size
        )

        matches = subscription_matches(attributes)

        if matches.empty?
          ::QueueBus.log_worker(
            'No subscription matches found for event',
            event_type: event_type,
            correlation_id: correlation_id
          )
        end

        matches.each do |sub|
          ::QueueBus.log_worker(
            'Dispatching event to subscription',
            event_type: event_type,
            correlation_id: correlation_id,
            queue_name: sub.queue_name,
            app_key: sub.app_key,
            subscription_key: sub.key,
            class_name: sub.class_name
          )

          bus_attr = {  'bus_driven_at' => Time.now.to_i,
                        'bus_rider_queue' => sub.queue_name,
                        'bus_rider_app_key' => sub.app_key,
                        'bus_rider_sub_key' => sub.key,
                        'bus_rider_class_name' => sub.class_name }
          bus_attr = bus_attr.merge(attributes || {})
          ::QueueBus.enqueue_to(sub.queue_name, sub.class_name, bus_attr)
        end
      end
    end
  end
end
