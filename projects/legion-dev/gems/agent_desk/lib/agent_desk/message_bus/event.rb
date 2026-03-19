# frozen_string_literal: true

module AgentDesk
  module MessageBus
    # Immutable typed struct representing a single agent event.
    #
    # All fields except +type+ have sensible defaults so callers only need to
    # supply what is meaningful for the event.
    #
    # @example
    #   event = AgentDesk::MessageBus::Event.new(
    #     type:     "response.chunk",
    #     source:   "agent_desk",
    #     agent_id: "qa-agent",
    #     task_id:  "task-123",
    #     payload:  { content: "Hello" }
    #   )
    Event = Data.define(:type, :source, :agent_id, :task_id, :timestamp, :payload) do
      # @param type [String] event type identifier (e.g., +"response.chunk"+)
      # @param source [String] origin identifier (default: +"agent_desk"+)
      # @param agent_id [String, nil] agent that emitted the event
      # @param task_id [String, nil] task the event belongs to
      # @param timestamp [Time] event creation time (default: +Time.now+, evaluated at construction)
      # @param payload [Hash] event-specific data (default: +{}+)
      # @note The +payload+ Hash is NOT frozen. Pass a frozen hash (e.g., +payload.freeze+)
      #   if immutability is required by your adapter or subscriber.
      def initialize(type:, source: "agent_desk", agent_id: nil, task_id: nil,
                     timestamp: nil, payload: {})
        super(
          type:      type,
          source:    source,
          agent_id:  agent_id,
          task_id:   task_id,
          timestamp: timestamp || Time.now,
          payload:   payload
        )
      end
    end
  end
end
