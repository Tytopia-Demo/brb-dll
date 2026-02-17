# frozen_string_literal: true

module QueueBus
  # only process local queues
  class Local
    class << self
      def publish(attributes = {})
        if ::QueueBus.local_mode == :suppress
          log_context = {
            event_type: attributes['bus_event_type'],
            bus_id: attributes['bus_id']
          }
          ::QueueBus.log_worker('Event suppressed in local mode', log_context)
          return # not doing anything
        end

        # To json and back to simlulate enqueueing
        json = ::QueueBus::Util.encode(attributes)
        attributes = ::QueueBus::Util.decode(json)

        log_context = {
          event_type: attributes['bus_event_type'],
          bus_id: attributes['bus_id'],
          local_mode: ::QueueBus.local_mode
        }
        ::QueueBus.log_worker('Local mode processing event', log_context)

        # looking for subscriptions, not queues
        subscription_matches(attributes).each do |sub|
          bus_attr = {  'bus_driven_at' => Time.now.to_i,
                        'bus_rider_queue' => sub.queue_name,
                        'bus_rider_app_key' => sub.app_key,
                        'bus_rider_sub_key' => sub.key,
                        'bus_rider_class_name' => sub.class_name }
          to_publish = bus_attr.merge(attributes || {})
          if ::QueueBus.local_mode == :standalone
            ::QueueBus.enqueue_to(sub.queue_name, sub.class_name, bus_attr.merge(attributes || {}))
          else # defaults to inline mode
            sub.execute!(to_publish)
          end
        end
      end

      # looking directly at subscriptions loaded into dispatcher
      # so we don't need redis server up
      def subscription_matches(attributes)
        out = []
        ::QueueBus.dispatchers.each do |dispatcher|
          out.concat(dispatcher.subscription_matches(attributes))
        end
        out
      end
    end
  end
end
