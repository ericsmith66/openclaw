# frozen_string_literal: true

require "json"
require "yaml"
require "fileutils"
require "securerandom"
require "time"
require Rails.root.join("app", "services", "ai", "cwa_task_log_service")
require Rails.root.join("app", "services", "ai_workflow", "artifact_writer")
require Rails.root.join("app", "services", "ai_workflow", "agent_factory")
require Rails.root.join("app", "services", "ai_workflow", "context_manager")
require Rails.root.join("app", "services", "ai_workflow", "guardrail_enforcer")

class AiWorkflowService
  class GuardrailError < StandardError; end
  class EscalateToHumanError < GuardrailError; end

  SimpleResult = Struct.new(:output, :context, :error, :usage, keyword_init: true)

  DEFAULT_MAX_TURNS = 5

  # PRD 0050: resume a run from persisted artifacts when possible.
  def self.load_existing_context(correlation_id)
    AiWorkflow::ContextManager.load_existing(correlation_id)
  end

  # PRD 0050: explicit helper to encapsulate the handoff payload schema.
  def self.handoff_to_cwa(context:, reason: nil)
    {
      correlation_id: context[:correlation_id],
      micro_tasks: context[:micro_tasks] || [],
      reason: reason,
      workflow_state: context[:workflow_state]
    }.compact
  end

  def self.find_workflow_run(correlation_id)
    AiWorkflowRun.find_by(id: correlation_id) || AiWorkflowRun.find_by(correlation_id: correlation_id.to_s)
  end

  def self.finalize_hybrid_handoff!(result, artifacts:)
    current_agent = result.context[:current_agent] || result.context["current_agent"]
    workflow_state = result.context[:workflow_state] || result.context["workflow_state"]
    correlation_id = result.context[:correlation_id] || result.context["correlation_id"]

    # Always try to sync micro-tasks to the artifact if they were generated
    if (run = find_workflow_run(correlation_id)) && (artifact = run.active_artifact)
      micro_tasks = result.context[:micro_tasks] || result.context["micro_tasks"]
      if micro_tasks.present?
        # Use WorkflowBridge to handle the transition and updates (PRD-AH-011F)
        AgentHub::WorkflowBridge.execute_transition(
          artifact_id: artifact.id,
          command: "approve",
          user: run.user,
          agent_id: "Coordinator",
          payload_updates: { "micro_tasks" => micro_tasks }
        )

        # Broadcast the plan to Agent Hub immediately for visibility
        plan_summary = +"### 📋 Technical Plan Generated\n"
        micro_tasks.each do |task|
          plan_summary << "- [ ] **#{task['id']}**: #{task['title']} (#{task['estimate']})\n"
        end
        plan_summary << "\nType `/inspect` to see full details or `/approve` to move to development."

        unless Ai::TestMode.enabled?
          ActionCable.server.broadcast("agent_hub_channel_#{correlation_id}", {
            type: "token",
            message_id: "auto-plan-#{Time.now.to_i}",
            token: plan_summary
          })
          ActionCable.server.broadcast("agent_hub_channel_all_agents", {
            type: "token",
            message_id: "auto-plan-#{Time.now.to_i}",
            token: plan_summary
          })
        end
      end
    end

    # If CWA was the last agent to speak and we didn't hit an explicit error state,
    # transition to awaiting human review.
    if current_agent.to_s == "CWA" && workflow_state.to_s == "in_progress"
      result.context[:workflow_state] = Ai::TestMode.enabled? ? "resolved" : "awaiting_review"
      result.context[:ball_with] = Ai::TestMode.enabled? ? "Human" : "Human"
      artifacts.record_event(type: "awaiting_review", from: "CWA")

      # Result Loopback: Transition Artifact phase and attach notes
      if (run = find_workflow_run(correlation_id)) && (artifact = run.active_artifact)
        implementation_notes = "Autonomous CWA run completed successfully.\n"

        # Try to gather git diff if available in tools traces
        git_events = artifacts.instance_variable_get(:@events)&.select { |e| e[:tool_name] == "GitTool" }
        if (diff_event = git_events&.find { |e| e[:args]&.fetch("action", nil) == "diff" })
          implementation_notes += "\nGit Diff:\n#{diff_event[:result]}"
        end

        # Try to gather test results if available
        shell_events = artifacts.instance_variable_get(:@events)&.select { |e| e[:tool_name] == "SafeShellTool" }
        test_event = shell_events&.reverse&.find { |e| e[:args] && e[:args].fetch("cmd", "").to_s.match?(/(rake|rails) test/) }
        if test_event
          implementation_notes += "\n\nLast Test Results (Status: #{test_event[:result][:status]}):\n#{test_event[:result][:stdout]}"
        end

        # Use WorkflowBridge to handle the transition and updates (PRD-AH-011F)
        AgentHub::WorkflowBridge.execute_transition(
          artifact_id: artifact.id,
          command: "approve",
          user: run.user,
          agent_id: "CWA",
          payload_updates: { "implementation_notes" => implementation_notes }
        )

        unless Ai::TestMode.enabled?
          ActionCable.server.broadcast("agent_hub_channel_all_agents", {
            type: "token",
            message_id: "auto-loopback-#{Time.now.to_i}",
            token: "✅ Artifact '#{artifact.name}' moved to Ready for QA by CWA."
          })
        end
      end

      artifacts.record_event(
        type: "draft_artifacts_available",
        message: "Review draft artifacts (logs, diffs, commits) before merging.",
        correlation_id: result.context[:correlation_id] || result.context["correlation_id"],
        run_dir: Rails.root.join("agent_logs", "ai_workflow", (result.context[:correlation_id] || result.context["correlation_id"]).to_s).to_s,
        sandbox_hint: Rails.root.join("tmp", "agent_sandbox").to_s
      )
    end

    if workflow_state.to_s == "escalated_to_human" || workflow_state.to_s == "blocked" || workflow_state.to_s == "failed"
      result.context[:ball_with] = "Human"

      correlation_id = result.context[:correlation_id] || result.context["correlation_id"]
      if (run = find_workflow_run(correlation_id)) && (artifact = run.active_artifact)
        # Use WorkflowBridge to handle the transition and updates (PRD-AH-011F)
        AgentHub::WorkflowBridge.execute_transition(
          artifact_id: artifact.id,
          command: "reject",
          user: run.user,
          agent_id: "CWA"
        )

        unless Ai::TestMode.enabled?
          ActionCable.server.broadcast("agent_hub_channel_all_agents", {
            type: "token",
            message_id: "auto-failure-#{Time.now.to_i}",
            token: "❌ Autonomous run failed for '#{artifact.name}'. Moved back to #{artifact.phase.humanize}."
          })
        end
      end
    end

    result
  end

  def self.run(
    prompt:,
    correlation_id: SecureRandom.uuid,
    max_turns: DEFAULT_MAX_TURNS,
    model: nil,
    test_mode: false,
    test_overrides: {},
    start_agent: nil
  )
    raise GuardrailError, "prompt must be present" if prompt.nil? || prompt.strip.empty?

    Ai::TestMode.with(enabled: test_mode) do
      context = load_existing_context(correlation_id) || build_initial_context(correlation_id)
      context[:sandbox_level] ||= test_overrides["sandbox_level"] if test_overrides.is_a?(Hash)
      context[:max_tool_calls_total] ||= test_overrides["max_tool_calls"] if test_overrides.is_a?(Hash)
      context[:llm_base_dir] ||= test_overrides["llm_base_dir"] if test_overrides.is_a?(Hash)
      if test_overrides.is_a?(Hash) && test_overrides["micro_tasks"].present? && (context[:micro_tasks].blank? && context["micro_tasks"].blank?)
        context[:micro_tasks] = test_overrides["micro_tasks"]
      end

      artifacts = AiWorkflow::ArtifactWriter.new(
        correlation_id,
        cwa_cli_log_path: test_overrides.is_a?(Hash) ? test_overrides["cwa_log_path"] : nil,
        cwa_summary_path: test_overrides.is_a?(Hash) ? test_overrides["cwa_summary_path"] : nil
      )

      artifacts.record_event(type: "test_overrides", payload: test_overrides) if test_overrides.present?

      # PRD 0050: log Junie deprecation routing.
      if prompt.to_s.match?(/\bjunie\b/i)
        artifacts.record_event(type: "junie_deprecation", message: "Deprecating Junie: Using CWA for task")
      end

      common_context = AiWorkflow::ContextManager.prepare_rag_context

      factory = AiWorkflow::AgentFactory.new(
        model: model,
        test_overrides: test_overrides,
        common_context: common_context,
        context: context
      )
      agents = factory.build_agents

      sap_agent = agents[:sap]
      coordinator_agent = agents[:coordinator]
      planner_agent = agents[:planner]
      cwa_agent = agents[:cwa]

      headers = {
        "X-Request-ID" => SecureRandom.uuid,
        "X-Correlation-ID" => correlation_id.to_s,
        "X-LLM-Base-Dir" => context&.fetch(:llm_base_dir, nil).to_s
      }.compact

      agent_order = case start_agent.to_s
      when "Coordinator"
                      [ coordinator_agent, planner_agent, cwa_agent, sap_agent ]
      when "Planner"
                      [ planner_agent, cwa_agent, coordinator_agent, sap_agent ]
      when "CWA"
                      [ cwa_agent, planner_agent, coordinator_agent, sap_agent ]
      else
                      [ sap_agent, coordinator_agent, planner_agent, cwa_agent ]
      end

      runner = Agents::Runner.with_agents(*agent_order)
      artifacts.attach_callbacks!(runner)

      result = runner.run(
        prompt,
        context: context,
        max_turns: max_turns,
        headers: headers
      )

      # Normalize ownership tracking.
      current_agent = result.context[:current_agent] || result.context["current_agent"]
      result.context[:ball_with] = current_agent

      turn_count = result.context[:turn_count] || result.context["turn_count"]
      result.context[:turns_count] = turn_count

      artifacts.write_run_json(result)

      finalize_hybrid_handoff!(result, artifacts: artifacts)

      artifacts.write_run_json(result)

      result
    rescue EscalateToHumanError => e
      raise unless test_mode

      artifacts.record_event(type: "escalate_suppressed", message: e.message)
      context[:workflow_state] = "escalated_to_human"
      suppressed = SimpleResult.new(output: nil, context: context, error: e, usage: nil)
      artifacts.write_run_json(suppressed)
      suppressed
    end
  rescue StandardError => e
    # Best-effort event + run.json on failures.
    begin
      artifacts ||= AiWorkflow::ArtifactWriter.new(correlation_id)
      artifacts.write_error(e)
    rescue StandardError
      # ignore
    end
    raise
  end

  # Multi-turn feedback/resolution loop.
  #
  # Intended usage:
  # - Call with `feedback: nil` to get an initial response + enter `awaiting_feedback`.
  # - Call again with `feedback:` to continue and attempt to reach a terminal state.
  def self.resolve_feedback(
    prompt:,
    feedback: nil,
    correlation_id: SecureRandom.uuid,
    max_turns: DEFAULT_MAX_TURNS,
    model: nil,
    route: "dm"
  )
    raise GuardrailError, "prompt must be present" if prompt.nil? || prompt.strip.empty?

    context = load_existing_context(correlation_id) || build_initial_context(correlation_id)
    artifacts = AiWorkflow::ArtifactWriter.new(correlation_id)

    if prompt.to_s.match?(/\bjunie\b/i)
      artifacts.record_event(type: "junie_deprecation", message: "Deprecating Junie: Using CWA for task")
    end

    initial = run_once(
      prompt: "User request:\n#{prompt}",
      context: context,
      artifacts: artifacts,
      max_turns: max_turns,
      model: model
    )

    finalize_hybrid_handoff!(initial, artifacts: artifacts)

    if feedback.nil? || feedback.to_s.strip.empty?
      entry = {
        ts: Time.now.utc.iso8601,
        prompt: prompt,
        requested_by: "Coordinator"
      }
      context[:workflow_state] = "awaiting_feedback"
      context[:feedback_history] << entry

      initial.context[:workflow_state] = context[:workflow_state]
      initial.context[:feedback_history] = context[:feedback_history]

      artifacts.record_event(type: "feedback_requested", route: route, requested_by: "Coordinator")
      artifacts.write_run_json(initial)
      return initial
    end

    entry = {
      ts: Time.now.utc.iso8601,
      prompt: prompt,
      feedback: feedback.to_s
    }
    context[:feedback_history] << entry
    artifacts.record_event(type: "feedback_received", route: route)

    resolved = run_once(
      prompt: "Resolve: #{prompt}\n\nFeedback:\n#{feedback}",
      context: context,
      artifacts: artifacts,
      max_turns: max_turns,
      model: model
    )

    finalize_hybrid_handoff!(resolved, artifacts: artifacts)
    context[:workflow_state] = "resolved"
    resolved.context[:workflow_state] = context[:workflow_state]
    resolved.context[:feedback_history] = context[:feedback_history]
    artifacts.record_event(type: "resolution_complete", workflow_state: resolved.context[:workflow_state], route: route)
    artifacts.write_run_json(resolved)
    resolved
  rescue EscalateToHumanError => e
    begin
      artifacts ||= AiWorkflow::ArtifactWriter.new(correlation_id)
      context ||= build_initial_context(correlation_id)
      context[:workflow_state] = "escalated_to_human"
      artifacts.record_event(type: "escalate_to_human", reason: e.message, route: route)
      artifacts.write_run_payload(correlation_id: correlation_id, error: e.message, context: context)
    rescue StandardError
      # ignore
    end
    raise
  end

  def self.build_initial_context(correlation_id)
    AiWorkflow::ContextManager.build_initial(correlation_id)
  end

  def self.run_once(prompt:, context:, artifacts:, max_turns:, model: nil)
    routing_decision = Ai::RoutingPolicy.call(
      prompt: prompt,
      research_requested: !!(context[:research_requested] || context["research_requested"])
    )

    chosen_model = model || routing_decision.model_id

    artifacts.record_event(
      type: "routing_decision",
      policy_version: routing_decision.policy_version,
      model_id: routing_decision.model_id,
      use_live_search: routing_decision.use_live_search,
      reason: routing_decision.reason,
      chosen_model: chosen_model
    )

    common_context = AiWorkflow::ContextManager.prepare_rag_context

    factory = AiWorkflow::AgentFactory.new(
      model: chosen_model,
      test_overrides: {},
      common_context: common_context,
      context: context
    )
    agents = factory.build_agents

    sap_agent = agents[:sap]
    coordinator_agent = agents[:coordinator]
    planner_agent = agents[:planner]
    cwa_agent = agents[:cwa]

    # Per-run correlation header; DO NOT use X-Request-ID here.
    # SmartProxy uses X-Request-ID to name per-call artifacts. If we set it here,
    # every LLM call in the run would share the same request id and overwrite files.
    headers = {
      "X-Correlation-ID" => context[:correlation_id].to_s
    }

    runner = Agents::Runner.with_agents(sap_agent, coordinator_agent, planner_agent, cwa_agent)
    artifacts.attach_callbacks!(runner)

    # Retry transient LLM/provider errors (these happen intermittently in practice).
    # We keep the retry scope small: only the runner call, and only for known transient classes.
    attempts = 0
    begin
      attempts += 1
      result = runner.run(
        prompt,
        context: context,
        max_turns: max_turns,
        headers: headers
      )
    rescue StandardError => e
      err_class = e.class.name.to_s

      # Capture metadata for diagnosing provider-side validation errors.
      if err_class == "RubyLLM::BadRequestError"
        artifacts.record_event(
          type: "llm_bad_request",
          error_class: err_class,
          message: e.message.to_s,
          chosen_model: chosen_model,
          prompt_bytes: prompt.to_s.bytesize,
          prompt_preview: prompt.to_s.byteslice(0, 500),
          context_keys: (context.is_a?(Hash) ? context.keys.map(&:to_s).sort : nil)
        )
      end

      if err_class == "RubyLLM::ServerError" && attempts < Integer(ENV.fetch("AI_LLM_MAX_RETRIES", "3"))
        sleep_seconds = 0.5 * (2**(attempts - 1))
        artifacts.record_event(type: "llm_retry", error_class: err_class, attempt: attempts, sleep_seconds: sleep_seconds)
        sleep sleep_seconds
        retry
      end

      raise
    end

    normalize_context!(result)
    enforce_turn_guardrails!(result, max_turns: max_turns, artifacts: artifacts)
    result
  rescue Timeout::Error, Net::ReadTimeout, Net::OpenTimeout => e
    artifacts.record_event(type: "timeout", message: e.message)
    raise EscalateToHumanError, "request timed out"
  rescue StandardError => e
    # Some HTTP stacks raise their own timeout types; treat as escalation if it smells like a timeout.
    if e.class.name.to_s.include?("Timeout")
      artifacts.record_event(type: "timeout", message: e.message, error_class: e.class.name)
      raise EscalateToHumanError, "request timed out"
    end
    raise
  end

  def self.normalize_context!(result)
    AiWorkflow::ContextManager.normalize!(result)
  end

  def self.enforce_turn_guardrails!(result, max_turns:, artifacts:)
    AiWorkflow::GuardrailEnforcer.enforce_turn_limit!(result, max_turns: max_turns, artifacts: artifacts)
  end
end
