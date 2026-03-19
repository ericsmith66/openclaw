# frozen_string_literal: true

module Legion
  # MessageBus adapter that bridges agent_desk gem events with PostgreSQL persistence.
  # Every event published during an agent run is persisted as a WorkflowEvent record.
  class PostgresBus
    include AgentDesk::MessageBus::MessageBusInterface

    def initialize(workflow_run:, skip_event_types: [], batch_mode: false)
      @workflow_run = workflow_run
      @skip_event_types = skip_event_types
      @batch_mode = batch_mode
      @callback_bus = AgentDesk::MessageBus::CallbackBus.new
    end

    # Publish an event to a named channel.
    # 1. Persists event to database (unless skipped)
    # 2. Forwards to internal CallbackBus for in-process subscribers
    # 3. Calls broadcast_event stub for future Solid Cable integration
    #
    # @param channel [String] dot-delimited channel name
    # @param event [AgentDesk::MessageBus::Event] the event to publish
    # @return [void]
    def publish(channel, event)
      persist_event(channel, event) unless @skip_event_types.include?(event.type)
    rescue StandardError => e
      Rails.logger.error(
        "[PostgresBus] DB write failed: #{e.class}: #{e.message} " \
        "(event: #{event.type}, run: #{@workflow_run.id})"
      )
    ensure
      # CallbackBus delivery MUST happen exactly once, even if DB write fails.
      @callback_bus.publish(channel, event)
      broadcast_event(channel, event)
    end

    # Subscribe to events matching a channel pattern.
    # Delegates to internal CallbackBus for subscriber management.
    #
    # @param pattern [String] channel pattern (e.g., "agent.*", "agent.qa.tool.called")
    # @yield [channel, event] called for each matching published event
    # @yieldparam channel [String] the exact channel the event was published on
    # @yieldparam event [AgentDesk::MessageBus::Event] the published event
    # @raise [ArgumentError] if pattern is nil or empty
    # @return [void]
    def subscribe(pattern, &block)
      @callback_bus.subscribe(pattern, &block)
    end

    # Remove all subscribers for the given pattern.
    # Delegates to internal CallbackBus.
    #
    # @param pattern [String] the exact pattern string used in a prior subscribe call
    # @return [void]
    def unsubscribe(pattern)
      @callback_bus.unsubscribe(pattern)
    end

    # Remove all subscribers.
    # Delegates to internal CallbackBus.
    # Does NOT delete WorkflowEvent records (persistence is permanent).
    #
    # @return [void]
    def clear
      @callback_bus.clear
    end

    private

    # Persist an event to the database as a WorkflowEvent record.
    #
    # @param channel [String] the channel the event was published on
    # @param event [AgentDesk::MessageBus::Event] the event to persist
    # @return [WorkflowEvent] the created record
    def persist_event(channel, event)
      WorkflowEvent.create!(
        workflow_run_id: @workflow_run.id,
        event_type: event.type,
        channel: channel,
        agent_id: event.agent_id,
        task_id: event.task_id,
        payload: serialize_payload(event.payload),
        recorded_at: event.timestamp
      )
    end

    # Serialize event payload for database storage.
    # Ensures non-Hash payloads are converted to an error marker hash.
    #
    # @param payload [Object] the event payload
    # @return [Hash] serialized payload suitable for JSONB storage
    def serialize_payload(payload)
      return payload if payload.is_a?(Hash)
      { "error" => "payload not serializable", "class" => payload.class.name }
    rescue StandardError
      { "error" => "payload serialization failed" }
    end

    # Solid Cable broadcast stub for Epic 4 integration.
    # Currently a no-op. Will use ActionCable.server.broadcast in Epic 4.
    #
    # TODO: Epic 4 - Activate Solid Cable broadcast for real-time UI updates
    #
    # @param channel [String] the channel the event was published on
    # @param event [AgentDesk::MessageBus::Event] the event to broadcast
    # @return [void]
    def broadcast_event(channel, event)
      # TODO: Epic 4 - Uncomment when ActionCable is integrated
      # ActionCable.server.broadcast("legion_events", {
      #   channel: channel,
      #   event_type: event.type,
      #   agent_id: event.agent_id,
      #   task_id: event.task_id,
      #   payload: event.payload,
      #   recorded_at: event.timestamp.iso8601
      # })
    end
  end
end
