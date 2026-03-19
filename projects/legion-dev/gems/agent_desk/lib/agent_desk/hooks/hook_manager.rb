# frozen_string_literal: true

module AgentDesk
  module Hooks
    # Manages registration and triggering of lifecycle hooks.
    #
    # Hook events are defined as symbols. Default events are:
    # - `:on_agent_started`
    # - `:on_tool_called`
    # - `:on_tool_finished`
    # - `:on_handle_approval`
    #
    # Additional events can be added at runtime via {#register_event}.
    #
    # Handlers are called in registration order. Each handler receives the current
    # event data hash and a context hash. It may return `nil` (skip), or a
    # {HookResult}. If a handler returns a {HookResult} with `blocked: true`,
    # triggering short‑circuits and that result is returned. Otherwise, the event
    # data may be updated (via `HookResult#event`) and a result value stored.
    #
    # The manager is thread‑safe for registration and clearing; triggering copies
    # the handler list before execution so that handlers added during a trigger
    # are not called in the same run.
    class HookManager
      # Default hook events.
      #
      # Includes lifecycle events from the base runner (0090), tool framework (0020),
      # and compaction/handoff (0092b).
      EVENTS = %i[
        on_agent_started on_tool_called on_tool_finished on_handle_approval
        on_token_budget_warning on_cost_budget_exceeded on_handoff_created
      ].freeze

      # Creates a new HookManager with empty handlers for the default events.
      def initialize
        @mutex = Mutex.new
        @handlers = EVENTS.each_with_object({}) { |event, h| h[event] = [] }
      end

      # Registers a new event type at runtime.
      #
      # @param event [Symbol] the event name to register
      # @return [self] for chaining
      # @note If the event is already registered (including default events),
      #   this method does nothing.
      def register_event(event)
        @mutex.synchronize do
          @handlers[event] ||= []
        end
        self
      end

      # Adds a handler for the given event.
      #
      # @param event [Symbol] the event to listen for
      # @yield [event_data, context] the block that will be called when the event is triggered
      # @yieldparam event_data [Hash] the current event data (may be mutated by previous handlers)
      # @yieldparam context [Hash] additional context passed by the trigger caller
      # @yieldreturn [HookResult, nil] a hook result that may block, modify event data, or store a result
      # @return [self] for chaining
      # @raise [ArgumentError] if the event is not registered (see {#register_event})
      def on(event, &handler)
        validate_event!(event)
        @mutex.synchronize do
          @handlers[event] << handler
        end
        self
      end

      # Triggers all handlers registered for `event`.
      #
      # Handlers are called in registration order. If a handler returns a
      # {HookResult} with `blocked: true`, processing stops and that result is
      # returned. Otherwise, the event data may be updated (via `HookResult#event`)
      # and the most recent non‑nil `HookResult#result` is remembered.
      #
      # @param event [Symbol] the event to trigger
      # @param event_data [Hash] initial event data (default: `{}`)
      # @param context [Hash] additional context passed to each handler (default: `{}`)
      # @return [HookResult] the aggregated result of the triggered handlers
      # @raise [ArgumentError] if the event is not registered
      def trigger(event, event_data = {}, context = {})
        validate_event!(event)
        handlers = nil
        @mutex.synchronize { handlers = @handlers[event].dup }

        current_event = event_data.dup
        result = nil

        handlers.each do |handler|
          hook_result = handler.call(current_event, context)
          next unless hook_result.is_a?(HookResult)

          if hook_result.blocked
            current_event = hook_result.event unless hook_result.event.empty?
            return HookResult.new(blocked: true, event: current_event, result: hook_result.result)
          end

          current_event = hook_result.event unless hook_result.event.empty?
          result = hook_result.result
        end

        HookResult.new(blocked: false, event: current_event, result: result)
      end

      # Removes all handlers for a specific event, or for all events if `event` is `nil`.
      #
      # @param event [Symbol, nil] the event to clear, or `nil` to clear all events
      # @return [self] for chaining
      # @raise [ArgumentError] if `event` is not `nil` and not registered
      def clear(event = nil)
        @mutex.synchronize do
          if event
            validate_event!(event)
            @handlers[event].clear
          else
            @handlers.each_value(&:clear)
          end
        end
        self
      end

      private

      # Validates that `event` is a known event (default or registered).
      #
      # @param event [Symbol] the event to check
      # @raise [ArgumentError] if the event is unknown
      def validate_event!(event)
        return if @handlers.key?(event)

        raise ArgumentError, "Unknown hook event: #{event}"
      end
    end
  end
end
