# frozen_string_literal: true

# PRD-AH-013G: include `context_wrapper` in agent handoff callbacks so downstream
# instrumentation can attach stage payloads (e.g., Planner `plan_json`) to handoff artifacts.
#
# This is implemented as a monkeypatch via `Module#prepend` to avoid forking the `ai-agents` gem.
# Backwards compatibility: existing 3-arg blocks ignore the 4th arg.

require "agents/runner"

module Agents
  module RunnerHandoffContextPatch
    def run(starting_agent, input, context: {}, registry: {}, max_turns: DEFAULT_MAX_TURNS, headers: nil, callbacks: {})
      # This is copied from `ai-agents` with a single behavioral change:
      # we pass `context_wrapper` as a 4th argument to `emit_agent_handoff`.
      current_agent = starting_agent

      context_copy = deep_copy_context(context)
      context_wrapper = RunContext.new(context_copy, callbacks: callbacks)
      current_turn = 0

      context_wrapper.callback_manager.emit_run_start(current_agent.name, input, context_wrapper)

      runtime_headers = Helpers::Headers.normalize(headers)
      agent_headers = Helpers::Headers.normalize(current_agent.headers)

      chat = RubyLLM::Chat.new(model: current_agent.model)
      current_headers = Helpers::Headers.merge(agent_headers, runtime_headers)
      apply_headers(chat, current_headers)
      configure_chat_for_agent(chat, current_agent, context_wrapper, replace: false)
      restore_conversation_history(chat, context_wrapper)

      loop do
        current_turn += 1
        raise Runner::MaxTurnsExceeded, "Exceeded maximum turns: #{max_turns}" if current_turn > max_turns

        result = if current_turn == 1
          context_wrapper.callback_manager.emit_agent_thinking(current_agent.name, input)
          chat.ask(input)
        else
          context_wrapper.callback_manager.emit_agent_thinking(current_agent.name, "(continuing conversation)")
          chat.complete
        end
        response = result

        if response.is_a?(RubyLLM::Tool::Halt) && context_wrapper.context[:pending_handoff]
          handoff_info = context_wrapper.context.delete(:pending_handoff)
          next_agent = handoff_info[:target_agent]

          unless registry[next_agent.name]
            save_conversation_state(chat, context_wrapper, current_agent)
            error = Runner::AgentNotFoundError.new("Handoff failed: Agent '#{next_agent.name}' not found in registry")

            result = RunResult.new(
              output: nil,
              messages: Helpers::MessageExtractor.extract_messages(chat, current_agent),
              usage: context_wrapper.usage,
              context: context_wrapper.context,
              error: error
            )

            context_wrapper.callback_manager.emit_agent_complete(current_agent.name, result, error, context_wrapper)
            context_wrapper.callback_manager.emit_run_complete(current_agent.name, result, context_wrapper)
            return result
          end

          save_conversation_state(chat, context_wrapper, current_agent)
          context_wrapper.callback_manager.emit_agent_complete(current_agent.name, nil, nil, context_wrapper)

          # Patch: include context_wrapper for handoff payload extraction
          context_wrapper.callback_manager.emit_agent_handoff(current_agent.name, next_agent.name, "handoff", context_wrapper)

          current_agent = next_agent
          context_wrapper.context[:current_agent] = next_agent.name

          configure_chat_for_agent(chat, current_agent, context_wrapper, replace: true)
          agent_headers = Helpers::Headers.normalize(current_agent.headers)
          current_headers = Helpers::Headers.merge(agent_headers, runtime_headers)
          apply_headers(chat, current_headers)

          input = nil
          next
        end

        if response.is_a?(RubyLLM::Tool::Halt)
          save_conversation_state(chat, context_wrapper, current_agent)

          result = RunResult.new(
            output: response.content,
            messages: Helpers::MessageExtractor.extract_messages(chat, current_agent),
            usage: context_wrapper.usage,
            context: context_wrapper.context
          )

          context_wrapper.callback_manager.emit_agent_complete(current_agent.name, result, nil, context_wrapper)
          context_wrapper.callback_manager.emit_run_complete(current_agent.name, result, context_wrapper)
          return result
        end

        next if response.tool_call?

        save_conversation_state(chat, context_wrapper, current_agent)

        result = RunResult.new(
          output: response.content,
          messages: Helpers::MessageExtractor.extract_messages(chat, current_agent),
          usage: context_wrapper.usage,
          context: context_wrapper.context
        )

        context_wrapper.callback_manager.emit_agent_complete(current_agent.name, result, nil, context_wrapper)
        context_wrapper.callback_manager.emit_run_complete(current_agent.name, result, context_wrapper)
        return result
      end
    rescue Runner::MaxTurnsExceeded => e
      save_conversation_state(chat, context_wrapper, current_agent) if chat

      result = RunResult.new(
        output: "Conversation ended: #{e.message}",
        messages: chat ? Helpers::MessageExtractor.extract_messages(chat, current_agent) : [],
        usage: context_wrapper.usage,
        error: e,
        context: context_wrapper.context
      )

      context_wrapper.callback_manager.emit_agent_complete(current_agent.name, result, e, context_wrapper)
      context_wrapper.callback_manager.emit_run_complete(current_agent.name, result, context_wrapper)
      result
    rescue StandardError => e
      save_conversation_state(chat, context_wrapper, current_agent) if chat

      result = RunResult.new(
        output: nil,
        messages: chat ? Helpers::MessageExtractor.extract_messages(chat, current_agent) : [],
        usage: context_wrapper.usage,
        error: e,
        context: context_wrapper.context
      )

      context_wrapper.callback_manager.emit_agent_complete(current_agent.name, result, e, context_wrapper)
      context_wrapper.callback_manager.emit_run_complete(current_agent.name, result, context_wrapper)
      result
    end
  end
end

Agents::Runner.prepend(Agents::RunnerHandoffContextPatch)
