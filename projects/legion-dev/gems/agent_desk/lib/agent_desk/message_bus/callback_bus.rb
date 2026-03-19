# frozen_string_literal: true

module AgentDesk
  module MessageBus
    # In-process, zero-dependency message bus adapter.
    #
    # Stores subscribers in memory as a hash of pattern → array of callables.
    # All operations are protected by a +Mutex+ for thread safety. Callbacks are
    # invoked *outside* the lock to prevent deadlocks when subscribers call
    # +publish+ or +subscribe+ during their execution.
    #
    # Subscriber exceptions are rescued, logged via +warn+, and do not prevent
    # remaining subscribers from receiving the event.
    #
    # @example
    #   bus = AgentDesk::MessageBus::CallbackBus.new
    #   bus.subscribe("agent.*") { |channel, event| puts event.type }
    #   bus.publish("agent.qa.started", event)
    class CallbackBus
      include MessageBusInterface

      def initialize
        @subscriptions = {} # pattern => [callable, ...]
        @mutex = Mutex.new
      end

      # @param channel [String] dot-delimited channel name
      # @param event [Event] event to deliver
      # @return [void]
      def publish(channel, event)
        # Collect matching callbacks under lock, then invoke outside lock.
        callbacks = @mutex.synchronize do
          @subscriptions
            .select { |pattern, _| Channel.match?(pattern, channel) }
            .values
            .flatten
        end

        callbacks.each do |callback|
          begin
            callback.call(channel, event)
          rescue StandardError => e
            warn "AgentDesk::MessageBus subscriber error on '#{channel}': " \
                 "#{e.class}: #{e.message}"
          end
        end
      end

      # @param pattern [String] channel pattern to subscribe to
      # @raise [ArgumentError] if pattern is nil or empty
      # @yield [channel, event] invoked for each matching published event
      # @return [void]
      def subscribe(pattern, &block)
        raise ArgumentError, "pattern cannot be nil or empty" if pattern.nil? || pattern.empty?

        @mutex.synchronize do
          @subscriptions[pattern] ||= []
          @subscriptions[pattern] << block
        end
      end

      # Remove all subscribers registered under +pattern+.
      #
      # No-op if +pattern+ has no registered subscribers.
      #
      # @param pattern [String] the exact pattern string used when subscribing
      # @return [void]
      def unsubscribe(pattern)
        @mutex.synchronize { @subscriptions.delete(pattern) }
      end

      # Remove all subscribers for all patterns.
      #
      # @return [void]
      def clear
        @mutex.synchronize { @subscriptions.clear }
      end
    end
  end
end
