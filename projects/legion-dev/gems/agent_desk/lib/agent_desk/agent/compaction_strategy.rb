# frozen_string_literal: true

require "set"
require "securerandom"

module AgentDesk
  module Agent
    # Compact a conversation by summarizing it via an LLM call.
    #
    # Mirrors AiderDesk's +ContextCompactionType.Compact+ behaviour:
    # sends the full conversation to the LLM with a summarisation prompt,
    # replaces all messages in place with a four-message compacted form,
    # and signals the runner to continue.
    #
    # On LLM failure: logs a warning and leaves the conversation untouched,
    # returning +:continue+ so the runner degrades gracefully.
    #
    # @since 0.1.0
    class CompactStrategy
      # System prompt used for the tool-less summarisation call.
      COMPACT_SYSTEM_PROMPT = <<~PROMPT.freeze
        You are a conversation compactor. Your job is to summarize a long
        agent conversation into a concise, structured summary that preserves:
        - All decisions and rationale
        - All file paths mentioned
        - Current task state and what remains to be done
        - Any errors encountered and how they were resolved

        Produce a clear, well-organized summary. Be comprehensive but concise.
      PROMPT

      # Executes the compact strategy.
      #
      # Sends the conversation to the LLM for summarisation, then replaces all
      # messages in the +conversation+ array in place with a four-message
      # compacted form:
      # 1. Original user message (role: "user")
      # 2. State snapshot context (role: "assistant")
      # 3. LLM-generated summary (role: "assistant")
      # 4. Continuation instruction (role: "user")
      #
      # @param context [Hash] runner context (unused in M1, reserved for future use)
      # @param conversation [Array<Hash>] the current conversation; modified in place
      # @param state_snapshot [StateSnapshot] structured state at the time of compaction
      # @param model_manager [#chat] LLM client for the summarisation call
      # @param hook_manager [Hooks::HookManager, nil] unused in compact; reserved
      # @param message_bus [MessageBus::MessageBusInterface, nil] event bus for publishing
      # @param agent_id [String, nil] agent identifier for event publishing
      # @param task_id [String, nil] task identifier for event publishing
      # @return [:continue] always signals the runner to continue
      def execute(
        context:,
        conversation:,
        state_snapshot:,
        model_manager:,
        hook_manager: nil,
        message_bus: nil,
        agent_id: nil,
        task_id: nil
      )
        original_token_count = conversation.size
        original_user_msg = first_user_message(conversation)

        compact_messages = build_compact_messages(conversation)

        response = model_manager.chat(messages: compact_messages, tools: nil)
        summary = response[:content].to_s

        # Replace conversation in-place: clear old messages, build compacted form
        conversation.clear
        conversation.concat(build_compacted_conversation(original_user_msg, state_snapshot, summary))

        messages_removed = [ original_token_count - conversation.size, 0 ].max

        publish_event(
          message_bus,
          MessageBus::Events.conversation_compacted(
            agent_id:         agent_id,
            task_id:          task_id,
            messages_removed: messages_removed,
            summary_length:   summary.length
          )
        )

        :continue
      rescue StandardError => e
        warn "[AgentDesk] CompactStrategy: LLM summarisation failed — #{e.message}. Continuing without compaction."
        :continue
      end

      private

      # Returns the first user message from the conversation, or a default.
      #
      # @param conversation [Array<Hash>]
      # @return [Hash] message hash
      def first_user_message(conversation)
        conversation.find { |m| m[:role] == "user" } ||
          { role: "user", content: "Continue the task." }
      end

      # Builds the message array for the summarisation LLM call.
      #
      # @param conversation [Array<Hash>]
      # @return [Array<Hash>]
      def build_compact_messages(conversation)
        [
          { role: "system", content: COMPACT_SYSTEM_PROMPT },
          *conversation,
          { role: "user", content: "Please summarize the conversation above into a structured compaction summary." }
        ]
      end

      # Builds the four-message compacted conversation.
      #
      # @param original_user_msg [Hash]
      # @param state_snapshot [StateSnapshot]
      # @param summary [String]
      # @return [Array<Hash>]
      def build_compacted_conversation(original_user_msg, state_snapshot, summary)
        [
          original_user_msg,
          state_snapshot.to_context_message,
          { role: "assistant", content: summary },
          { role: "user", content: "Please continue where you left off based on the summary and state above." }
        ]
      end

      # Publishes an event to the message bus if one is configured.
      #
      # @param message_bus [MessageBus::MessageBusInterface, nil]
      # @param event [MessageBus::Event]
      # @return [void]
      def publish_event(message_bus, event)
        message_bus&.publish(event.type, event)
      end
    end

    # Creates a new task with a continuation prompt and signals the runner to stop.
    #
    # Mirrors AiderDesk's +ContextCompactionType.Handoff+ behaviour:
    # generates a continuation prompt via LLM, creates a handoff task hash,
    # fires the +on_handoff_created+ hook, publishes a MessageBus event,
    # and signals the runner to stop.
    #
    # On failure at any step: logs a warning and returns +:stop+ to avoid
    # leaving the runner in a bad state.
    #
    # @since 0.1.0
    class HandoffStrategy
      # System prompt used for the tool-less continuation-prompt generation call.
      HANDOFF_SYSTEM_PROMPT = <<~PROMPT.freeze
        You are a conversation handoff coordinator. Your job is to analyze a
        long agent conversation and generate a comprehensive continuation prompt
        for a new agent task.

        The continuation prompt must include:
        - A concise summary of what has been accomplished
        - The exact remaining work to be done
        - Any critical context (file paths, decisions, constraints)
        - The precise next step to take

        Write the prompt as if you are handing off to a fresh agent instance
        that has no knowledge of the previous conversation.
      PROMPT

      # Executes the handoff strategy.
      #
      # Generates a continuation prompt via LLM, wraps it with the serialized
      # {StateSnapshot}, creates a handoff task hash, fires the
      # +on_handoff_created+ hook (allowing hook consumers to intercept or
      # modify the handoff), publishes a MessageBus event, and returns +:stop+.
      #
      # @param context [Hash] runner context (unused in M1)
      # @param conversation [Array<Hash>] current conversation (read-only)
      # @param state_snapshot [StateSnapshot] structured state at the time of handoff
      # @param model_manager [#chat] LLM client for generating the continuation prompt
      # @param hook_manager [Hooks::HookManager, nil] optional hook manager
      # @param message_bus [MessageBus::MessageBusInterface, nil] optional event bus
      # @param agent_id [String, nil] agent identifier for event publishing
      # @param task_id [String, nil] task identifier for event publishing
      # @return [:stop] always signals the runner to stop
      def execute(
        context:,
        conversation:,
        state_snapshot:,
        model_manager:,
        hook_manager: nil,
        message_bus: nil,
        agent_id: nil,
        task_id: nil
      )
        handoff_messages = build_handoff_messages(conversation)
        response = model_manager.chat(messages: handoff_messages, tools: nil)
        continuation_prompt = response[:content].to_s

        snapshot_json = state_snapshot.to_json_str
        full_prompt = "#{snapshot_json}\n\n#{continuation_prompt}"

        new_task_id = SecureRandom.uuid
        context_files = context.is_a?(Hash) ? context.fetch(:files_in_context, []) : []

        handoff_task = {
          id:            new_task_id,
          prompt:        full_prompt,
          context_files: context_files
        }

        trigger_handoff_hook(hook_manager, handoff_task, state_snapshot, task_id)

        publish_event(
          message_bus,
          MessageBus::Events.conversation_handoff(
            agent_id:       agent_id,
            task_id:        task_id,
            new_task_id:    new_task_id,
            prompt_excerpt: continuation_prompt.to_s[0, 200]
          )
        )

        :stop
      rescue StandardError => e
        warn "[AgentDesk] HandoffStrategy: failed — #{e.message}. Signalling stop to avoid bad state."
        :stop
      end

      private

      # Builds messages for the continuation-prompt generation LLM call.
      #
      # @param conversation [Array<Hash>]
      # @return [Array<Hash>]
      def build_handoff_messages(conversation)
        [
          { role: "system", content: HANDOFF_SYSTEM_PROMPT },
          *conversation,
          { role: "user", content: "Generate a continuation prompt for a new agent task based on the conversation above." }
        ]
      end

      # Fires the +on_handoff_created+ hook if a hook manager is provided.
      #
      # @param hook_manager [Hooks::HookManager, nil]
      # @param handoff_task [Hash]
      # @param state_snapshot [StateSnapshot]
      # @param original_task_id [String, nil]
      # @return [void]
      def trigger_handoff_hook(hook_manager, handoff_task, state_snapshot, original_task_id)
        return unless hook_manager

        hook_manager.trigger(
          :on_handoff_created,
          {
            original_task_id: original_task_id,
            new_task_id:      handoff_task[:id],
            handoff_prompt:   handoff_task[:prompt],
            state_snapshot:   state_snapshot,
            context_files:    handoff_task[:context_files]
          }
        )
      end

      # Publishes an event to the message bus if one is configured.
      #
      # @param message_bus [MessageBus::MessageBusInterface, nil]
      # @param event [MessageBus::Event]
      # @return [void]
      def publish_event(message_bus, event)
        message_bus&.publish(event.type, event)
      end
    end

    # Applies progressive compaction based on the current threshold tier.
    #
    # Provides three tiers of compaction, from least to most aggressive:
    #
    # - *Tier 1* (+:tier_1+): Trim verbose tool results in older messages (no LLM call).
    # - *Tier 2* (+:tier_2+): Summarize older messages, preserve the most recent.
    # - *Tier 3* (+:tier_3+): Delegate to {CompactStrategy} or {HandoffStrategy}.
    #
    # Each tier is only triggered once per run. Call {#reset} at the start of
    # each +Runner#run+ invocation to clear per-run state.
    #
    # @since 0.1.0
    class TieredStrategy
      # Number of recent messages to preserve in tier-2 compaction.
      RECENT_MESSAGES_TO_KEEP = 10

      # Maximum length of a tool result before it is trimmed in tier 1.
      TIER1_MAX_RESULT_LENGTH = 500

      # Creates a new TieredStrategy.
      #
      # @param tier3_strategy [Symbol] strategy to use at tier 3; +:compact+ or +:handoff+ (default: +:compact+)
      def initialize(tier3_strategy: :compact)
        @tier3_strategy = tier3_strategy
        @handled_tiers = Set.new
      end

      # Resets per-run state.
      #
      # Must be called at the start of each +Runner#run+ invocation when the
      # strategy instance is reused across runs. Clears the set of already-handled
      # tiers so tier actions are not silently skipped.
      #
      # @return [self]
      def reset
        @handled_tiers = Set.new
        self
      end

      # Executes the tiered compaction strategy for the current threshold tier.
      #
      # @param context [Hash] runner context
      # @param conversation [Array<Hash>] current conversation; may be modified in place
      # @param state_snapshot [StateSnapshot] structured state at snapshot time
      # @param model_manager [#chat] LLM client
      # @param hook_manager [Hooks::HookManager, nil] optional hook manager
      # @param message_bus [MessageBus::MessageBusInterface, nil] optional event bus
      # @param agent_id [String, nil] agent identifier for event publishing
      # @param task_id [String, nil] task identifier for event publishing
      # @return [:continue, :stop] +:continue+ for tiers 1/2; tier-3 strategy result for tier 3
      def execute(
        context:,
        conversation:,
        state_snapshot:,
        model_manager:,
        hook_manager: nil,
        message_bus: nil,
        agent_id: nil,
        task_id: nil
      )
        tier = state_snapshot_tier(state_snapshot, context)
        return :continue if tier.nil?
        return :continue if @handled_tiers.include?(tier)

        case tier
        when :tier_1
          apply_tier1(conversation)
          @handled_tiers.add(:tier_1)
          :continue
        when :tier_2
          apply_tier2(conversation, model_manager)
          @handled_tiers.add(:tier_2)
          :continue
        when :tier_3
          @handled_tiers.add(:tier_3)
          delegate_tier3(
            context:         context,
            conversation:    conversation,
            state_snapshot:  state_snapshot,
            model_manager:   model_manager,
            hook_manager:    hook_manager,
            message_bus:     message_bus,
            agent_id:        agent_id,
            task_id:         task_id
          )
        else
          :continue
        end
      end

      private

      # Extracts the threshold tier from context (passed from runner).
      #
      # @param _state_snapshot [StateSnapshot] unused; tier comes from context
      # @param context [Hash]
      # @return [Symbol, nil]
      def state_snapshot_tier(_state_snapshot, context)
        context.is_a?(Hash) ? context[:threshold_tier] : nil
      end

      # Tier 1: trim verbose tool results in older messages (no LLM call).
      #
      # Messages within the last {RECENT_MESSAGES_TO_KEEP} are left intact.
      # Tool-role messages earlier than that have their content truncated to
      # {TIER1_MAX_RESULT_LENGTH} characters.
      #
      # @param conversation [Array<Hash>] modified in place
      # @return [void]
      def apply_tier1(conversation)
        return if conversation.size <= RECENT_MESSAGES_TO_KEEP

        older_messages = conversation[0..-(RECENT_MESSAGES_TO_KEEP + 1)]
        older_messages.each do |msg|
          next unless msg[:role] == "tool"
          next unless msg[:content].is_a?(String) && msg[:content].length > TIER1_MAX_RESULT_LENGTH

          msg[:content] = "#{msg[:content][0, TIER1_MAX_RESULT_LENGTH]}... [trimmed by TieredStrategy tier-1]"
        end
      end

      # Tier 2: summarize older messages, keep recent ones intact.
      #
      # Builds a summary of messages older than {RECENT_MESSAGES_TO_KEEP} via an
      # LLM call, then replaces those older messages with a single summary message.
      # If the LLM call fails, a static fallback message is used.
      #
      # @param conversation [Array<Hash>] modified in place
      # @param model_manager [#chat] LLM client for summarization
      # @return [void]
      def apply_tier2(conversation, model_manager)
        return if conversation.size <= RECENT_MESSAGES_TO_KEEP

        split_idx = conversation.size - RECENT_MESSAGES_TO_KEEP
        older = conversation[0...split_idx]
        recent = conversation[split_idx..]

        summary_text = summarize_messages(older, model_manager)

        conversation.clear
        conversation << { role: "assistant", content: summary_text }
        conversation.concat(recent)
      rescue StandardError => e
        warn "[AgentDesk] TieredStrategy tier-2: summarization failed — #{e.message}. Leaving conversation unchanged."
      end

      # Summarizes a set of messages via an LLM call.
      #
      # @param messages [Array<Hash>]
      # @param model_manager [#chat]
      # @return [String] summary text
      def summarize_messages(messages, model_manager)
        summarize_prompt = [
          { role: "system", content: "Summarize the following agent conversation history concisely, preserving all important context, decisions, file paths, and progress." },
          *messages,
          { role: "user", content: "Provide a structured summary of the above conversation." }
        ]
        response = model_manager.chat(messages: summarize_prompt, tools: nil)
        response[:content].to_s
      rescue StandardError => e
        "[Tier-2 Compaction: summarization failed (#{e.message}). Older context may be incomplete.]"
      end

      # Delegates tier-3 handling to the configured sub-strategy.
      #
      # @param opts [Hash] full execute kwargs
      # @return [:continue, :stop]
      def delegate_tier3(**opts)
        strategy = case @tier3_strategy
        when :handoff then HandoffStrategy.new
        else CompactStrategy.new
        end
        strategy.execute(**opts)
      end
    end
  end
end
