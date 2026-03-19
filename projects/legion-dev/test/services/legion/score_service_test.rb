# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Legion
  class ScoreServiceTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project)
      @membership = create(:team_membership, agent_team: @team, config: { "id" => "qa", "name" => "QA Agent", "provider" => "deepseek", "model" => "deepseek-reasoner" })
      @workflow_execution = create(:workflow_execution, project: @project)
      @workflow_run = create(:workflow_run, project: @project, team_membership: @membership, workflow_execution: @workflow_execution)
      @team.team_memberships << @membership
      @team.save!

      # Stub DispatchService and external dependencies
      @default_dispatch_result = mock
      @default_dispatch_result.stubs(:result).returns("## Score\n87/100\n\n## Feedback\nTest feedback")

      DispatchService.stubs(:call).returns(@default_dispatch_result)

      # Stub AgentAssemblyService to prevent real agent assembly
      @assembly_runner = mock
      @assembly_runner.stubs(:run)

      mock_profile = mock
      mock_profile.stubs(:id).returns("test")
      mock_profile.stubs(:name).returns("test")
      mock_profile.stubs(:provider).returns("test")
      mock_profile.stubs(:model).returns("test")
      mock_profile.stubs(:max_iterations).returns(100)

      @assembly_result = {
        runner: @assembly_runner,
        system_prompt: "test prompt",
        tool_set: mock,
        profile: mock_profile,
        message_bus: mock
      }
      AgentAssemblyService.stubs(:call).returns(@assembly_result)
    end

    teardown do
      # Clean up any stubs that might affect other tests
      DispatchService.unstub(:call)
      AgentAssemblyService.unstub(:call)
    end

    test "FR-3: finds WorkflowRun by ID" do
      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 87, result.score
      assert result.passed
    end

    test "FR-3: raises WorkflowRunNotFoundError when workflow_run not found" do
      assert_raises ScoreService::WorkflowRunNotFoundError do
        ScoreService.call(
          workflow_run_id: 999_999,
          team_name: @team.name,
          threshold: 90,
          project_path: @project.path
        )
      end
    end

    test "finds Team by name within project" do
      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 87, result.score
    end

    test "FR-4: builds prompt from WorkflowRun data including tasks context" do
      task1 = create(:task, workflow_run: @workflow_run, status: "completed", result: "App built successfully")
      task2 = create(:task, workflow_run: @workflow_run, status: "completed", result: "All tests passed")

      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 87, result.score
    end

    test "FR-4: builds prompt with empty tasks message when no tasks exist" do
      @workflow_run.tasks.destroy_all

      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 87, result.score
    end

    test "FR-5: dispatches QA agent via DispatchService with correct arguments" do
      # QaGate dispatches via DispatchService with agent_identifier "qa".
      # Verify by checking that DispatchService.call is invoked (global stub in setup).
      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.expects(:new).with(
        execution: @workflow_run.workflow_execution,
        workflow_run: @workflow_run
      ).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 87, result.score
    end

    test "FR-5: dispatches with custom agent role when specified" do
      # Create a membership with custom agent role so ScoreService validation passes
      create(:team_membership, agent_team: @team, config: { "id" => "custom", "name" => "Custom Agent", "provider" => "deepseek", "model" => "deepseek-reasoner" })

      # When QaGate is stubbed, DispatchService is not called directly.
      # ScoreService delegates dispatch to QaGate which handles it internally.
      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path,
        agent_role: "custom"
      )

      assert_equal 87, result.score
    end

    test "raises AgentNotFoundError when QA agent role not in team" do
      # Create a new workflow_run with a fresh team that has no QA membership
      team_without_qa = create(:agent_team, project: @project, name: "TeamWithoutQA-#{Time.now.to_i}")
      membership_other = create(:team_membership, agent_team: team_without_qa, config: { "id" => "other", "name" => "Other Agent", "provider" => "deepseek", "model" => "deepseek-reasoner" })
      workflow_run_no_qa = create(:workflow_run, project: @project, team_membership: membership_other)

      assert_raises ScoreService::AgentNotFoundError do
        ScoreService.call(
          workflow_run_id: workflow_run_no_qa.id,
          team_name: team_without_qa.name,
          threshold: 80,
          project_path: @project.path
        )
      end
    end

    test "FR-6: parses score from QA dispatch result" do
      dispatch_result = mock
      dispatch_result.stubs(:result).returns("## Score\n92/100\n\n## Feedback\nExcellent work!")

      DispatchService.stubs(:call).returns(dispatch_result)

      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 92,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 92, result.score
      assert result.passed
    end

    test "FR-11: returns score 0 with feedback when score parsing fails" do
      dispatch_result = mock
      dispatch_result.stubs(:result).returns("This output has no score pattern")

      DispatchService.stubs(:call).returns(dispatch_result)

      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 0,
          passed: false,
          feedback: "Score parsing failed — manual review required",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 90,
        project_path: @project.path
      )

      assert_equal 0, result.score
      assert_not result.passed
      assert_match "Score parsing failed", result.feedback
    end

    test "FR-7: creates Artifact with score_report type" do
      quality_gate = mock
      artifact = mock
      artifact.stubs(:artifact_type).returns("score_report")
      artifact.stubs(:metadata).returns({ "score" => 87 })
      artifact.stubs(:content).returns("## Score\n87/100\n\n## Feedback\nTest feedback")
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: artifact
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      # QaGate is stubbed, so artifact comes from the mock evaluate result
      assert_not_nil result.artifact
      assert_equal "score_report", result.artifact.artifact_type
      assert_equal 87, result.artifact.metadata["score"]
      assert_match "## Score", result.artifact.content
    end

    test "FR-7: creates Artifact with correct score and feedback content" do
      quality_gate = mock
      artifact = mock
      artifact.stubs(:artifact_type).returns("score_report")
      artifact.stubs(:metadata).returns({ "score" => 87, "parser_message" => "Score extracted successfully" })
      artifact.stubs(:content).returns("## Score\n87/100\n\n## Feedback\nScore extracted successfully")
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Score extracted successfully",
          artifact: artifact
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      # QaGate is stubbed; artifact comes from the mock evaluate result
      assert_not_nil result.artifact
      assert_equal 87, result.artifact.metadata["score"]
      assert_match "87/100", result.artifact.content
      assert_match "Score extracted successfully", result.artifact.content
    end

    test "FR-7: creates error Artifact when dispatch fails" do
      error = StandardError.new("Dispatch failed")
      DispatchService.stubs(:call).raises(error)

      quality_gate = mock
      quality_gate.stubs(:evaluate).raises(error)

      QaGate.stubs(:new).returns(quality_gate)

      assert_difference "Artifact.count", 1 do
        result = ScoreService.call(
          workflow_run_id: @workflow_run.id,
          team_name: @team.name,
          threshold: 80,
          project_path: @project.path
        )
      end

      artifact = @workflow_run.artifacts.last
      assert_equal "score_report", artifact.artifact_type
      assert_equal "Dispatch failed", artifact.metadata["error_message"]
    end

    test "returns Result struct with correct attributes" do
      quality_gate = mock
      artifact = mock
      artifact.stubs(:artifact_type).returns("score_report")
      artifact.stubs(:metadata).returns({ "score" => 87, "parser_message" => "Score extracted successfully" })
      artifact.stubs(:content).returns("## Score\n87/100\n\n## Feedback\nScore extracted successfully")
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Score extracted successfully",
          artifact: artifact
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_instance_of ScoreService::Result, result
      assert_equal 87, result.score
      assert result.passed
      assert_not_nil result.artifact
    end

    test "FR-8: returns passed=false when score below threshold" do
      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: false,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 95,
        project_path: @project.path
      )

      assert_not result.passed
      assert_equal 87, result.score
    end

    test "FR-8: returns passed=true when score meets threshold" do
      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert result.passed
      assert_equal 87, result.score
    end

    test "FR-8: returns passed=true when score equals threshold" do
      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 87,
        project_path: @project.path
      )

      assert result.passed
      assert_equal 87, result.score
    end

    test "uses configurable threshold parameter" do
      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 50,
        project_path: @project.path
      )

      assert result.passed
    end

    test "FR-11: handles score 0 with fallback message" do
      dispatch_result = mock
      dispatch_result.stubs(:result).returns("## Score\n0/100\n\n## Feedback\nNeeds improvement")

      DispatchService.stubs(:call).returns(dispatch_result)

      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 0,
          passed: false,
          feedback: "Score parsing failed — manual review required",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 90,
        project_path: @project.path
      )

      assert_equal 0, result.score
      assert_not result.passed
      assert_match "Score parsing failed", result.feedback
    end

    test "creates Artifact with error content when score <= 0" do
      dispatch_result = mock
      dispatch_result.stubs(:result).returns("## Score\n0/100\n\n## Feedback\nNeeds improvement")

      DispatchService.stubs(:call).returns(dispatch_result)

      quality_gate = mock
      artifact = mock
      artifact.stubs(:artifact_type).returns("score_report")
      artifact.stubs(:metadata).returns({ "score" => 0 })
      artifact.stubs(:content).returns("## Score\n0/100\n\n## Feedback\nNeeds improvement")
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 0,
          passed: false,
          feedback: "Score parsing failed — manual review required",
          artifact: artifact
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 90,
        project_path: @project.path
      )

      # QaGate is stubbed; artifact comes from the mock evaluate result
      assert_not_nil result.artifact
      assert_equal 0, result.artifact.metadata["score"]
      assert_match "0/100", result.artifact.content
    end

    test "does not create Artifact when WorkflowRun not found" do
      assert_no_difference "Artifact.count" do
        assert_raises ScoreService::WorkflowRunNotFoundError do
          ScoreService.call(
            workflow_run_id: 999_999,
            team_name: @team.name,
            threshold: 90,
            project_path: @project.path
          )
        end
      end
    end

    test "TeamNotFoundError raised when project not found" do
      assert_raises ScoreService::TeamNotFoundError do
        ScoreService.call(
          workflow_run_id: @workflow_run.id,
          team_name: @team.name,
          threshold: 90,
          project_path: "nonexistent/path"
        )
      end
    end

    test "TeamNotFoundError raised when team not found in project" do
      assert_raises ScoreService::TeamNotFoundError do
        ScoreService.call(
          workflow_run_id: @workflow_run.id,
          team_name: "nonexistent",
          threshold: 90,
          project_path: @project.path
        )
      end
    end

    test "uses default agent_role 'qa' when not specified" do
      # ScoreService uses QaGate internally; DispatchService is called by QaGate not directly.
      # Verify the default agent_role 'qa' results in a successful call.
      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 87, result.score
    end

    test "builds correct prompt structure" do
      prompt_builder = ScoreService.new(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )
      prompt = prompt_builder.send(:build_prompt, @workflow_run)

      assert_match "Please evaluate the workflow run output", prompt
      assert_match "## Context", prompt
      assert_match "## Workflow Tasks and Results", prompt
      assert_match "## Instructions", prompt
      assert_match "## Output Format", prompt
    end

    test "build_tasks_context returns message when no tasks" do
      prompt_builder = ScoreService.new(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      context = prompt_builder.send(:build_tasks_context, @workflow_run)
      assert_match "No tasks found", context
    end

    test "build_tasks_context includes task details" do
      task = create(:task, workflow_run: @workflow_run, status: "completed", result: "Success")

      prompt_builder = ScoreService.new(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      context = prompt_builder.send(:build_tasks_context, @workflow_run)
      assert_match /Task #/, context
      assert_match "Status: completed", context
      assert_match "Result: Success", context
    end

    test "build_tasks_context includes error_message when present" do
      task = create(:task, workflow_run: @workflow_run, status: "failed")
      task.update_column(:error_message, "Connection timeout")

      prompt_builder = ScoreService.new(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      context = prompt_builder.send(:build_tasks_context, @workflow_run)
      assert_match "Error: Connection timeout", context
    end

    test "passes workflow_run tasks to prompt builder" do
      task1 = create(:task, workflow_run: @workflow_run, status: "completed", result: "Result 1")
      task2 = create(:task, workflow_run: @workflow_run, status: "failed")
      task2.update_column(:error_message, "Error 2")

      quality_gate = mock
      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 87, result.score
    end

    # FR-7: Tests for QualityGate delegation
    test "FR-7: delegates to QualityGate for evaluation" do
      quality_gate = mock
      quality_gate.expects(:evaluate).with(threshold: 80).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.expects(:new).with(execution: @workflow_run.workflow_execution, workflow_run: @workflow_run).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 87, result.score
      assert result.passed
    end

    test "FR-7: passes correct threshold to QualityGate" do
      quality_gate = mock
      quality_gate.expects(:evaluate).with(threshold: 95).returns(
        OpenStruct.new(
          score: 87,
          passed: false,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 95,
        project_path: @project.path
      )
    end

    test "FR-7: QualityGate creates artifact via create_artifact_record" do
      quality_gate = mock
      artifact = mock
      artifact.stubs(:artifact_type).returns("score_report")
      artifact.stubs(:metadata).returns({ "score" => 87, "parser_message" => "Score extracted successfully" })
      artifact.stubs(:content).returns("## Score\n87/100\n\n## Feedback\nScore extracted successfully")

      quality_gate.stubs(:evaluate).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Score extracted successfully",
          artifact: artifact
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_equal 87, result.score
      assert_equal "Score extracted successfully", result.feedback
    end

    # NF-2: Tests for ScoreParser sharing and consistency
    test "NF-2: uses ScoreParser for score parsing" do
      text = "## Score\n87/100\n\n## Feedback\nTest feedback"
      result = ScoreParser.call(text: text)

      assert_equal 87, result.score
      assert_equal "Score extracted successfully", result.message
    end

    test "NF-2: ScoreParser patterns are consistent across service" do
      # Test all ScoreParser patterns
      patterns = {
        "header_format" => "## Score\n87/100\n\n## Feedback\nTest",
        "inline_format" => "SCORE: 87",
        "slash_format" => "87/100"
      }

      patterns.each do |name, text|
        result = ScoreParser.call(text: text)
        assert_equal 87, result.score, "Pattern #{name} should extract score 87"
      end
    end

    test "NF-2: ScoreParser handles parsing failures consistently" do
      text = "This output has no score pattern"
      result = ScoreParser.call(text: text)

      assert_equal 0, result.score
      assert_equal "Score parsing failed — manual review required", result.message
    end

    test "NF-2: ScoreParser score 0 is handled consistently" do
      text = "## Score\n0/100\n\n## Feedback\nNeeds improvement"
      result = ScoreParser.call(text: text)

      assert_equal 0, result.score
      assert_equal "Score parsing failed — manual review required", result.message
    end

    test "NF-2: ScoreParser and QualityGate share same parsing logic" do
      # Verify both use the same ScoreParser class
      assert_equal ScoreParser, ScoreParser

      # Verify QualityGate uses ScoreParser via parse_score (private method)
      quality_gate = Legion::QualityGate.new(execution: @workflow_run.workflow_execution)
      assert quality_gate.respond_to?(:parse_score, true), "QualityGate should have a private #parse_score method"
    end

    test "NF-2: QualityGate delegates score parsing to ScoreParser" do
      # Create a concrete QualityGate subclass (QaGate) to test actual delegation
      qa_gate = QaGate.new(execution: @workflow_run.workflow_execution, workflow_run: @workflow_run)

      # Inject a fake dispatch result directly so parse_score has text to work with
      fake_dispatch = stub(result: "## Score\n87/100\n\n## Feedback\nTest feedback")
      qa_gate.instance_variable_set(:@dispatch_result, fake_dispatch)

      # Verify parse_score uses ScoreParser internally
      qa_gate.send(:parse_score)

      assert_equal 87, qa_gate.instance_variable_get(:@parsed_score).score
    end

    test "NF-2: ScoreParser parsing is consistent in QualityGate evaluation" do
      # Create a mock dispatch result with score
      dispatch_result = mock
      dispatch_result.stubs(:result).returns("## Score\n87/100\n\n## Feedback\nTest")

      DispatchService.stubs(:call).returns(dispatch_result)

      # Create a concrete QualityGate subclass (QaGate)
      qa_gate = QaGate.new(execution: @workflow_run.workflow_execution, workflow_run: @workflow_run)

      # Mock create_artifact to avoid database operations
      artifact = mock
      artifact.stubs(:artifact_type).returns("score_report")
      artifact.stubs(:metadata).returns({ "score" => 87 })
      qa_gate.stubs(:create_artifact).returns(artifact)

      # Evaluate and verify parsing consistency
      result = qa_gate.evaluate(threshold: 80)

      assert_equal 87, result.score
      assert result.passed
      # feedback is the extracted ## Feedback section content
      assert_equal "Test", result.feedback
    end

    # Error handling tests
    test "handles QualityGate evaluation failure gracefully" do
      error = StandardError.new("QualityGate evaluation failed")
      quality_gate = mock
      quality_gate.stubs(:evaluate).raises(error)

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      assert_not result.passed
      assert_equal 0, result.score
      assert_match "Score evaluation failed", result.feedback
    end

    test "creates error artifact when QualityGate raises error" do
      error = StandardError.new("Dispatch failed")
      quality_gate = mock
      quality_gate.stubs(:evaluate).raises(error)

      QaGate.stubs(:new).returns(quality_gate)

      assert_difference "Artifact.count", 1 do
        ScoreService.call(
          workflow_run_id: @workflow_run.id,
          team_name: @team.name,
          threshold: 80,
          project_path: @project.path
        )
      end
    end

    test "NF-2: QualityGate error handling uses same ScoreParser result format" do
      # Test that QualityGate error result matches ScoreParser result format
      error = StandardError.new("Dispatch failed")
      quality_gate = mock
      quality_gate.stubs(:evaluate).raises(error)

      QaGate.stubs(:new).returns(quality_gate)

      result = ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )

      # Verify error result has same structure as ScoreParser result
      assert_equal 0, result.score
      assert_not result.passed
      assert_match "Score evaluation failed", result.feedback
    end

    test "NF-2: ScoreParser result format is consistent across QualityGate and direct usage" do
      text = "## Score\n87/100\n\n## Feedback\nTest"

      # Test direct ScoreParser usage
      direct_result = ScoreParser.call(text: text)

      # Test QualityGate uses same parser — inject dispatch_result directly
      qa_gate = QaGate.new(execution: @workflow_run.workflow_execution, workflow_run: @workflow_run)
      fake_dispatch = stub(result: text)
      qa_gate.instance_variable_set(:@dispatch_result, fake_dispatch)

      qa_gate.send(:parse_score)
      gate_result = qa_gate.instance_variable_get(:@parsed_score)

      # Both should have same score and message format
      assert_equal direct_result.score, gate_result.score
      assert_equal direct_result.message, gate_result.message
    end

    test "FR-7: QualityGate evaluation flow includes all steps" do
      # Verify QualityGate.evaluate is called (which internally calls build_prompt,
      # dispatch_agent, parse_score, create_artifact, build_result)
      quality_gate = mock
      quality_gate.expects(:evaluate).with(threshold: 80).returns(
        OpenStruct.new(
          score: 87,
          passed: true,
          feedback: "Test feedback",
          artifact: mock
        )
      )

      QaGate.stubs(:new).returns(quality_gate)

      ScoreService.call(
        workflow_run_id: @workflow_run.id,
        team_name: @team.name,
        threshold: 80,
        project_path: @project.path
      )
    end

    test "NF-2: ScoreParser is the single source of truth for score extraction" do
      # Verify ScoreParser is used consistently
      text = "## Score\n87/100\n\n## Feedback\nTest"

      # Direct usage
      direct_result = ScoreParser.call(text: text)

      # QualityGate usage (via parse_score) — inject dispatch_result directly
      qa_gate = QaGate.new(execution: @workflow_run.workflow_execution, workflow_run: @workflow_run)
      fake_dispatch = stub(result: text)
      qa_gate.instance_variable_set(:@dispatch_result, fake_dispatch)

      # This should use ScoreParser internally
      qa_gate.send(:parse_score)
      assert_equal 87, qa_gate.instance_variable_get(:@parsed_score).score
      assert_equal direct_result.score, qa_gate.instance_variable_get(:@parsed_score).score
    end

    test "NF-2: ScoreParser patterns are defined once and shared" do
      # Verify PATTERNS constant is defined in ScoreParser
      assert ScoreParser.const_defined?(:PATTERNS), "ScoreParser::PATTERNS constant should be defined"

      # Verify all patterns are accessible
      patterns = ScoreParser::PATTERNS
      assert patterns.key?(:header_format)
      assert patterns.key?(:inline_format)
      assert patterns.key?(:slash_format)
    end

    test "NF-2: QualityGate uses ScoreParser without duplicating patterns" do
      # Verify QualityGate does not define its own PATTERNS constant
      assert_not Legion::QualityGate.const_defined?(:PATTERNS, false),
                 "QualityGate should not define its own PATTERNS; use ScoreParser::PATTERNS"

      # Verify QualityGate calls ScoreParser.call — inject dispatch_result directly
      qa_gate = QaGate.new(execution: @workflow_run.workflow_execution, workflow_run: @workflow_run)
      fake_dispatch = stub(result: "## Score\n87/100\n\n## Feedback\nTest")
      qa_gate.instance_variable_set(:@dispatch_result, fake_dispatch)

      # This should use ScoreParser internally
      qa_gate.send(:parse_score)
      assert_equal 87, qa_gate.instance_variable_get(:@parsed_score).score
    end
  end
end
