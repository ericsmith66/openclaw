# frozen_string_literal: true

module AgentDesk
  module Agent
    # Core agent execution loop.
    #
    # Runner sends a user prompt to an LLM, processes any tool calls the LLM
    # returns, appends results to the conversation, and loops until the LLM
    # produces a text-only response or {max_iterations} is reached.
    #
    # All LLM communication is delegated to +model_manager+. Runner contains no
    # provider-specific code.
    #
    # @example Basic usage (no tools, no bus)
    #   runner = AgentDesk::Agent::Runner.new(model_manager: manager)
    #   conversation = runner.run(prompt: "Hello", project_dir: Dir.pwd)
    #   puts conversation.last[:content]
    #
    # @example With tools and event bus
    #   runner = AgentDesk::Agent::Runner.new(
    #     model_manager: manager,
    #     message_bus:   bus,
    #     hook_manager:  hooks,
    #     approval_manager: approvals
    #   )
    #   conversation = runner.run(
    #     prompt:   "List Ruby files",
    #     project_dir: Dir.pwd,
    #     tool_set: my_tool_set,
    #     agent_id: "dev-agent",
    #     task_id:  "task-001"
    #   )
    class Runner
      # Default maximum number of LLM iterations per run.
      DEFAULT_MAX_ITERATIONS = 250

      # @!attribute [r] model_manager
      #   @return [#chat] the LLM client (ModelManager or MockModelManager)
      attr_reader :model_manager

      # @!attribute [r] message_bus
      #   @return [MessageBus::MessageBusInterface, nil] optional event bus
      attr_reader :message_bus

      # @!attribute [r] hook_manager
      #   @return [Hooks::HookManager, nil] optional lifecycle hook manager
      attr_reader :hook_manager

      # @!attribute [r] approval_manager
      #   @return [Tools::ApprovalManager, nil] optional tool approval manager
      attr_reader :approval_manager

      # @!attribute [r] token_budget_tracker
      #   @return [TokenBudgetTracker, nil] optional token/cost budget tracker
      attr_reader :token_budget_tracker

      # @!attribute [r] usage_logger
      #   @return [UsageLogger::NullLogger, UsageLogger::JsonLogger, nil] optional usage logger
      attr_reader :usage_logger

      # @!attribute [r] compaction_strategy
      #   @return [Symbol, #execute, nil] compaction strategy; one of +:compact+,
      #     +:handoff+, +:tiered+, or a strategy object responding to +#execute+.
      #     When nil, no compaction is performed even if a budget tracker is configured.
      attr_reader :compaction_strategy

      # Creates a new Runner.
      #
      # @param model_manager [#chat] required LLM client
      # @param message_bus [MessageBus::MessageBusInterface, nil] optional event bus;
      #   when nil, no events are published (zero overhead)
      # @param hook_manager [Hooks::HookManager, nil] optional hook manager;
      #   when nil, all lifecycle hooks are skipped
      # @param approval_manager [Tools::ApprovalManager, nil] optional approval manager;
      #   when nil, all tool executions are auto-approved
      # @param token_budget_tracker [TokenBudgetTracker, nil] optional budget tracker;
      #   when set, {#run} records usage after each LLM response and publishes
      #   +usage_recorded+ events with the current threshold tier
      # @param usage_logger [UsageLogger::NullLogger, UsageLogger::JsonLogger, nil]
      #   optional usage logger; when set, each LLM response's usage data is persisted
      # @param compaction_strategy [Symbol, #execute, nil] compaction strategy;
      #   one of +:compact+, +:handoff+, +:tiered+, or a strategy object. When nil,
      #   no compaction is performed even if +token_budget_tracker+ is set.
      def initialize(
        model_manager:,
        message_bus: nil,
        hook_manager: nil,
        approval_manager: nil,
        token_budget_tracker: nil,
        usage_logger: nil,
        compaction_strategy: nil
      )
        @model_manager        = model_manager
        @message_bus          = message_bus
        @hook_manager         = hook_manager
        @approval_manager     = approval_manager
        @token_budget_tracker = token_budget_tracker
        @usage_logger         = usage_logger
        # Resolve symbol strategies to objects at construction time so that
        # stateful strategies (e.g. TieredStrategy) retain their state across
        # iterations within a single run.
        @compaction_strategy  = resolve_strategy(compaction_strategy)
      end

      # Runs the agent execution loop.
      #
      # Builds an initial conversation from +prompt+ and optional +system_prompt+,
      # then sends messages to the LLM repeatedly until a text-only response is
      # received or +max_iterations+ is exhausted. Tool calls from the LLM are
      # executed, and results are appended to the conversation before the next
      # iteration.
      #
      # @param prompt [String] the user's initial prompt
      # @param project_dir [String] working directory passed to tool context
      # @param profile [Object, nil] reserved for future profile integration (PRD-0040)
      # @param messages [Array<Hash>, nil] pre-seeded conversation messages (prepended before prompt)
      # @param system_prompt [String, nil] system message prepended to the conversation
      # @param tool_set [Tools::ToolSet, nil] tools available to the LLM
      # @param max_iterations [Integer] maximum LLM call iterations (default: 250)
      # @param on_message [Proc, nil] callback invoked for each assistant/tool message added
      # @param agent_id [String, nil] agent identifier for event publishing
      # @param task_id [String, nil] task identifier for event publishing
      # @return [Array<Hash>] the full conversation in OpenAI message format
      def run(
        prompt:,
        project_dir:,
        profile: nil,
        messages: nil,
        system_prompt: nil,
        tool_set: nil,
        max_iterations: DEFAULT_MAX_ITERATIONS,
        on_message: nil,
        agent_id: nil,
        task_id: nil
      )
        # Reset per-run state on reusable strategy objects (e.g. TieredStrategy#reset).
        @compaction_strategy.reset if @compaction_strategy.respond_to?(:reset)

        conversation = build_conversation(prompt, messages, system_prompt)
        resolved_tool_set = build_tool_set(profile, tool_set)
        tool_defs = tool_definitions(resolved_tool_set)
        context = { project_dir: project_dir }

        profile_name = profile.respond_to?(:name) ? profile.name : "default"
        publish(MessageBus::Events.agent_started(
          agent_id: agent_id,
          task_id: task_id,
          profile_name: profile_name
        ))

        hook_result = trigger_hook(:on_agent_started, { prompt: prompt }, context)
        return conversation if hook_result&.blocked

        iteration = 0

        loop do
          break if iteration >= max_iterations

          iteration += 1

          response = @model_manager.chat(messages: conversation, tools: tool_defs) do |chunk|
            publish(MessageBus::Events.response_chunk(
              agent_id: agent_id,
              task_id: task_id,
              content: chunk[:content].to_s
            ))
          end

          publish(MessageBus::Events.response_complete(
            agent_id: agent_id,
            task_id: task_id,
            usage: response[:usage] || {}
          ))

          record_budget_usage(response[:usage], agent_id: agent_id, task_id: task_id)

          compaction_signal = check_compaction(
            conversation:    conversation,
            agent_id:        agent_id,
            task_id:         task_id,
            original_prompt: prompt,
            context:         context
          )
          break if compaction_signal == :stop

          if response[:tool_calls]&.any?
            assistant_msg = {
              role: "assistant",
              tool_calls: response[:tool_calls]
            }
            # Only include content if present; newer Claude models return nil
            # content for tool-use responses, and Anthropic rejects null content.
            assistant_msg[:content] = response[:content] if response[:content]
            # Preserve reasoning_content for models that require it (e.g., deepseek-reasoner).
            assistant_msg[:reasoning_content] = response[:reasoning_content] if response.key?(:reasoning_content)
            conversation << assistant_msg
            on_message&.call(assistant_msg)

            execute_tool_calls(
              response[:tool_calls],
              resolved_tool_set,
              conversation,
              context,
              on_message,
              agent_id,
              task_id
            )
          else
            final_msg = { role: "assistant", content: response[:content] }
            conversation << final_msg
            on_message&.call(final_msg)

            publish(MessageBus::Events.agent_completed(
              agent_id: agent_id,
              task_id: task_id,
              iterations: iteration
            ))
            break
          end
        end

        # Also publish agent.completed when max_iterations is exhausted
        if iteration >= max_iterations
          publish(MessageBus::Events.agent_completed(
            agent_id: agent_id,
            task_id: task_id,
            iterations: iteration
          ))
        end

        conversation
      end

      private

      # Builds the initial conversation array.
      #
      # @param prompt [String] user prompt
      # @param messages [Array<Hash>, nil] pre-seeded messages
      # @param system_prompt [String, nil] optional system message
      # @return [Array<Hash>] conversation messages
      def build_conversation(prompt, messages, system_prompt)
        conversation = []
        conversation << { role: "system", content: system_prompt } if system_prompt
        conversation.concat(messages) if messages&.any?
        conversation << { role: "user", content: prompt }
        conversation
      end

      # Resolves a ToolSet from profile or direct argument.
      #
      # For M1, callers pass +tool_set+ directly. Profile-based building
      # is reserved for PRD-0040.
      #
      # @param _profile [Object, nil] reserved (unused in M1)
      # @param tool_set [Tools::ToolSet, nil] explicit tool set
      # @return [Tools::ToolSet, nil]
      def build_tool_set(_profile, tool_set)
        tool_set
      end

      # Serializes a ToolSet to OpenAI-compatible function definition array.
      #
      # Wraps each BaseTool definition in the +{ type: "function", function: ... }+
      # envelope required by the OpenAI function-calling API. BaseTool remains
      # provider-agnostic; this wrapping is the Runner's responsibility.
      #
      # @param tool_set [Tools::ToolSet, nil] the tool set to serialize
      # @return [Array<Hash>, nil] array of OpenAI function definitions, or nil
      def tool_definitions(tool_set)
        return nil if tool_set.nil? || tool_set.size.zero?

        tool_set.to_function_definitions.map do |defn|
          { type: "function", function: defn }
        end
      end

      # Iterates tool calls from the LLM response, executes each, and appends
      # results to the conversation.
      #
      # @param tool_calls [Array<Hash>] normalized tool_calls from ModelManager
      # @param tool_set [Tools::ToolSet, nil] available tools
      # @param conversation [Array<Hash>] conversation to append results to
      # @param context [Hash] execution context (e.g., project_dir)
      # @param on_message [Proc, nil] message callback
      # @param agent_id [String, nil] for event publishing
      # @param task_id [String, nil] for event publishing
      # @return [void]
      def execute_tool_calls(tool_calls, tool_set, conversation, context, on_message, agent_id, task_id)
        tool_calls.each do |tool_call|
          tool_name = tool_call.dig(:function, :name)
          arguments = tool_call.dig(:function, :arguments) || {}
          tool_call_id = tool_call[:id]

          publish(MessageBus::Events.tool_called(
            agent_id: agent_id,
            task_id: task_id,
            tool_name: tool_name,
            arguments: arguments
          ))

          result = execute_single_tool(tool_call, tool_set, context)

          publish(MessageBus::Events.tool_result(
            agent_id: agent_id,
            task_id: task_id,
            tool_name: tool_name,
            result: result
          ))

          tool_result_msg = {
            role: "tool",
            tool_call_id: tool_call_id,
            content: result
          }
          conversation << tool_result_msg
          on_message&.call(tool_result_msg)
        end
      end

      # Looks up, validates, and executes a single tool call.
      #
      # @param tool_call [Hash] normalized tool call with :id, :function keys
      # @param tool_set [Tools::ToolSet, nil] available tools
      # @param context [Hash] execution context
      # @return [String] result string (or error message)
      def execute_single_tool(tool_call, tool_set, context)
        tool_name = tool_call.dig(:function, :name)
        arguments = tool_call.dig(:function, :arguments) || {}

        tool = tool_set&.[](tool_name)
        unless tool
          return missing_tool_error(tool_name, tool_set)
        end

        hook_result = trigger_hook(:on_tool_called, { tool_name: tool_name, arguments: arguments }, context)
        return "Tool execution blocked" if hook_result&.blocked

        if @approval_manager
          approved, reason = @approval_manager.check_approval(
            tool_name,
            text: "Execute #{tool_name} with #{arguments}",
            subject: tool_name
          )
          return "Tool execution denied: #{reason}" unless approved
        end

        result = tool.execute(arguments, context: context).to_s
        trigger_hook(:on_tool_finished, { tool_name: tool_name, result: result }, context)
        result
      rescue StandardError => e
        "Tool error: #{e.message}"
      end

      # Formats a helpful error message for a missing tool.
      #
      # @param name [String] the requested tool name that was not found
      # @param tool_set [Tools::ToolSet, nil] the available tool set
      # @return [String] error message listing available tools
      def missing_tool_error(name, tool_set)
        available = tool_set&.map(&:full_name)&.join(", ") || "(none)"
        "Tool '#{name}' not found. Available tools: #{available}"
      end

      # Publishes an event to the message bus if one is configured.
      #
      # Uses nil-safe invocation: zero overhead when +@message_bus+ is nil.
      #
      # @param event [MessageBus::Event] the event to publish
      # @return [void]
      def publish(event)
        @message_bus&.publish(event.type, event)
      end

      # Triggers a lifecycle hook on the hook manager if one is configured.
      #
      # @param event [Symbol] hook event name (e.g., +:on_agent_started+)
      # @param event_data [Hash] initial event data
      # @param context [Hash] execution context
      # @return [Hooks::HookResult, nil] hook result, or nil when no manager
      def trigger_hook(event, event_data = {}, context = {})
        @hook_manager&.trigger(event, event_data, context)
      end

      # Records token/cost usage from the LLM response into the optional
      # {TokenBudgetTracker} and {UsageLogger}, then publishes a +usage_recorded+
      # event via the message bus.
      #
      # This method is a *reporting-only* integration point — it never modifies
      # the conversation or triggers compaction (that is PRD-0092b's responsibility).
      #
      # When +@token_budget_tracker+ is nil the method is a no-op.
      #
      # @param usage [Hash, nil] usage hash from the LLM response; expected keys:
      #   +:prompt_tokens+, +:completion_tokens+, +:cache_read_tokens+,
      #   +:cache_write_tokens+, +:message_cost+
      # @param agent_id [String, nil] for event publishing
      # @param task_id [String, nil] for event publishing
      # @return [void]
      def record_budget_usage(usage, agent_id:, task_id:)
        return unless @token_budget_tracker

        u = usage || {}

        @token_budget_tracker.record(
          sent_tokens:        u[:prompt_tokens],
          received_tokens:    u[:completion_tokens],
          cache_read_tokens:  u[:cache_read_tokens],
          cache_write_tokens: u[:cache_write_tokens],
          message_cost:       u[:message_cost]
        )

        log_data = u.merge(
          cumulative_cost: @token_budget_tracker.cumulative_cost,
          threshold_tier:  @token_budget_tracker.threshold_tier
        )
        @usage_logger&.log(log_data)

        publish(MessageBus::Events::Event.new(
          type:    "usage_recorded",
          payload: {
            agent_id:         agent_id,
            task_id:          task_id,
            prompt_tokens:    u[:prompt_tokens],
            completion_tokens: u[:completion_tokens],
            cumulative_cost:  @token_budget_tracker.cumulative_cost,
            remaining_tokens: @token_budget_tracker.remaining_tokens,
            threshold_tier:   @token_budget_tracker.threshold_tier
          }
        ))
      end

      # Checks the token budget and cost budget after each LLM response, and
      # invokes the configured compaction strategy if a threshold is crossed.
      #
      # This is the integration point for PRD-0092b. It runs immediately after
      # {#record_budget_usage} in the runner loop.
      #
      # Cost budget check (independent of token threshold):
      # 1. If cost is exceeded, fire +on_cost_budget_exceeded+ hook.
      # 2. Unless the hook blocks the halt, return +:stop+.
      #
      # Token threshold check:
      # 1. If a threshold tier is crossed, build a {StateSnapshot}.
      # 2. Fire +on_token_budget_warning+ hook.
      # 3. Unless the hook blocks default compaction, execute the strategy.
      # 4. Return the strategy's signal (+:continue+ or +:stop+).
      #
      # When +@token_budget_tracker+ is nil or +@compaction_strategy+ is nil,
      # returns +:continue+ immediately (zero overhead).
      #
      # Hook handler errors are rescued individually so a broken hook cannot
      # crash the runner loop.
      #
      # @param conversation [Array<Hash>] current conversation; may be modified in place
      # @param agent_id [String, nil] for event publishing
      # @param task_id [String, nil] for event publishing
      # @param original_prompt [String] the user's first prompt (for snapshot)
      # @param context [Hash] execution context (e.g. project_dir)
      # @return [:continue, :stop]
      def check_compaction(conversation:, agent_id:, task_id:, original_prompt:, context:)
        return :continue unless @token_budget_tracker && @compaction_strategy

        # --- Cost budget check ---
        if @token_budget_tracker.cost_exceeded?
          cost_hook_result = safe_trigger_hook(
            :on_cost_budget_exceeded,
            {
              cumulative_cost:    @token_budget_tracker.cumulative_cost,
              cost_budget:        @token_budget_tracker.cost_budget,
              last_message_cost:  @token_budget_tracker.last_message_cost
            },
            context
          )
          return :stop unless cost_hook_result&.blocked
        end

        # --- Token threshold check ---
        tier = @token_budget_tracker.threshold_tier
        return :continue if tier.nil?

        snapshot = StateSnapshot.build(
          original_prompt: original_prompt,
          conversation:    conversation
        )

        enriched_context = context.merge(threshold_tier: tier)

        publish(MessageBus::Events.token_budget_warning(
          agent_id:         agent_id,
          task_id:          task_id,
          tier:             tier,
          usage_percentage: @token_budget_tracker.usage_percentage,
          remaining_tokens: @token_budget_tracker.remaining_tokens
        ))

        warning_hook_result = safe_trigger_hook(
          :on_token_budget_warning,
          {
            tier:                 tier,
            usage_percentage:     @token_budget_tracker.usage_percentage,
            remaining_tokens:     @token_budget_tracker.remaining_tokens,
            state_snapshot:       snapshot,
            cumulative_cost:      @token_budget_tracker.cumulative_cost,
            last_message_cost:    @token_budget_tracker.last_message_cost,
            cost_budget:          @token_budget_tracker.cost_budget,
            cost_budget_exceeded: @token_budget_tracker.cost_exceeded?
          },
          context
        )
        # If hook blocks, consumer handles compaction — skip default strategy
        return :continue if warning_hook_result&.blocked

        @compaction_strategy.execute(
          context:        enriched_context,
          conversation:   conversation,
          state_snapshot: snapshot,
          model_manager:  @model_manager,
          hook_manager:   @hook_manager,
          message_bus:    @message_bus,
          agent_id:       agent_id,
          task_id:        task_id
        )
      end

      # Triggers a lifecycle hook with rescue so that a broken hook handler
      # cannot crash the runner loop.
      #
      # On +StandardError+: logs via +warn+ and returns +nil+ (non-blocking).
      #
      # @param event [Symbol] hook event name
      # @param event_data [Hash] event data
      # @param context [Hash] execution context
      # @return [Hooks::HookResult, nil]
      def safe_trigger_hook(event, event_data = {}, context = {})
        trigger_hook(event, event_data, context)
      rescue StandardError => e
        warn "[AgentDesk] Runner: hook '#{event}' raised — #{e.message}. Treating as non-blocking."
        nil
      end

      # Resolves a compaction strategy symbol or object to an executable strategy.
      #
      # @param strategy [Symbol, #execute] the strategy to resolve
      # @return [#execute] a strategy object
      def resolve_strategy(strategy)
        case strategy
        when :compact  then CompactStrategy.new
        when :handoff  then HandoffStrategy.new
        when :tiered   then TieredStrategy.new
        else
          # Duck-typed strategy object
          strategy
        end
      end
    end
  end
end
