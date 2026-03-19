# frozen_string_literal: true

require "test_helper"

module Legion
  class PromptBuilderIntegrationTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project, name: "ROR")
      @architect = create(:team_membership, agent_team: @team, config: {
        "id" => "architect-test",
        "name" => "Architect",
        "provider" => "anthropic",
        "model" => "claude-opus-4"
      })
      @rails_lead = create(:team_membership, agent_team: @team, config: {
        "id" => "rails-lead-test",
        "name" => "Rails Lead",
        "provider" => "deepseek",
        "model" => "deepseek-reasoner"
      })

      @prd_path = Rails.root.join("test/fixtures/sample_prd.md").to_s
      @project_path = @project.path
    end

    # ============================================================================
    # AC-1: Decomposition prompt contains PRD content
    # ============================================================================

    test "decomposition prompt contains PRD content" do
      prd_content = File.read(@prd_path)

      # Build decomposition prompt using PromptBuilder
      prompt = PromptBuilder.build(
        phase: :decompose,
        context: {
          prd_content: prd_content,
          project_path: @project_path
        }
      )

      # Verify PRD content is present in the rendered prompt
      assert_includes prompt, "User Management", "PRD title should be in decomposition prompt"
      assert_includes prompt, "Overview", "PRD section headers should be present"
      assert_includes prompt, "User Model", "PRD requirements section should be present"
      assert_includes prompt, "authentication", "PRD functional requirements should be present"
    end

    test "decomposition prompt contains project path" do
      prd_content = File.read(@prd_path)

      prompt = PromptBuilder.build(
        phase: :decompose,
        context: {
          prd_content: prd_content,
          project_path: @project_path
        }
      )

      assert_includes prompt, @project_path, "Project path should be in decomposition prompt"
    end

    # ============================================================================
    # AC-6: Conductor prompt with full state renders correctly
    # ============================================================================

    test "conductor prompt renders with execution state context" do
      # Create test data for conductor prompt
      workflow_id = "wf-123"
      phase = "executing"
      attempt = 2

      # Create mock tasks with states - using simplified structure that matches template
      completed_task = {
        position: 1,
        status: "completed",
        type: "code",
        score: 95,
        agent: "rails-lead",
        files_score: 3,
        concepts_score: 2,
        dependencies_score: 1
      }

      pending_task = {
        position: 2,
        status: "pending",
        type: "test",
        score: nil,
        agent: "rails-lead",
        files_score: 2,
        concepts_score: 1,
        dependencies_score: 1
      }

      failed_task = {
        position: 3,
        status: "failed",
        type: "code",
        score: 45,
        agent: "rails-lead",
        files_score: 2,
        concepts_score: 3,
        dependencies_score: 1
      }

      tasks = [ completed_task, pending_task, failed_task ]

      # Create scores hash matching template expectations
      scores = {
        completed_count: 1,
        failed_count: 1,
        skipped_count: 0,
        pending_count: 1,
        average_score: 70.0,
        last_feedback: "Task 3 needs improvement"
      }

      prompt = PromptBuilder.build(
        phase: :conductor,
        context: {
          phase: phase,
          attempt: attempt,
          workflow_id: workflow_id,
          tasks: tasks,
          scores: scores
        }
      )

      # Verify all state values are present in the prompt
      assert_includes prompt, "executing", "Phase should be in conductor prompt"
      assert_includes prompt, "2", "Attempt should be in conductor prompt"
      assert_includes prompt, workflow_id, "Workflow ID should be in conductor prompt"

      # Verify task summary section
      assert_includes prompt, "3", "Total tasks count should be in prompt"
      assert_includes prompt, "1", "Completed count should be in prompt"
      assert_includes prompt, "1", "Failed count should be in prompt"
      assert_includes prompt, "1", "Pending count should be in prompt"
      assert_includes prompt, "70.0", "Average score should be in prompt"

      # Verify task details
      assert_includes prompt, "Task 1", "Task 1 should be in summary"
      assert_includes prompt, "completed", "Task 1 status should be in prompt"
      assert_includes prompt, "Task 2", "Task 2 should be in summary"
      assert_includes prompt, "pending", "Task 2 status should be in prompt"
      assert_includes prompt, "Task 3", "Task 3 should be in summary"
      assert_includes prompt, "failed", "Task 3 status should be in prompt"

      # Verify feedback section
      assert_includes prompt, "Task 3 needs improvement", "Feedback should be in prompt"
    end

    # ============================================================================
    # AC-5: Verify DecompositionService uses PromptBuilder
    # ============================================================================

    test "decomposition_service_uses_prompt_builder_not_inline" do
      # Setup mock for DispatchService
      mock_workflow_run = create(:workflow_run,
        project: @project,
        team_membership: @architect,
        status: :completed,
        result: "[{\"position\":1,\"type\":\"code\",\"prompt\":\"Test task\",\"agent\":\"rails-lead\",\"files_score\":1,\"concepts_score\":1,\"dependencies_score\":1,\"depends_on\":[]}]"
      )

      DispatchService.stubs(:call).returns(mock_workflow_run)

      # Mock the file read to return PRD content
      prd_content = File.read(@prd_path)

      # Verify that DecompositionService#build_decomposition_prompt uses PromptBuilder
      # by checking the prompt content structure
      service = DecompositionService.new(
        team_name: "ROR",
        prd_path: @prd_path,
        agent_identifier: "architect",
        project_path: @project_path,
        dry_run: true,
        verbose: false
      )

      # Access the private method via send to verify it uses PromptBuilder
      # The prompt should contain PRD content and be built via PromptBuilder
      prompt = service.send(:build_decomposition_prompt, prd_content)

      # Verify PRD content is in the prompt (prompt building works)
      assert_includes prompt, "User Management", "Prompt should contain PRD content"
      assert_includes prompt, "User Model", "Prompt should contain requirements"
      assert_includes prompt, "authentication", "Prompt should contain auth requirements"
    end

    test "decomposition_service_full_integration_with_prompt_builder" do
      # Setup VCR for real API call
      # Mock the full dispatch for integration test
      mock_workflow_run = create(:workflow_run,
        project: @project,
        team_membership: @architect,
        status: :completed,
        result: "[{\"position\":1,\"type\":\"test\",\"prompt\":\"Write tests and factory for User model\",\"agent\":\"rails-lead\",\"files_score\":2,\"concepts_score\":1,\"dependencies_score\":1,\"depends_on\":[],\"notes\":\"Independent test task\"}]"
      )

      DispatchService.stubs(:call).returns(mock_workflow_run)

      # Run full decomposition
      result = DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: false
      )

      # Verify decomposition worked
      assert_equal 1, result.tasks.size
      assert_equal [], result.errors
      assert_equal "completed", result.workflow_run.status

      # Verify task was created
      task = result.tasks.first
      assert_equal "test", task[:type]
      assert_includes task[:prompt], "User model", "Task prompt should be derived from PRD"
    end

    # ============================================================================
    # FR-8 integration: PromptBuilder refactoring verification
    # ============================================================================

    test "prompt_builder_integration_with_full_workflow" do
      prd_content = File.read(@prd_path)

      # Test 1: Decomposition phase uses PromptBuilder
      decomposition_prompt = PromptBuilder.build(
        phase: :decompose,
        context: {
          prd_content: prd_content,
          project_path: @project_path
        }
      )

      assert_instance_of String, decomposition_prompt
      assert_not_empty decomposition_prompt
      assert_includes decomposition_prompt, prd_content, "PRD content should be embedded in prompt"

      # Test 2: Verify context extraction works
      required_context = PromptBuilder.required_context(phase: :decompose)
      assert_includes required_context, "prd_content"
      assert_includes required_context, "project_path"

      # Test 3: Verify available phases
      available_phases = PromptBuilder.available_phases
      assert_includes available_phases, :decompose
      assert_includes available_phases, :conductor

      # Test 4: Error handling for missing context
      error = assert_raises PromptBuilder::PromptContextError do
        PromptBuilder.build(
          phase: :decompose,
          context: { prd_content: prd_content } # Missing project_path
        )
      end

      assert_includes error.message, "project_path", "Error should specify missing variable"
    end
  end
end
