# frozen_string_literal: true

module AgentDesk
  module MessageBus
    # Abstract interface that all message bus adapters must implement.
    #
    # External adapters (e.g., Legion's +PostgresBus+) should include this
    # module and implement all four methods. The gem ships with +CallbackBus+
    # as the default in-process, zero-dependency adapter.
    #
    # @example Implementing a custom adapter
    #   class MyBus
    #     include AgentDesk::MessageBus::MessageBusInterface
    #
    #     def publish(channel, event) = ...
    #     def subscribe(pattern, &block) = ...
    #     def unsubscribe(pattern) = ...
    #     def clear = ...
    #   end
    module MessageBusInterface
      # Publish an event to a named channel.
      #
      # @param channel [String] dot-delimited channel name (e.g., +"agent.qa.response.chunk"+)
      # @param event [AgentDesk::MessageBus::Event] the event to publish
      # @return [void]
      def publish(channel, event)
        raise NotImplementedError, "#{self.class}#publish is not implemented"
      end

      # Subscribe to events matching a channel pattern.
      #
      # Patterns use dot-delimited segments. A trailing +.*+ acts as a wildcard
      # matching any sub-path: +"agent.*"+ matches +"agent.qa.response.chunk"+.
      # A bare +"*"+ matches every channel.
      #
      # @param pattern [String] channel pattern (e.g., +"agent.*"+, +"agent.qa.tool.called"+)
      # @yield [channel, event] called for each matching published event
      # @yieldparam channel [String] the exact channel the event was published on
      # @yieldparam event [AgentDesk::MessageBus::Event] the published event
      # @raise [ArgumentError] if pattern is nil or empty
      # @return [void]
      def subscribe(pattern, &block)
        raise NotImplementedError, "#{self.class}#subscribe is not implemented"
      end

      # Remove all subscribers for the given pattern.
      #
      # @param pattern [String] the exact pattern string used in a prior +subscribe+ call
      # @return [void]
      def unsubscribe(pattern)
        raise NotImplementedError, "#{self.class}#unsubscribe is not implemented"
      end

      # Remove all subscribers for all patterns.
      #
      # @return [void]
      def clear
        raise NotImplementedError, "#{self.class}#clear is not implemented"
      end
    end
  end
end
