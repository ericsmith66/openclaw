# frozen_string_literal: true

module Legion
  # ConductorService orchestrates the workflow execution by:
  # - Finding the conductor team member
  # - Rendering the conductor prompt
  # - Dispatching to AgentDesk
  # - Processing tool calls and creating ConductorDecision records
  # - Updating the workflow execution phase
  #
  # @example
  #   Legion::ConductorService.call(execution: workflow_execution, trigger: :start)
  class ConductorService
    def self.call(execution:, trigger:)
      new(execution:, trigger:).call
    end

    def initialize(execution:, trigger:)
      @execution = execution
      @trigger = trigger
    end

    def call
      team_membership = find_conductor_team_membership
      prompt = build_prompt(team_membership)
      config = build_agent_config(team_membership)

      start_time = Time.current
      response = dispatch_to_agent(prompt, config)
      duration_ms = ((Time.current - start_time) * 1000).to_i

      process_response(response, duration_ms, prompt, team_membership)
    end

    private

    def find_conductor_team_membership
      @execution.team.team_memberships.find_by(role: "conductor") ||
        raise(ConductorNotFoundError, "Conductor team membership not found for team '#{@execution.team.name}'")
    end

    def build_prompt(team_membership)
      PromptBuilder.build(
        phase: :conductor,
        context: {
          execution: @execution,
          trigger: @trigger,
          team_membership: team_membership
        }
      )
    end

    def build_agent_config(team_membership)
      # Use the agent_config from team_membership if available
      config = team_membership.agent_config || team_membership.config
      {
        "model" => config["model"],
        "tools" => config["tools"] || []
      }
    end

    def dispatch_to_agent(prompt, config)
      tools = build_tool_set(config["tools"])
      Legion::AgentDesk.dispatch(prompt, config, tools: tools)
    end

    def build_tool_set(tool_names)
      # Map tool names to their definitions
      # For now, return an empty array - tool definitions would be registered elsewhere
      []
    end

    def process_response(response, duration_ms, prompt, team_membership)
      tool_call = extract_tool_call(response)

      if tool_call.nil?
        create_error_decision(response, duration_ms, prompt, team_membership)
        return
      end

      tool_name = tool_call["name"]
      tool_args = parse_tool_args(tool_call["arguments"])

      phase_transition = determine_phase_transition(tool_name, tool_args)
      from_phase = @execution.phase
      to_phase = phase_transition[:to_phase]

      reasoning = extract_reasoning(tool_name, tool_args, response)

      input_summary = {
        "prompt" => prompt,
        "model" => response.dig("model") || team_membership.config["model"],
        "trigger" => @trigger.to_s
      }

      tokens_used = calculate_tokens_used(response)

      decision = @execution.conductor_decisions.create!(
        decision_type: "approve",
        payload: tool_args,
        tool_name: tool_name,
        tool_args: tool_args,
        from_phase: from_phase,
        to_phase: to_phase,
        reasoning: reasoning,
        input_summary: input_summary.to_json,
        duration_ms: duration_ms,
        tokens_used: tokens_used,
        estimated_cost: calculate_estimated_cost(tokens_used, duration_ms)
      )

      if to_phase
        @execution.update!(phase: to_phase)
      end

      decision
    rescue StandardError => e
      Rails.logger.error("[ConductorService] Error processing response: #{e.message}")
      create_error_decision(response, duration_ms, prompt, team_membership, e)
      raise
    end

    def extract_tool_call(response)
      # Try to extract from tool_calls array
      if response["tool_calls"]&.any?
        response["tool_calls"].first
      elsif response["choices"]&.first&.dig("message")&.dig("tool_calls")&.any?
        response["choices"].first["message"]["tool_calls"].first
      else
        nil
      end
    end

    def parse_tool_args(arguments)
      if arguments.is_a?(String)
        JSON.parse(arguments)
      elsif arguments.is_a?(Hash)
        arguments
      else
        {}
      end
    rescue JSON::ParserError
      {}
    end

    def determine_phase_transition(tool_name, tool_args)
      # Define phase transitions based on tool names
      case tool_name
      when "dispatch_decompose"
        { to_phase: "decomposing" }
      when "dispatch_plan"
        { to_phase: "planning" }
      when "dispatch_execute"
        { to_phase: "executing" }
      when "dispatch_review"
        { to_phase: "reviewing" }
      when "dispatch_validate"
        { to_phase: "validating" }
      when "dispatch_synthesize"
        { to_phase: "synthesizing" }
      when "dispatch_iterate"
        { to_phase: "iterating" }
      else
        { to_phase: nil }
      end
    end

    def extract_reasoning(tool_name, tool_args, response)
      # Use reasoning from tool_args if present
      if tool_args.is_a?(Hash) && tool_args["reasoning"]
        tool_args["reasoning"]
      # Otherwise, extract from response content
      elsif response["choices"]&.first&.dig("message")&.dig("content")
        response["choices"].first["message"]["content"]
      else
        "No reasoning provided"
      end
    end

    def calculate_tokens_used(response)
      usage = response.dig("usage") || {}
      usage["total_tokens"] || 0
    end

    def calculate_estimated_cost(tokens_used, duration_ms)
      # Estimate cost based on token usage
      # Using approximate rates: $3/million input tokens, $15/million output tokens
      # For simplicity, use an average rate of $9/million tokens
      rate_per_million = 9.0
      (tokens_used / 1_000_000.0) * rate_per_million
    end

    def create_error_decision(response, duration_ms, prompt, team_membership, error = nil)
      error_reasoning = if error
        "Error processing response: #{error.message}"
      elsif response["choices"]&.first&.dig("message", "content")
        response["choices"].first["message"]["content"]
      else
        "No tool call detected in LLM response"
      end

      input_summary = {
        "prompt" => prompt,
        "model" => team_membership.config["model"],
        "trigger" => @trigger.to_s
      }

      @execution.conductor_decisions.create!(
        decision_type: "reject_decision",
        payload: {},
        tool_name: nil,
        tool_args: {},
        from_phase: @execution.phase,
        to_phase: nil,
        reasoning: error_reasoning,
        input_summary: input_summary.to_json,
        duration_ms: duration_ms,
        tokens_used: 0,
        estimated_cost: 0.0
      )

      # Enqueue retry for error recovery
      ConductorJob.perform_later(execution_id: @execution.id, trigger: :error_recovery)
    end

    # Custom error classes
    ConductorNotFoundError = Class.new(StandardError)
    ConductorNotConfiguredError = Class.new(StandardError)
  end
end
