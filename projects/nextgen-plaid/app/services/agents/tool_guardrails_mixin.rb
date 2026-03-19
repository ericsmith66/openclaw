# frozen_string_literal: true

module Agents
  # Mixin for tools that need guardrail enforcement.
  #
  # Provides standard limits and enforcement for:
  # - Tool calls per turn
  # - Total tool calls across run
  # - Tool retry attempts
  #
  # Tools can override limits by defining constants:
  #   MAX_CALLS_PER_TURN = 50 (default: 30)
  #   MAX_RETRIES = 5 (default: 2)
  #
  # @example
  #   class MyTool < Agents::Tool
  #     include Agents::ToolGuardrailsMixin
  #
  #     def perform(tool_context, **args)
  #       enforce_tool_guardrails!(tool_context)
  #       # ... tool logic
  #     end
  #   end
  module ToolGuardrailsMixin
    DEFAULT_MAX_CALLS_PER_TURN = 30
    DEFAULT_MAX_RETRIES = 2

    private

    # Enforces guardrails on tool execution.
    #
    # Tracks and limits:
    # - Tool calls per turn (prevents infinite loops)
    # - Total tool calls (prevents runaway costs)
    # - Retry attempts (prevents retry storms)
    #
    # @param tool_context [Agents::ToolContext] the tool execution context
    # @raise [AiWorkflowService::GuardrailError] if any limit is exceeded
    def enforce_tool_guardrails!(tool_context)
      turn = (tool_context.context[:turn_count] || tool_context.context["turn_count"] || 0).to_i

      # Track calls per turn
      tool_context.context[:tool_calls_by_turn] ||= {}
      tool_context.context[:tool_calls_by_turn][turn] ||= 0
      tool_context.context[:tool_calls_by_turn][turn] += 1

      # Track total calls
      tool_context.context[:tool_calls_total] ||= 0
      tool_context.context[:tool_calls_total] += 1

      # Check total limit (if set)
      max_total = tool_context.context[:max_tool_calls_total] || tool_context.context["max_tool_calls_total"]
      if max_total.present? && tool_context.context[:tool_calls_total] > max_total.to_i
        raise AiWorkflowService::GuardrailError, "max tool calls exceeded (#{tool_context.context[:tool_calls_total]}/#{max_total})"
      end

      # Check per-turn limit
      if tool_context.context[:tool_calls_by_turn][turn] > max_calls_per_turn_limit
        raise AiWorkflowService::GuardrailError, "max tool calls exceeded for turn #{turn}"
      end

      # Check retry limit
      if tool_context.retry_count.to_i > max_retries_limit
        raise AiWorkflowService::GuardrailError, "max tool retries exceeded"
      end
    end

    # Returns the maximum calls allowed per turn.
    # Tools can override by defining MAX_CALLS_PER_TURN constant.
    def max_calls_per_turn_limit
      self.class.const_get(:MAX_CALLS_PER_TURN)
    rescue NameError
      DEFAULT_MAX_CALLS_PER_TURN
    end

    # Returns the maximum retry attempts allowed.
    # Tools can override by defining MAX_RETRIES constant.
    def max_retries_limit
      self.class.const_get(:MAX_RETRIES)
    rescue NameError
      DEFAULT_MAX_RETRIES
    end
  end
end
