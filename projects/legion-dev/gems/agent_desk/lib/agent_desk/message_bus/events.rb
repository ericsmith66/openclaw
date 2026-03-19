# frozen_string_literal: true

module AgentDesk
  module MessageBus
    # Convenience constructors for all standard agent event types.
    #
    # Each method returns a fully populated +Event+ instance. All events use
    # +source: "agent_desk"+ and default +timestamp: Time.now+.
    #
    # @example
    #   event = AgentDesk::MessageBus::Events.response_chunk(
    #     agent_id: "qa",
    #     task_id:  "t-1",
    #     content:  "Hello, world!"
    #   )
    module Events
      # A streaming response chunk from the LLM.
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param content [String] text chunk content
      # @return [Event]
      def self.response_chunk(agent_id:, task_id:, content:)
        Event.new(
          type:     "response.chunk",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { content: content }
        )
      end

      # The LLM has finished responding (non-streaming or final chunk).
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param usage [Hash] token usage stats (default: +{}+)
      # @return [Event]
      def self.response_complete(agent_id:, task_id:, usage: {})
        Event.new(
          type:     "response.complete",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { usage: usage }
        )
      end

      # A tool has been called by the agent.
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param tool_name [String] fully-qualified tool name (e.g., +"power---bash"+)
      # @param arguments [Hash] parsed tool arguments (default: +{}+)
      # @return [Event]
      def self.tool_called(agent_id:, task_id:, tool_name:, arguments: {})
        Event.new(
          type:     "tool.called",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { tool_name: tool_name, arguments: arguments }
        )
      end

      # A tool has returned a result.
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param tool_name [String] fully-qualified tool name
      # @param result [String] the tool's result string
      # @return [Event]
      def self.tool_result(agent_id:, task_id:, tool_name:, result:)
        Event.new(
          type:     "tool.result",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { tool_name: tool_name, result: result }
        )
      end

      # An agent session has started.
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param profile_name [String] agent profile name
      # @return [Event]
      def self.agent_started(agent_id:, task_id:, profile_name:)
        Event.new(
          type:     "agent.started",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { profile_name: profile_name }
        )
      end

      # An agent session has completed.
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param iterations [Integer] number of LLM iterations performed
      # @return [Event]
      def self.agent_completed(agent_id:, task_id:, iterations:)
        Event.new(
          type:     "agent.completed",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { iterations: iterations }
        )
      end

      # An approval request has been raised for a tool call.
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param tool_name [String] fully-qualified tool name awaiting approval
      # @return [Event]
      def self.approval_request(agent_id:, task_id:, tool_name:)
        Event.new(
          type:     "approval.request",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { tool_name: tool_name }
        )
      end

      # An approval decision has been made.
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param tool_name [String] fully-qualified tool name
      # @param approved [Boolean] whether the tool call was approved
      # @return [Event]
      def self.approval_response(agent_id:, task_id:, tool_name:, approved:)
        Event.new(
          type:     "approval.response",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { tool_name: tool_name, approved: approved }
        )
      end

      # The conversation has been compacted by a {Agent::CompactStrategy}.
      #
      # Published after the conversation messages are replaced with the compacted form.
      # Consumers can use +messages_removed+ and +summary_length+ to track compaction
      # efficiency over time.
      #
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param messages_removed [Integer] number of conversation messages removed during compaction
      # @param summary_length [Integer] length of the LLM-generated summary in characters
      # @return [Event]
      def self.conversation_compacted(agent_id:, task_id:, messages_removed:, summary_length:)
        Event.new(
          type:     "conversation.compacted",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { messages_removed: messages_removed, summary_length: summary_length }
        )
      end

      # A handoff task has been created by a {Agent::HandoffStrategy}.
      #
      # Published after the handoff task is created and the +on_handoff_created+
      # hook has fired. Consumers (e.g. Legion WorkflowEngine) can subscribe
      # to this event to route the new task through their orchestration pipeline.
      #
      # @param agent_id [String] agent identifier for the current (stopping) agent
      # @param task_id [String] task identifier for the current (stopping) task
      # @param new_task_id [String] UUID assigned to the new handoff task
      # @param prompt_excerpt [String] first 200 characters of the continuation prompt
      # @return [Event]
      def self.conversation_handoff(agent_id:, task_id:, new_task_id:, prompt_excerpt:)
        Event.new(
          type:     "conversation.handoff",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { new_task_id: new_task_id, prompt_excerpt: prompt_excerpt }
        )
      end

      # A token budget threshold tier has been crossed.
      #
      # Published by the runner's +check_compaction+ method before invoking a
      # compaction strategy. Subscribers can use this event to monitor context
      # window health across all running agents.
      #
      # @param agent_id [String] agent identifier
      # @param task_id [String] task identifier
      # @param tier [Symbol, nil] the threshold tier crossed (e.g. +:threshold+, +:tier_1+)
      # @param usage_percentage [Float] percentage of context window consumed
      # @param remaining_tokens [Integer] tokens remaining before the context limit
      # @return [Event]
      def self.token_budget_warning(agent_id:, task_id:, tier:, usage_percentage:, remaining_tokens:)
        Event.new(
          type:     "conversation.budget_warning",
          agent_id: agent_id,
          task_id:  task_id,
          payload:  { tier: tier, usage_percentage: usage_percentage, remaining_tokens: remaining_tokens }
        )
      end
    end
  end
end
