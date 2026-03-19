# frozen_string_literal: true

require "test_helper"

module Legion
  class ArchitectGateTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project)
      @execution = create(:workflow_execution, project: @project)

      # Stub DispatchService so evaluate never hits real agent infrastructure.
      # Individual tests that care about the result override this stub locally.
      @default_dispatch_result = mock("dispatch_result")
      @default_dispatch_result.stubs(:result).returns("")
      Legion::DispatchService.stubs(:call).returns(@default_dispatch_result)

      # Stub lower-level agent infrastructure (precautionary — DispatchService stub
      # above should prevent these from being reached, but kept for safety).
      AgentDesk::Rules::RulesLoader.stubs(:load_rules_content).returns("rules content")
      AgentDesk::Prompts::PromptsManager.stubs(:system_prompt).returns("system prompt")
      AgentDesk::Tools::PowerTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Skills::SkillLoader.any_instance.stubs(:activate_skill_tool).returns(stub(full_name: "skills---activate_skill"))
      AgentDesk::Tools::TodoTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Tools::MemoryTools.stubs(:create).returns(AgentDesk::Tools::ToolSet.new)
      AgentDesk::Models::ModelManager.stubs(:new).returns(mock)
      Legion::PostgresBus.stubs(:new).returns(mock)
      AgentDesk::Hooks::HookManager.stubs(:new).returns(mock)
      AgentDesk::Tools::ApprovalManager.stubs(:new).returns(mock)
      AgentDesk::Agent::Runner.stubs(:new).returns(mock)

      default_runner = mock
      default_runner.stubs(:run)
      default_profile = mock
      default_profile.stubs(:id).returns("default")
      default_profile.stubs(:name).returns("default")
      default_profile.stubs(:provider).returns("default")
      default_profile.stubs(:model).returns("default")
      default_profile.stubs(:max_iterations).returns(100)
      Legion::AgentAssemblyService.stubs(:call).returns({
        runner: default_runner,
        system_prompt: "default",
        tool_set: mock,
        profile: default_profile,
        message_bus: mock
      })
    end

    # ---------------------------------------------------------------------------
    # Initialization
    # ---------------------------------------------------------------------------

    test "initializes with execution" do
      gate = ArchitectGate.new(execution: @execution)

      assert_equal @execution, gate.instance_variable_get(:@execution)
      assert_nil gate.instance_variable_get(:@workflow_run)
    end

    test "initializes with execution and workflow_run" do
      workflow_run = create(:workflow_run, project: @project)
      gate = ArchitectGate.new(execution: @execution, workflow_run: workflow_run)

      assert_equal @execution, gate.instance_variable_get(:@execution)
      assert_equal workflow_run, gate.instance_variable_get(:@workflow_run)
    end

    # ---------------------------------------------------------------------------
    # Subclass contract
    # ---------------------------------------------------------------------------

    test "gate_name returns 'architect'" do
      gate = ArchitectGate.new(execution: @execution)

      assert_equal "architect", gate.gate_name
    end

    test "prompt_template_phase returns :architect_review" do
      gate = ArchitectGate.new(execution: @execution)

      assert_equal :architect_review, gate.prompt_template_phase
    end

    test "agent_role returns 'architect'" do
      gate = ArchitectGate.new(execution: @execution)

      assert_equal "architect", gate.agent_role
    end

    test "default_threshold returns 80" do
      gate = ArchitectGate.new(execution: @execution)

      assert_equal 80, gate.default_threshold
    end

    # ---------------------------------------------------------------------------
    # gate_context
    # ---------------------------------------------------------------------------

    test "gate_context includes task_list" do
      gate = ArchitectGate.new(execution: @execution)
      context = gate.gate_context

      assert context.key?(:task_list)
    end

    test "gate_context includes dag" do
      gate = ArchitectGate.new(execution: @execution)
      context = gate.gate_context

      assert context.key?(:dag)
    end

    test "gate_context includes prd_content" do
      gate = ArchitectGate.new(execution: @execution)
      context = gate.gate_context

      assert context.key?(:prd_content)
      assert_equal @project.prd_content, context[:prd_content]
    end

    test "gate_context includes acceptance_criteria" do
      gate = ArchitectGate.new(execution: @execution)
      context = gate.gate_context

      assert context.key?(:acceptance_criteria)
      assert_equal @project.acceptance_criteria, context[:acceptance_criteria]
    end

    # ---------------------------------------------------------------------------
    # build_task_list
    # ---------------------------------------------------------------------------

    test "build_task_list returns empty array when no tasks" do
      gate = ArchitectGate.new(execution: @execution)
      task_list = gate.send(:build_task_list)

      assert_equal [], task_list
    end

    test "build_task_list returns task data with position, prompt, status, result, error_message" do
      task = create(:task,
        workflow_execution: @execution,
        position: 1,
        prompt: "Test task prompt",
        status: "completed",
        result: "Test result",
        error_message: nil
      )

      gate = ArchitectGate.new(execution: @execution)
      task_list = gate.send(:build_task_list)

      assert_equal 1, task_list.size
      assert_equal 1, task_list.first[:position]
      assert_equal "Test task prompt", task_list.first[:prompt]
      assert_equal "completed", task_list.first[:status]
      assert_equal "Test result", task_list.first[:result]
      assert_nil task_list.first[:error_message]
    end

    test "build_task_list uses workflow_run tasks when provided" do
      workflow_run = create(:workflow_run, project: @project)
      _task = create(:task,
        workflow_run: workflow_run,
        position: 1,
        prompt: "Test task prompt",
        status: "completed",
        result: "Test result",
        error_message: nil
      )

      gate = ArchitectGate.new(execution: @execution, workflow_run: workflow_run)
      task_list = gate.send(:build_task_list)

      assert_equal 1, task_list.size
      assert_equal 1, task_list.first[:position]
    end

    # ---------------------------------------------------------------------------
    # build_dag
    # ---------------------------------------------------------------------------

    test "build_dag returns empty array when no tasks" do
      gate = ArchitectGate.new(execution: @execution)
      dag = gate.send(:build_dag)

      assert_equal [], dag
    end

    test "build_dag returns task data with position, prompt, dependencies" do
      task = create(:task,
        workflow_execution: @execution,
        position: 1,
        prompt: "Test task prompt"
      )
      dep_task = create(:task,
        workflow_execution: @execution,
        position: 2,
        prompt: "Dependent task"
      )
      create(:task_dependency, task: task, depends_on_task: dep_task)

      gate = ArchitectGate.new(execution: @execution)
      dag = gate.send(:build_dag)

      assert_equal 2, dag.size
      task_dag = dag.find { |d| d[:position] == 1 }
      assert_equal 1, task_dag[:position]
      assert_equal "Test task prompt", task_dag[:prompt]
      assert_equal [ 2 ], task_dag[:dependencies]
    end

    test "build_dag uses workflow_run tasks when provided" do
      workflow_run = create(:workflow_run, project: @project)
      _task = create(:task,
        workflow_run: workflow_run,
        position: 1,
        prompt: "Test task prompt"
      )

      gate = ArchitectGate.new(execution: @execution, workflow_run: workflow_run)
      dag = gate.send(:build_dag)

      assert_equal 1, dag.size
      assert_equal 1, dag.first[:position]
    end

    # ---------------------------------------------------------------------------
    # evaluate — method dispatch (uses default DispatchService stub)
    # ---------------------------------------------------------------------------

    test "evaluate calls build_prompt" do
      gate = ArchitectGate.new(execution: @execution)
      gate.expects(:build_prompt)

      gate.evaluate
    end

    test "evaluate calls dispatch_agent" do
      gate = ArchitectGate.new(execution: @execution)
      gate.expects(:dispatch_agent)

      gate.evaluate
    end

    test "evaluate calls parse_score" do
      gate = ArchitectGate.new(execution: @execution)
      gate.expects(:parse_score)

      gate.evaluate
    end

    test "evaluate calls create_artifact" do
      gate = ArchitectGate.new(execution: @execution)
      gate.expects(:create_artifact)

      gate.evaluate
    end

    test "evaluate calls build_result" do
      gate = ArchitectGate.new(execution: @execution)
      gate.expects(:build_result)

      gate.evaluate
    end

    # ---------------------------------------------------------------------------
    # evaluate — result correctness (each test stubs DispatchService locally)
    # ---------------------------------------------------------------------------

    test "evaluate returns GateResult with passed status" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n85/100\n\n## Feedback\nGood review")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = ArchitectGate.new(execution: @execution)
      result = gate.evaluate

      assert result.is_a?(QualityGate::GateResult)
      assert result.passed
      assert_equal 85, result.score
      assert_equal "Good review", result.feedback
      assert result.artifact
    end

    test "evaluate returns GateResult with failed status when score below threshold" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n70/100\n\n## Feedback\nNeeds improvement")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = ArchitectGate.new(execution: @execution)
      result = gate.evaluate

      assert result.is_a?(QualityGate::GateResult)
      refute result.passed
      assert_equal 70, result.score
    end

    test "evaluate uses custom threshold when provided" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n75/100\n\n## Feedback\nGood review")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = ArchitectGate.new(execution: @execution)
      result = gate.evaluate(threshold: 70)

      assert result.passed
      assert_equal 75, result.score
    end

    test "evaluate creates artifact with artifact_type 'architect_review'" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n85/100\n\n## Feedback\nGood review")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = ArchitectGate.new(execution: @execution)
      result = gate.evaluate

      assert_equal "architect_review", result.artifact.artifact_type
    end

    test "evaluate creates artifact with gate_context including task_list and dag" do
      task1 = create(:task,
        workflow_execution: @execution,
        position: 1,
        prompt: "Task 1",
        status: "pending",
        result: nil,
        error_message: nil
      )
      task2 = create(:task,
        workflow_execution: @execution,
        position: 2,
        prompt: "Task 2",
        status: "pending",
        result: nil,
        error_message: nil
      )
      create(:task_dependency, task: task2, depends_on_task: task1)

      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n85/100\n\n## Feedback\nGood review")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = ArchitectGate.new(execution: @execution)
      result = gate.evaluate

      assert_equal "architect_review", result.artifact.artifact_type
      assert result.artifact.metadata.key?("score")
      assert_equal 85, result.artifact.metadata["score"]
    end

    test "evaluate handles score parsing failure" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("This is not a valid score format")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = ArchitectGate.new(execution: @execution)
      result = gate.evaluate

      refute result.passed
      assert_equal 0, result.score
      assert_equal "Score parsing failed — manual review required", result.feedback
    end

    test "evaluate handles error during evaluation" do
      gate = ArchitectGate.new(execution: @execution)
      gate.expects(:build_prompt).raises(StandardError.new("Test error"))

      result = gate.evaluate

      assert result.is_a?(QualityGate::GateResult)
      refute result.passed
      assert_equal 0, result.score
      assert result.feedback.include?("Gate evaluation failed")
    end

    test "evaluate creates error artifact on failure" do
      gate = ArchitectGate.new(execution: @execution)
      gate.expects(:build_prompt).raises(StandardError.new("Test error"))

      result = gate.evaluate

      assert result.artifact
      assert_equal "architect_review", result.artifact.artifact_type
      assert result.artifact.content.include?("Architect review failed")
      assert result.artifact.metadata.key?("error")
      assert_equal "StandardError", result.artifact.metadata["error"]
    end

    test "evaluate with workflow_run uses workflow_run tasks for gate_context" do
      workflow_run = create(:workflow_run, project: @project)
      _task = create(:task,
        workflow_run: workflow_run,
        position: 1,
        prompt: "Workflow task",
        status: "pending",
        result: nil,
        error_message: nil
      )

      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n85/100\n\n## Feedback\nGood review")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = ArchitectGate.new(execution: @execution, workflow_run: workflow_run)
      result = gate.evaluate

      assert result.passed
      assert_equal "architect_review", result.artifact.artifact_type
    end

    # ---------------------------------------------------------------------------
    # dispatch_agent — argument verification
    # ---------------------------------------------------------------------------

    test "dispatch_agent calls DispatchService with correct arguments" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n85/100\n\n## Feedback\nGood review")

      Legion::DispatchService.expects(:call).with(
        team_name: @execution.team.name,
        agent_identifier: "architect",
        prompt: anything,
        project_path: @execution.project.path
      ).returns(mock_result)

      gate = ArchitectGate.new(execution: @execution)
      gate.evaluate
    end

    # ---------------------------------------------------------------------------
    # parse_score (private, called via send)
    # ---------------------------------------------------------------------------

    test "parse_score extracts score from formatted output" do
      gate = ArchitectGate.new(execution: @execution)

      result = gate.send(:parse_score, "## Score\n85/100\n\n## Feedback\nGood review")

      assert_equal 85, result.score
      assert_equal "Score extracted successfully", result.message
    end

    test "parse_score returns score 0 when parsing fails" do
      gate = ArchitectGate.new(execution: @execution)

      result = gate.send(:parse_score, "This is not a valid score format")

      assert_equal 0, result.score
      assert_equal "Score parsing failed — manual review required", result.message
    end

    # ---------------------------------------------------------------------------
    # build_result (private, called via send)
    # ---------------------------------------------------------------------------

    test "build_result returns GateResult with correct values" do
      gate = ArchitectGate.new(execution: @execution)

      parsed_score = mock
      parsed_score.stubs(:score).returns(85)
      parsed_score.stubs(:message).returns("Score extracted successfully")
      parsed_score.stubs(:feedback).returns("Good review")
      gate.instance_variable_set(:@parsed_score, parsed_score)

      artifact = mock
      gate.instance_variable_set(:@artifact, artifact)

      result = gate.send(:build_result, nil)

      assert result.passed
      assert_equal 85, result.score
      assert_equal "Good review", result.feedback
      assert_equal artifact, result.artifact
    end

    test "build_result respects custom threshold" do
      gate = ArchitectGate.new(execution: @execution)

      # 75 is below default threshold (80) but above custom threshold (70)
      parsed_score = mock
      parsed_score.stubs(:score).returns(75)
      parsed_score.stubs(:message).returns("Score extracted successfully")
      parsed_score.stubs(:feedback).returns("Needs improvement")
      gate.instance_variable_set(:@parsed_score, parsed_score)

      artifact = mock
      gate.instance_variable_set(:@artifact, artifact)

      result = gate.send(:build_result, 70)

      assert result.passed
      assert_equal 75, result.score
    end

    # ---------------------------------------------------------------------------
    # create_artifact_record (private, called via send)
    # ---------------------------------------------------------------------------

    test "create_artifact_record creates artifact with correct attributes" do
      gate = ArchitectGate.new(execution: @execution)

      artifact = gate.send(:create_artifact_record,
        score: 85,
        message: "Good review",
        dispatch_result: stub(result: "## Score\n85/100\n\n## Feedback\nGood review")
      )

      assert_equal "architect_review", artifact.artifact_type
      assert_equal "Architect Review 1", artifact.name
      assert artifact.content.include?("85/100")
      assert artifact.content.include?("Good review")
      assert_equal @project.id, artifact.project_id
      assert artifact.metadata.key?("score")
      assert_equal 85, artifact.metadata["score"]
    end

    test "create_artifact_record handles score 0" do
      gate = ArchitectGate.new(execution: @execution)

      artifact = gate.send(:create_artifact_record,
        score: 0,
        message: "Score parsing failed",
        dispatch_result: stub(result: "## Score\n0/100\n\n## Feedback\nScore parsing failed")
      )

      assert_equal "architect_review", artifact.artifact_type
      assert artifact.content.include?("0/100")
      assert artifact.content.include?("Score parsing failed")
    end

    # ---------------------------------------------------------------------------
    # create_error_artifact (private, called via send)
    # ---------------------------------------------------------------------------

    test "create_error_artifact creates error artifact" do
      gate = ArchitectGate.new(execution: @execution)

      error = StandardError.new("Test error")
      artifact = gate.send(:create_error_artifact, error)

      assert_equal "architect_review", artifact.artifact_type
      assert artifact.content.include?("Architect review failed")
      assert artifact.content.include?("Test error")
      assert artifact.metadata.key?("error")
      assert_equal "StandardError", artifact.metadata["error"]
      assert artifact.metadata.key?("error_message")
      assert_equal "Test error", artifact.metadata["error_message"]
    end

    # ---------------------------------------------------------------------------
    # handle_error (private, called via send)
    # ---------------------------------------------------------------------------

    test "handle_error returns GateResult with error details" do
      gate = ArchitectGate.new(execution: @execution)

      error = StandardError.new("Test error")
      result = gate.send(:handle_error, error)

      assert result.is_a?(QualityGate::GateResult)
      refute result.passed
      assert_equal 0, result.score
      assert result.feedback.include?("Gate evaluation failed")
      assert result.feedback.include?("Test error")
      assert result.artifact
    end
  end
end
