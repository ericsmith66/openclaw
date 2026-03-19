# frozen_string_literal: true

require "test_helper"

module Legion
  class QaGateTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project)
      @team_membership = create(:team_membership, agent_team: @team)
      @workflow_run = create(:workflow_run, project: @project, team_membership: @team_membership)
      @execution = create(:workflow_execution, project: @project)
      # Associate the workflow_run with the execution so QaGate can access it
      @workflow_run.update!(workflow_execution: @execution)

      # Stub DispatchService so evaluate never hits real agent infrastructure.
      # Individual tests that care about the result override this stub locally.
      @default_dispatch_result = mock("dispatch_result")
      @default_dispatch_result.stubs(:result).returns("")
      Legion::DispatchService.stubs(:call).returns(@default_dispatch_result)

      # Stub lower-level agent infrastructure (precautionary)
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
      gate = QaGate.new(execution: @execution)

      assert_equal @execution, gate.instance_variable_get(:@execution)
      assert_nil gate.instance_variable_get(:@workflow_run)
    end

    # ---------------------------------------------------------------------------
    # Subclass contract
    # ---------------------------------------------------------------------------

    test "gate_name returns 'qa'" do
      gate = QaGate.new(execution: @execution)

      assert_equal "qa", gate.gate_name
    end

    test "prompt_template_phase returns :qa_score" do
      gate = QaGate.new(execution: @execution)

      assert_equal :qa_score, gate.prompt_template_phase
    end

    test "agent_role returns 'qa'" do
      gate = QaGate.new(execution: @execution)

      assert_equal "qa", gate.agent_role
    end

    test "default_threshold returns 90" do
      gate = QaGate.new(execution: @execution)

      assert_equal 90, gate.default_threshold
    end

    # ---------------------------------------------------------------------------
    # gate_context (inherited from QualityGate)
    # ---------------------------------------------------------------------------

    test "gate_context includes task_results" do
      gate = QaGate.new(execution: @execution)
      context = gate.gate_context

      assert context.key?(:task_results)
    end

    test "gate_context includes prd_content" do
      gate = QaGate.new(execution: @execution)
      context = gate.gate_context

      assert context.key?(:prd_content)
      assert_equal @project.prd_content, context[:prd_content]
    end

    test "gate_context includes acceptance_criteria" do
      gate = QaGate.new(execution: @execution)
      context = gate.gate_context

      assert context.key?(:acceptance_criteria)
      assert_equal @project.acceptance_criteria, context[:acceptance_criteria]
    end

    test "gate_context task_results returns empty array when no tasks" do
      gate = QaGate.new(execution: @execution)
      context = gate.gate_context

      assert_equal [], context[:task_results]
    end

    test "gate_context task_results returns task data" do
      _task = create(:task,
        workflow_execution: @execution,
        position: 1,
        prompt: "Test task prompt",
        status: "completed",
        result: "Test result",
        error_message: nil
      )

      gate = QaGate.new(execution: @execution)
      context = gate.gate_context

      assert_equal 1, context[:task_results].size
      assert_equal 1, context[:task_results].first[:position]
      assert_equal "Test task prompt", context[:task_results].first[:prompt]
      assert_equal "completed", context[:task_results].first[:status]
      assert_equal "Test result", context[:task_results].first[:result]
    end

    # ---------------------------------------------------------------------------
    # evaluate — method dispatch (uses default DispatchService stub)
    # ---------------------------------------------------------------------------

    test "evaluate calls build_prompt" do
      gate = QaGate.new(execution: @execution)
      gate.expects(:build_prompt)

      gate.evaluate
    end

    test "evaluate calls dispatch_agent" do
      gate = QaGate.new(execution: @execution)
      gate.expects(:dispatch_agent)

      gate.evaluate
    end

    test "evaluate calls parse_score" do
      gate = QaGate.new(execution: @execution)
      gate.expects(:parse_score)

      gate.evaluate
    end

    test "evaluate calls create_artifact" do
      gate = QaGate.new(execution: @execution)
      gate.expects(:create_artifact)

      gate.evaluate
    end

    test "evaluate calls build_result" do
      gate = QaGate.new(execution: @execution)
      gate.expects(:build_result)

      gate.evaluate
    end

    # ---------------------------------------------------------------------------
    # evaluate — result correctness (each test stubs DispatchService locally)
    # ---------------------------------------------------------------------------

    test "evaluate returns GateResult with passed status" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n92/100\n\n## Feedback\nExcellent coverage")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = QaGate.new(execution: @execution)
      result = gate.evaluate

      assert result.is_a?(QualityGate::GateResult)
      assert result.passed
      assert_equal 92, result.score
      assert_equal "Excellent coverage", result.feedback
      assert result.artifact
    end

    test "evaluate returns GateResult with failed status when score below threshold" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n85/100\n\n## Feedback\nMissing edge case tests")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = QaGate.new(execution: @execution)
      result = gate.evaluate

      assert result.is_a?(QualityGate::GateResult)
      refute result.passed
      assert_equal 85, result.score
    end

    test "evaluate uses custom threshold when provided" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n88/100\n\n## Feedback\nGood coverage")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = QaGate.new(execution: @execution)
      result = gate.evaluate(threshold: 85)

      assert result.passed
      assert_equal 88, result.score
    end

    test "evaluate creates artifact with artifact_type 'score_report'" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n92/100\n\n## Feedback\nExcellent coverage")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = QaGate.new(execution: @execution)
      result = gate.evaluate

      assert_equal "score_report", result.artifact.artifact_type
    end

    test "evaluate creates artifact with score in metadata" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n92/100\n\n## Feedback\nExcellent coverage")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = QaGate.new(execution: @execution)
      result = gate.evaluate

      assert result.artifact.metadata.key?("score")
      assert_equal 92, result.artifact.metadata["score"]
    end

    test "evaluate handles score parsing failure" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("This is not a valid score format")
      Legion::DispatchService.stubs(:call).returns(mock_result)

      gate = QaGate.new(execution: @execution)
      result = gate.evaluate

      refute result.passed
      assert_equal 0, result.score
      assert_equal "Score parsing failed — manual review required", result.feedback
    end

    test "evaluate handles error during evaluation" do
      gate = QaGate.new(execution: @execution)
      gate.expects(:build_prompt).raises(StandardError.new("Test error"))

      result = gate.evaluate

      assert result.is_a?(QualityGate::GateResult)
      refute result.passed
      assert_equal 0, result.score
      assert result.feedback.include?("Gate evaluation failed")
    end

    test "evaluate creates error artifact on failure" do
      gate = QaGate.new(execution: @execution)
      gate.expects(:build_prompt).raises(StandardError.new("Test error"))

      result = gate.evaluate

      assert result.artifact
      assert_equal "score_report", result.artifact.artifact_type
      assert result.artifact.content.include?("Score evaluation failed")
      assert result.artifact.metadata.key?("error")
      assert_equal "StandardError", result.artifact.metadata["error"]
    end

    # ---------------------------------------------------------------------------
    # dispatch_agent — argument verification
    # ---------------------------------------------------------------------------

    test "dispatch_agent calls DispatchService with correct arguments" do
      mock_result = mock("workflow_run_result")
      mock_result.stubs(:result).returns("## Score\n92/100\n\n## Feedback\nExcellent coverage")

      Legion::DispatchService.expects(:call).with(
        team_name: @execution.team.name,
        agent_identifier: "qa",
        prompt: anything,
        project_path: @execution.project.path
      ).returns(mock_result)

      gate = QaGate.new(execution: @execution)
      gate.evaluate
    end

    # ---------------------------------------------------------------------------
    # parse_score (private, called via send — inherited from QualityGate)
    # ---------------------------------------------------------------------------

    test "parse_score extracts score from formatted output" do
      gate = QaGate.new(execution: @execution)

      result = gate.send(:parse_score, "## Score\n92/100\n\n## Feedback\nExcellent coverage")

      assert_equal 92, result.score
      assert_equal "Score extracted successfully", result.message
    end

    test "parse_score returns score 0 when parsing fails" do
      gate = QaGate.new(execution: @execution)

      result = gate.send(:parse_score, "This is not a valid score format")

      assert_equal 0, result.score
      assert_equal "Score parsing failed — manual review required", result.message
    end

    # ---------------------------------------------------------------------------
    # build_result (private, called via send — inherited from QualityGate)
    # ---------------------------------------------------------------------------

    test "build_result returns GateResult with correct values" do
      gate = QaGate.new(execution: @execution)

      parsed_score = mock
      parsed_score.stubs(:score).returns(92)
      parsed_score.stubs(:message).returns("Score extracted successfully")
      parsed_score.stubs(:feedback).returns("Excellent coverage")
      gate.instance_variable_set(:@parsed_score, parsed_score)

      artifact = mock
      gate.instance_variable_set(:@artifact, artifact)

      result = gate.send(:build_result, nil)

      assert result.passed
      assert_equal 92, result.score
      assert_equal "Excellent coverage", result.feedback
      assert_equal artifact, result.artifact
    end

    test "build_result fails when score below default threshold" do
      gate = QaGate.new(execution: @execution)

      parsed_score = mock
      parsed_score.stubs(:score).returns(85)
      parsed_score.stubs(:message).returns("Score extracted successfully")
      parsed_score.stubs(:feedback).returns("Missing tests")
      gate.instance_variable_set(:@parsed_score, parsed_score)

      artifact = mock
      gate.instance_variable_set(:@artifact, artifact)

      result = gate.send(:build_result, nil)

      refute result.passed
      assert_equal 85, result.score
    end

    test "build_result respects custom threshold" do
      gate = QaGate.new(execution: @execution)

      # 88 is below default threshold (90) but above custom threshold (85)
      parsed_score = mock
      parsed_score.stubs(:score).returns(88)
      parsed_score.stubs(:message).returns("Score extracted successfully")
      parsed_score.stubs(:feedback).returns("Good coverage")
      gate.instance_variable_set(:@parsed_score, parsed_score)

      artifact = mock
      gate.instance_variable_set(:@artifact, artifact)

      result = gate.send(:build_result, 85)

      assert result.passed
      assert_equal 88, result.score
    end

    # ---------------------------------------------------------------------------
    # create_artifact_record (private, called via send)
    # ---------------------------------------------------------------------------

    test "create_artifact_record creates artifact with correct attributes" do
      gate = QaGate.new(execution: @execution)

      artifact = gate.send(:create_artifact_record,
        score: 92,
        message: "Excellent coverage",
        dispatch_result: stub(result: "## Score\n92/100\n\n## Feedback\nExcellent coverage")
      )

      assert_equal "score_report", artifact.artifact_type
      assert_equal "Score Report 1", artifact.name
      assert artifact.content.include?("92/100")
      assert artifact.content.include?("Excellent coverage")
      assert_equal @project.id, artifact.project_id
      assert artifact.metadata.key?("score")
      assert_equal 92, artifact.metadata["score"]
    end

    test "create_artifact_record handles score 0" do
      gate = QaGate.new(execution: @execution)

      artifact = gate.send(:create_artifact_record,
        score: 0,
        message: "Score parsing failed",
        dispatch_result: stub(result: "## Score\n0/100\n\n## Feedback\nScore parsing failed")
      )

      assert_equal "score_report", artifact.artifact_type
      assert artifact.content.include?("0/100")
      assert artifact.content.include?("Score parsing failed")
    end

    # ---------------------------------------------------------------------------
    # create_error_artifact (private, called via send)
    # ---------------------------------------------------------------------------

    test "create_error_artifact creates error artifact" do
      gate = QaGate.new(execution: @execution)

      error = StandardError.new("Test error")
      artifact = gate.send(:create_error_artifact, error)

      assert_equal "score_report", artifact.artifact_type
      assert artifact.content.include?("Score evaluation failed")
      assert artifact.content.include?("Test error")
      assert artifact.metadata.key?("error")
      assert_equal "StandardError", artifact.metadata["error"]
      assert artifact.metadata.key?("error_message")
      assert_equal "Test error", artifact.metadata["error_message"]
    end

    # ---------------------------------------------------------------------------
    # handle_error (private, called via send — inherited from QualityGate)
    # ---------------------------------------------------------------------------

    test "handle_error returns GateResult with error details" do
      gate = QaGate.new(execution: @execution)

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
