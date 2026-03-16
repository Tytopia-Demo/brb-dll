# frozen_string_literal: true

module QueueBus
  # A helper class for executing Rake tasks.
  class TaskManager
    attr_reader :logging

    def initialize(logging)
      @logging = logging
    end

    def subscribe!
      count = 0
      ::QueueBus.dispatchers.each do |dispatcher|
        subscriptions = dispatcher.subscriptions
        next if subscriptions.empty?

        count += subscriptions.size
        log(
          'Subscribing application to event bus',
          app_key: dispatcher.app_key,
          subscription_count: subscriptions.size
        )
        app = ::QueueBus::Application.new(dispatcher.app_key)
        app.subscribe(subscriptions, logging)
        log('Subscription complete', app_key: dispatcher.app_key)
      end
      count
    end

    def unsubscribe_queue!(app_key, queue)
      log('Unsubscribing queue from application', app_key: app_key, queue_name: queue)
      app = ::QueueBus::Application.new(app_key)
      app.unsubscribe_queue(queue)
      log('Unsubscribe complete', app_key: app_key, queue_name: queue)
    end

    def unsubscribe!
      count = 0
      ::QueueBus.dispatchers.each do |dispatcher|
        log('Unsubscribing application from event bus', app_key: dispatcher.app_key)
        app = ::QueueBus::Application.new(dispatcher.app_key)
        app.unsubscribe
        count += 1
        log('Unsubscribe complete', app_key: dispatcher.app_key)
      end
    end

    def queue_names
      # let's not talk to redis in here. Seems to screw things up
      queues = []
      ::QueueBus.dispatchers.each do |dispatcher|
        dispatcher.subscriptions.all.each do |sub|
          queues << sub.queue_name
        end
      end

      queues.uniq
    end

    def log(message, **metadata)
      return unless logging

      if ::QueueBus.use_json_logging?
        ::QueueBus.log_application(message, **metadata)
      else
        # Fallback to puts for compatibility
        puts(message)
      end
    end
  end
end
