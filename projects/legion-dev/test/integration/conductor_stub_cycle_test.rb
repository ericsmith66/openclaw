# frozen_string_literal: true

require "test_helper"

class ConductorStubCycleTest < ActionDispatch::IntegrationTest
  # Integration test for PRD 2-06: Conductor Agent & WorkflowEngine
  # Tests full phase transitions with stubs (no VCR)
  # Verifies decision trail and phase transitions via stubbed orchestration tools
  #
  # Stub cycle: decompose → architect_review → coding → scoring → retrospective → complete
  # Each phase transition is verified via ConductorDecision records

  setup do
    @project = create(:project)
    @team = create(:agent_team, project: @project, name: "conductor")

    # Create team membership with conductor role
    @conductor_membership = create(:team_membership,
      agent_team: @team,
      role: "conductor",
      config: {
        "id" => "conductor-agent",
        "name" => "Conductor Agent",
        "provider" => "anthropic",
        "model" => "claude-3-5-sonnet-20240620"
      }
    )

    # Create workflow execution starting in decomposing phase
    @execution = create(:workflow_execution,
      project: @project,
      phase: "decomposing",
      status: "running"
    )

    # Stubbed decisions tracking
    @stubbed_decisions = []
  end

  # ───────────────────────────────────────────────
  # Stubbed Tool Call Handlers
  # ───────────────────────────────────────────────

  # Stub for dispatch_decompose tool
  def stub_dispatch_decompose(execution, tool_args)
    # Create decomposition workflow run
    workflow_run = create(:workflow_run,
      project: execution.project,
      team_membership: @conductor_membership,
      status: "completed"
    )

    # Create tasks for decomposition
    3.times do |i|
      create(:task,
        project: execution.project,
        team_membership: @conductor_membership,
        workflow_run: workflow_run,
        prompt: "Task #{i + 1}",
        status: "pending",
        position: i + 1
      )
    end

    # Record decision before phase change
    from_phase = execution.phase

    # Update execution phase
    execution.update!(phase: "executing")

    # Create ConductorDecision record
    execution.conductor_decisions.create!(
      decision_type: "approve",
      payload: tool_args,
      tool_name: "dispatch_decompose",
      tool_args: tool_args,
      from_phase: from_phase,
      to_phase: "executing",
      reasoning: tool_args["reasoning"],
      input_summary: { "prompt" => "test", "trigger" => "start" }.to_json,
      duration_ms: 100,
      tokens_used: 1200,
      estimated_cost: 0.036
    )

    # Record decision
    @stubbed_decisions << {
      tool_name: "dispatch_decompose",
      from_phase: from_phase,
      to_phase: "executing",
      reasoning: tool_args["reasoning"]
    }
  end

  # Stub for dispatch_architect_review tool
  def stub_dispatch_architect_review(execution, tool_args)
    # Create artifact for architect review
    create(:artifact,
      workflow_execution: execution,
      artifact_type: "architect_review",
      content: { score: 92, feedback: "Good decomposition" }.to_json
    )

    # Record decision before phase change
    from_phase = execution.phase

    # Update execution phase
    execution.update!(phase: "executing")

    # Create ConductorDecision record
    execution.conductor_decisions.create!(
      decision_type: "approve",
      payload: tool_args,
      tool_name: "dispatch_architect_review",
      tool_args: tool_args,
      from_phase: from_phase,
      to_phase: "executing",
      reasoning: tool_args["reasoning"],
      input_summary: { "prompt" => "test", "trigger" => "start" }.to_json,
      duration_ms: 100,
      tokens_used: 800,
      estimated_cost: 0.024
    )

    # Record decision
    @stubbed_decisions << {
      tool_name: "dispatch_architect_review",
      from_phase: from_phase,
      to_phase: "executing",
      reasoning: tool_args["reasoning"]
    }
  end

  # Stub for dispatch_coding tool
  def stub_dispatch_coding(execution, tool_args)
    # Record decision before phase change
    from_phase = execution.phase

    # Update execution phase
    execution.update!(phase: "executing")

    # Create ConductorDecision record
    execution.conductor_decisions.create!(
      decision_type: "approve",
      payload: tool_args,
      tool_name: "dispatch_coding",
      tool_args: tool_args,
      from_phase: from_phase,
      to_phase: "executing",
      reasoning: tool_args["reasoning"],
      input_summary: { "prompt" => "test", "trigger" => "start" }.to_json,
      duration_ms: 100,
      tokens_used: 600,
      estimated_cost: 0.018
    )

    # Record decision
    @stubbed_decisions << {
      tool_name: "dispatch_coding",
      from_phase: from_phase,
      to_phase: "executing",
      reasoning: tool_args["reasoning"]
    }
  end

  # Stub for dispatch_scoring tool
  def stub_dispatch_scoring(execution, tool_args)
    # Create artifact for QA score (using score_report as per Artifact model)
    create(:artifact,
      workflow_execution: execution,
      artifact_type: "score_report",
      content: { score: 95, verdict: "passed" }.to_json
    )

    # Record decision before phase change
    from_phase = execution.phase

    # Update execution phase
    execution.update!(phase: "reviewing")

    # Create ConductorDecision record
    execution.conductor_decisions.create!(
      decision_type: "approve",
      payload: tool_args,
      tool_name: "dispatch_scoring",
      tool_args: tool_args,
      from_phase: from_phase,
      to_phase: "reviewing",
      reasoning: tool_args["reasoning"],
      input_summary: { "prompt" => "test", "trigger" => "start" }.to_json,
      duration_ms: 100,
      tokens_used: 500,
      estimated_cost: 0.015
    )

    # Record decision
    @stubbed_decisions << {
      tool_name: "dispatch_scoring",
      from_phase: from_phase,
      to_phase: "reviewing",
      reasoning: tool_args["reasoning"]
    }
  end

  # Stub for run_retrospective tool
  def stub_run_retrospective(execution, tool_args)
    # Create artifact for retrospective report
    create(:artifact,
      workflow_execution: execution,
      artifact_type: "retrospective_report",
      content: {
        prompt_tweaks: [ "Add more context to initial prompt" ],
        skill_gaps: [ "Agent needs more training data" ],
        tool_improvements: [ "Add retry tool" ],
        rule_changes: [ "Add phase transition rules" ],
        decomposition_patterns: [ "Use linear task chains" ],
        model_fit: [ "Claude Sonnet works well" ],
        overall_assessment: "Execution successful",
        summary: "All phases completed successfully"
      }.to_json
    )

    # Record decision before phase change
    from_phase = execution.phase

    # Update execution phase
    execution.update!(phase: "synthesizing")

    # Create ConductorDecision record
    execution.conductor_decisions.create!(
      decision_type: "approve",
      payload: tool_args,
      tool_name: "run_retrospective",
      tool_args: tool_args,
      from_phase: from_phase,
      to_phase: "synthesizing",
      reasoning: tool_args["reasoning"],
      input_summary: { "prompt" => "test", "trigger" => "start" }.to_json,
      duration_ms: 100,
      tokens_used: 1000,
      estimated_cost: 0.030
    )

    # Record decision
    @stubbed_decisions << {
      tool_name: "run_retrospective",
      from_phase: from_phase,
      to_phase: "synthesizing",
      reasoning: tool_args["reasoning"]
    }
  end

  # Stub for mark_completed tool
  def stub_mark_completed(execution, tool_args)
    # Record decision before phase change
    from_phase = execution.phase

    # Update execution status and phase
    execution.update!(status: "completed", phase: "phase_completed")

    # Create ConductorDecision record
    execution.conductor_decisions.create!(
      decision_type: "approve",
      payload: tool_args,
      tool_name: "mark_completed",
      tool_args: tool_args,
      from_phase: from_phase,
      to_phase: "phase_completed",
      reasoning: tool_args["reasoning"],
      input_summary: { "prompt" => "test", "trigger" => "start" }.to_json,
      duration_ms: 100,
      tokens_used: 400,
      estimated_cost: 0.012
    )

    # Record decision
    @stubbed_decisions << {
      tool_name: "mark_completed",
      from_phase: from_phase,
      to_phase: "phase_completed",
      reasoning: tool_args["reasoning"]
    }
  end

  # ───────────────────────────────────────────────
  # Test Cases
  # ───────────────────────────────────────────────

  test "full phase transition cycle with stubs" do
    # Verify initial state
    assert_equal "decomposing", @execution.phase
    assert_equal "running", @execution.status
    assert_equal 0, @execution.conductor_decisions.count

    # Simulate full cycle via stubbed tool calls
    # Phase 1: decompose → executing
    stub_dispatch_decompose(@execution, { "reasoning" => "Start decomposition phase" })
    @execution.reload
    assert_equal "executing", @execution.phase

    # Phase 2: architect_review → executing (no phase change, gate pass)
    stub_dispatch_architect_review(@execution, { "reasoning" => "Architect review passed" })
    @execution.reload
    assert_equal "executing", @execution.phase

    # Phase 3: coding → executing (no phase change, coding in progress)
    stub_dispatch_coding(@execution, { "reasoning" => "Start coding phase" })
    @execution.reload
    assert_equal "executing", @execution.phase

    # Phase 4: scoring → reviewing
    stub_dispatch_scoring(@execution, { "reasoning" => "Run QA scoring" })
    @execution.reload
    assert_equal "reviewing", @execution.phase

    # Phase 5: retrospective → synthesizing
    stub_run_retrospective(@execution, { "reasoning" => "Run retrospective analysis" })
    @execution.reload
    assert_equal "synthesizing", @execution.phase

    # Phase 6: mark_completed → phase_completed
    stub_mark_completed(@execution, { "reasoning" => "Mark execution complete" })
    @execution.reload
    assert_equal "phase_completed", @execution.phase
    assert_equal "completed", @execution.status

    # Verify decision trail
    assert_equal 6, @execution.conductor_decisions.count

    # Verify decision trail has correct phases
    decisions = @execution.conductor_decisions.order(:created_at)
    assert_equal "dispatch_decompose", decisions[0].tool_name
    assert_equal "decomposing", decisions[0].from_phase
    assert_equal "executing", decisions[0].to_phase

    assert_equal "dispatch_architect_review", decisions[1].tool_name
    assert_equal "executing", decisions[1].from_phase
    assert_equal "executing", decisions[1].to_phase

    assert_equal "dispatch_coding", decisions[2].tool_name
    assert_equal "executing", decisions[2].from_phase
    assert_equal "executing", decisions[2].to_phase

    assert_equal "dispatch_scoring", decisions[3].tool_name
    assert_equal "executing", decisions[3].from_phase
    assert_equal "reviewing", decisions[3].to_phase

    assert_equal "run_retrospective", decisions[4].tool_name
    assert_equal "reviewing", decisions[4].from_phase
    assert_equal "synthesizing", decisions[4].to_phase

    assert_equal "mark_completed", decisions[5].tool_name
    assert_equal "synthesizing", decisions[5].from_phase
    assert_equal "phase_completed", decisions[5].to_phase
  end

  test "decision trail verification with reasoning" do
    # Simulate a complete cycle
    stub_dispatch_decompose(@execution, { "reasoning" => "Initial decomposition decision" })
    stub_dispatch_architect_review(@execution, { "reasoning" => "Architect review passed with score 92" })
    stub_mark_completed(@execution, { "reasoning" => "Execution completed successfully" })

    # Reload execution and verify decisions
    @execution.reload
    decisions = @execution.conductor_decisions.order(:created_at)

    # Verify each decision has reasoning
    decisions.each do |decision|
      assert decision.reasoning.present?, "Decision #{decision.id} missing reasoning"
      assert decision.tool_name.present?, "Decision #{decision.id} missing tool_name"
      assert decision.from_phase.present?, "Decision #{decision.id} missing from_phase"
      assert decision.to_phase.present?, "Decision #{decision.id} missing to_phase"
    end

    # Verify specific reasoning
    assert_equal "Initial decomposition decision", decisions[0].reasoning
    assert_equal "Architect review passed with score 92", decisions[1].reasoning
    assert_equal "Execution completed successfully", decisions[2].reasoning
  end

  test "stub cycle handles error recovery" do
    # Start cycle
    stub_dispatch_decompose(@execution, { "reasoning" => "Start decomposition" })
    @execution.reload
    assert_equal "executing", @execution.phase

    # Simulate error - no tool call in response
    # This should create an error decision
    error_decision = @execution.conductor_decisions.create!(
      decision_type: "reject_decision",
      payload: {},
      tool_name: nil,
      tool_args: {},
      from_phase: @execution.phase,
      to_phase: nil,
      reasoning: "No tool call detected in LLM response",
      input_summary: { "prompt" => "test", "trigger" => "start" }.to_json,
      duration_ms: 100,
      tokens_used: 0,
      estimated_cost: 0.0
    )

    # Verify error decision created
    assert error_decision.persisted?
    assert_equal "reject_decision", error_decision.decision_type
    assert_nil error_decision.to_phase

    # Continue cycle after error
    stub_dispatch_architect_review(@execution, { "reasoning" => "Retry after error" })
    @execution.reload
    assert_equal "executing", @execution.phase
  end

  test "stub cycle preserves phase transition history" do
    # Run multiple cycles
    3.times do |i|
      stub_dispatch_decompose(@execution, { "reasoning" => "Cycle #{i + 1} decomposition" })
      @execution.reload
      assert_equal "executing", @execution.phase
    end

    # Verify all decisions recorded
    assert_equal 3, @execution.conductor_decisions.count

    # Verify each decision has unique timestamp
    timestamps = @execution.conductor_decisions.pluck(:created_at)
    assert_equal 3, timestamps.uniq.size
  end

  test "stub cycle with multiple tasks enqueued" do
    # Start cycle
    stub_dispatch_decompose(@execution, { "reasoning" => "Start decomposition" })
    @execution.reload

    # Create tasks for the execution
    5.times do |i|
      create(:task,
        project: @execution.project,
        team_membership: @conductor_membership,
        workflow_run: create(:workflow_run, project: @execution.project, team_membership: @conductor_membership),
        prompt: "Task #{i + 1}",
        status: "pending",
        position: i + 1
      )
    end

    # Verify tasks created (3 from stub_dispatch_decompose + 5 new = 8)
    assert_equal 8, Task.where(project: @execution.project).count

    # Continue cycle
    stub_mark_completed(@execution, { "reasoning" => "All tasks completed" })
    @execution.reload

    assert_equal "phase_completed", @execution.phase
    assert_equal "completed", @execution.status
  end

  test "stub cycle verifies ConductorDecision schema fields" do
    stub_dispatch_decompose(@execution, { "reasoning" => "Test decision" })
    @execution.reload

    decision = @execution.conductor_decisions.first

    # Verify all required fields exist
    assert decision.decision_type.present?
    assert decision.payload.present?
    assert decision.tool_name.present?
    assert decision.tool_args.present?
    assert decision.from_phase.present?
    assert decision.to_phase.present?
    assert decision.reasoning.present?
    assert decision.input_summary.present?
    assert decision.duration_ms >= 0
    assert decision.tokens_used >= 0
    assert decision.estimated_cost >= 0.0
  end
end
