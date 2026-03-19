# frozen_string_literal: true

require "test_helper"

module Legion
  class DecompositionIntegrationTest < ActiveSupport::TestCase
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

      # Mock the full dispatch for integration test
      # In real scenario, this would use VCR
      mock_workflow_run = create(:workflow_run,
        project: @project,
        team_membership: @architect,
        status: :completed,
        result: architect_response_json
      )

      DispatchService.stubs(:call).returns(mock_workflow_run)
    end

    def architect_response_json
      # Simulated Architect response for User model PRD
      [
        {
          position: 1,
          type: "test",
          prompt: "Write tests and factory for User model: name (required), email (required, unique, format validation), password_digest. Test validations, has_secure_password, factory validity.",
          agent: "rails-lead",
          files_score: 2,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [],
          notes: "Independent test task — parallel eligible"
        },
        {
          position: 2,
          type: "code",
          prompt: "Create User model and migration to make tests from Task 1 pass. Fields: name (string, required), email (string, required, unique), password_digest. Add has_secure_password.",
          agent: "rails-lead",
          files_score: 2,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [ 1 ],
          notes: "Implementation — depends on test task 1"
        },
        {
          position: 3,
          type: "test",
          prompt: "Write tests for User authentication: valid credentials return true, invalid return false, password length validation.",
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 2,
          depends_on: [ 2 ],
          notes: "Test authentication behavior"
        },
        {
          position: 4,
          type: "code",
          prompt: "Add authentication logic to User model: validate password length >= 8 characters.",
          agent: "rails-lead",
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 2,
          depends_on: [ 3 ],
          notes: "Implementation — depends on test task 3"
        }
      ].to_json
    end

    test "full decomposition with vcr" do
      result = DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: false
      )

      assert_equal 4, result.tasks.size
      assert_equal [], result.errors
      assert result.workflow_run.present?
    end

    test "task records created with correct scores" do
      DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: false
      )

      tasks = Task.order(position: :asc)
      assert_equal 4, tasks.size

      # Verify scores
      assert_equal 2, tasks.first.files_score
      assert_equal 1, tasks.first.concepts_score
      assert_equal 1, tasks.first.dependencies_score
      assert_equal 4, tasks.first.total_score

      # Verify task types
      assert_equal "test", tasks[0].task_type
      assert_equal "code", tasks[1].task_type
      assert_equal "test", tasks[2].task_type
      assert_equal "code", tasks[3].task_type
    end

    test "task dependency edges match architect output" do
      DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: false
      )

      task1 = Task.find_by(position: 1)
      task2 = Task.find_by(position: 2)
      task3 = Task.find_by(position: 3)
      task4 = Task.find_by(position: 4)

      # Task 1 has no dependencies
      assert_equal [], task1.dependencies.to_a

      # Task 2 depends on task 1
      assert_equal [ task1 ], task2.dependencies.to_a

      # Task 3 depends on task 2
      assert_equal [ task2 ], task3.dependencies.to_a

      # Task 4 depends on task 3
      assert_equal [ task3 ], task4.dependencies.to_a
    end

    test "test first ordering verified" do
      DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: false
      )

      tasks = Task.order(position: :asc)

      # For each code task, verify it depends on a test task
      code_tasks = tasks.select { |t| t.task_type == "code" }
      code_tasks.each do |code_task|
        dependencies = code_task.dependencies.to_a
        assert dependencies.any?, "Code task #{code_task.position} should have dependencies"

        # At least one dependency should be a test task
        has_test_dependency = dependencies.any? { |dep| dep.task_type == "test" }
        assert has_test_dependency, "Code task #{code_task.position} should depend on a test task"
      end
    end

    test "parallel groups detected correctly" do
      result = DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: true
      )

      parallel_groups = result.parallel_groups

      # First group should contain only task 1 (no dependencies)
      assert_equal [ 1 ], parallel_groups.first

      # Subsequent groups follow dependency resolution
      assert parallel_groups.size >= 1
    end

    test "workflow run status transitions to completed" do
      result = DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: false
      )

      workflow_run = result.workflow_run
      assert_equal "completed", workflow_run.status
    end
  end
end
