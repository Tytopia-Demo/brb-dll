# frozen_string_literal: true

# require 'queue_bus/tasks'
# A useful set of rake tasks for managing your bus

# rubocop:disable Metrics/BlockLength
namespace :queuebus do
  desc 'Subscribes this application to QueueBus events'
  task subscribe: [:preload] do
    manager = ::QueueBus::TaskManager.new(true)
    count = manager.subscribe!
    raise 'No subscriptions created' if count == 0
  end

  desc "Unsubscribes this application from QueueBus events"
  task :unsubscribe, [:app_key, :queue] => [ :preload ] do |task, args|
    app_key = args[:app_key]
    queue = args[:queue]
    manager = ::QueueBus::TaskManager.new(true)

    if app_key && queue
      manager.unsubscribe_queue!(app_key, queue)
    else
      manager = ::QueueBus::TaskManager.new(true)
      count = manager.unsubscribe!
      if count == 0
        ::QueueBus.log_warn('No subscriptions unsubscribed')
        puts "No subscriptions unsubscribed"
      end
    end
  end

  desc 'List QueueBus queues that need worked'
  task queues: [:preload] do
    manager = ::QueueBus::TaskManager.new(false)
    queues = manager.queue_names + ['bus_incoming']
    ::QueueBus.log_application('Listing queue names', queue_count: queues.size, queues: queues)
    puts queues.join(', ')
  end

  desc 'list time based subscriptions'
  task list_scheduled: [:preload] do
    scheduled_list = QueueBus::Application.all.flat_map do |app|
      app.send(:subscriptions).all
         .select { |s| s.matcher.filters['bus_event_type'] == 'heartbeat_minutes' }
    end
    scheduled_text_list = scheduled_list.collect do |e|
      [e.key, e.matcher.filters['hour'] || '*', e.matcher.filters['minute'] || '*']
    end
    ::QueueBus.log_application('Listing scheduled subscriptions', scheduled_count: scheduled_list.size)
    puts 'key, hour, minute'
    puts scheduled_text_list.sort_by { |(_, hour, minute)| [hour.to_i, minute.to_i] }.map(&:to_csv)
  end

  # Preload app files if this is Rails
  # you can also do this to load the right things
  task :preload do
    require 'queue-bus'
  end
end
# rubocop:enable Metrics/BlockLength
