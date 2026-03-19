# frozen_string_literal: true

require "json"

module AgentDesk
  module Agent
    # Structured snapshot of the agent's in-flight state at the moment compaction
    # or handoff is triggered.
    #
    # Unlike a free-text summary, {StateSnapshot} captures structured data that
    # survives compaction even if the LLM summary omits details. It is passed to
    # compaction/handoff strategies and can be serialized to JSON for injection
    # into continuation prompts.
    #
    # All fields default to empty values so partial snapshots are valid — no
    # exception is raised when some state is unavailable.
    #
    # == Creating a snapshot
    #
    # Use the {.build} factory rather than constructing directly:
    #
    #   snapshot = StateSnapshot.build(
    #     original_prompt: "Implement feature X",
    #     conversation: conversation_array
    #   )
    #
    # == Serialization
    #
    #   json  = snapshot.to_json_str
    #   back  = StateSnapshot.from_json_str(json)
    #   back == snapshot  # => true
    #
    # @since 0.1.0
    StateSnapshot = Data.define(
      :original_prompt,         # String — the user's first prompt
      :todo_items,              # Array<Hash> — [{ name:, completed: }]
      :files_modified,          # Array<String>
      :files_in_context,        # Array<String>
      :key_decisions,           # Array<String>
      :memory_retrievals,       # Array<String>
      :tool_approvals_granted,  # Array<String>
      :current_step,            # String — what the agent was working on
      :remaining_work,          # String — pending items
      :custom_data              # Hash — extensible payload for hook consumers
    )

    class StateSnapshot
      # @!attribute [r] original_prompt
      #   @return [String] the user's original request (unchanged across compactions)

      # @!attribute [r] todo_items
      #   @return [Array<Hash>] todo list items with :name and :completed keys

      # @!attribute [r] files_modified
      #   @return [Array<String>] file paths created or changed during the run

      # @!attribute [r] files_in_context
      #   @return [Array<String>] context files currently loaded by the agent

      # @!attribute [r] key_decisions
      #   @return [Array<String>] architectural or implementation decisions made

      # @!attribute [r] memory_retrievals
      #   @return [Array<String>] memory entries already retrieved (avoids re-fetching)

      # @!attribute [r] tool_approvals_granted
      #   @return [Array<String>] tool names the user approved during this run

      # @!attribute [r] current_step
      #   @return [String] description of what the agent was doing when snapshotted

      # @!attribute [r] remaining_work
      #   @return [String] summary of pending work from todo items or conversation

      # @!attribute [r] custom_data
      #   @return [Hash] extensible payload for hook consumers to attach domain state

      # Builds a {StateSnapshot} from the current runner context.
      #
      # Parses the +conversation+ array on a best-effort basis to extract:
      # - todo items from tool-result messages
      # - file modifications from tool-result messages
      #
      # All keyword arguments in +opts+ are passed through directly and override
      # any values extracted from the conversation.
      #
      # @param original_prompt [String] the user's original request
      # @param conversation [Array<Hash>] the current conversation messages
      # @param opts [Hash] optional field overrides; keys match {StateSnapshot} fields
      # @return [StateSnapshot]
      def self.build(original_prompt:, conversation: [], **opts)
        extracted = extract_from_conversation(conversation)

        new(
          original_prompt:        original_prompt,
          todo_items:             opts.fetch(:todo_items, extracted[:todo_items]),
          files_modified:         opts.fetch(:files_modified, extracted[:files_modified]),
          files_in_context:       opts.fetch(:files_in_context, []),
          key_decisions:          opts.fetch(:key_decisions, []),
          memory_retrievals:      opts.fetch(:memory_retrievals, []),
          tool_approvals_granted: opts.fetch(:tool_approvals_granted, []),
          current_step:           opts.fetch(:current_step, ""),
          remaining_work:         opts.fetch(:remaining_work, ""),
          custom_data:            opts.fetch(:custom_data, {})
        )
      end

      # Deserializes a {StateSnapshot} from a JSON string.
      #
      # @param str [String] JSON string produced by {#to_json_str}
      # @return [StateSnapshot]
      # @raise [JSON::ParserError] if +str+ is not valid JSON
      def self.from_json_str(str)
        data = JSON.parse(str, symbolize_names: true)
        new(
          original_prompt:        data.fetch(:original_prompt, ""),
          todo_items:             data.fetch(:todo_items, []),
          files_modified:         data.fetch(:files_modified, []),
          files_in_context:       data.fetch(:files_in_context, []),
          key_decisions:          data.fetch(:key_decisions, []),
          memory_retrievals:      data.fetch(:memory_retrievals, []),
          tool_approvals_granted: data.fetch(:tool_approvals_granted, []),
          current_step:           data.fetch(:current_step, ""),
          remaining_work:         data.fetch(:remaining_work, ""),
          custom_data:            data.fetch(:custom_data, {})
        )
      end

      # Serializes this snapshot to a JSON string.
      #
      # Serialization is designed to be fast: < 10ms for a snapshot with a
      # 100-item todo list.
      #
      # @return [String] JSON representation of this snapshot
      def to_json_str
        JSON.generate(to_h)
      end

      # Returns a conversation message (in OpenAI format) containing a
      # human-readable rendering of the snapshot.
      #
      # The message uses the +assistant+ role so it fits naturally into a
      # compacted conversation without requiring a new user turn.
      #
      # @return [Hash] message hash with +:role+ and +:content+ keys
      def to_context_message
        {
          role: "assistant",
          content: render_as_text
        }
      end

      private

      # Extracts best-effort state from conversation messages.
      #
      # @param conversation [Array<Hash>] conversation messages
      # @return [Hash] with :todo_items and :files_modified keys
      def self.extract_from_conversation(conversation)
        todo_items = []
        files_modified = []

        (conversation || []).each do |msg|
          content = msg[:content].to_s
          # Detect file write results by common tool result patterns
          if msg[:role] == "tool" && (content.include?("written") || content.include?("created") || content.include?("saved"))
            # Try to extract file path from result content
            if (m = content.match(/[`'"]([^`'"]+\.\w+)[`'"]/))
              files_modified << m[1]
            end
          end
        end

        files_modified.uniq!

        { todo_items: todo_items, files_modified: files_modified }
      end
      private_class_method :extract_from_conversation

      # Renders the snapshot as a structured text block for embedding in prompts.
      #
      # @return [String]
      def render_as_text
        lines = [ "## State Snapshot" ]

        lines << "\n### Original Request\n#{original_prompt}" unless original_prompt.to_s.empty?
        lines << "\n### Current Step\n#{current_step}" unless current_step.to_s.empty?
        lines << "\n### Remaining Work\n#{remaining_work}" unless remaining_work.to_s.empty?

        unless todo_items.empty?
          lines << "\n### Todo Items"
          todo_items.each do |item|
            check = item[:completed] || item["completed"] ? "x" : " "
            name = item[:name] || item["name"] || item.to_s
            lines << "- [#{check}] #{name}"
          end
        end

        unless files_modified.empty?
          lines << "\n### Files Modified"
          files_modified.each { |f| lines << "- #{f}" }
        end

        unless files_in_context.empty?
          lines << "\n### Files In Context"
          files_in_context.each { |f| lines << "- #{f}" }
        end

        unless memory_retrievals.empty?
          lines << "\n### Memory Retrievals (already fetched)"
          memory_retrievals.each { |m| lines << "- #{m}" }
        end

        unless key_decisions.empty?
          lines << "\n### Key Decisions"
          key_decisions.each { |d| lines << "- #{d}" }
        end

        unless tool_approvals_granted.empty?
          lines << "\n### Tool Approvals Granted"
          tool_approvals_granted.each { |t| lines << "- #{t}" }
        end

        lines.join("\n")
      end
    end
  end
end
