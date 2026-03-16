# frozen_string_literal: true

module QueueBus
  # The Rider is meant to execute subscriptions.
  #
  # When your application has subscriptions to an event we still need to enqueue some executor that
  # will execute the block that was registered. The Rider will effectively ride the bus for your
  # subscribed event. One Rider is launched for each subscription on an event.
  class Rider
    def self.perform(attributes = {})
      sub_key = attributes['bus_rider_sub_key']
      app_key = attributes['bus_rider_app_key']
      raise 'No application key passed' if app_key.to_s == ''
      raise 'No subcription key passed' if sub_key.to_s == ''

      attributes ||= {}
      event_type = attributes['bus_event_type']
      correlation_id = attributes['bus_id']

      ::QueueBus.log_worker(
        'Rider executing subscription',
        event_type: event_type,
        correlation_id: correlation_id,
        app_key: app_key,
        subscription_key: sub_key,
        queue_name: attributes['bus_rider_queue']
      )

      # attributes that should be available
      # attributes["bus_event_type"]
      # attributes["bus_app_key"]
      # attributes["bus_published_at"]
      # attributes["bus_driven_at"]

      # (now running with the real app that subscribed)
      begin
        ::QueueBus.dispatcher_execute(app_key, sub_key,
                                      attributes.merge('bus_executed_at' => Time.now.to_i))
      rescue StandardError => e
        ::QueueBus.log_error(
          'Error executing subscription',
          error: e,
          event_type: event_type,
          correlation_id: correlation_id,
          app_key: app_key,
          subscription_key: sub_key
        )
        raise
      end
    end
  end
end
