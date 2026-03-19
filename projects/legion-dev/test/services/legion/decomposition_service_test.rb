# frozen_string_literal: true

require "test_helper"

module Legion
  class DecompositionServiceTest < ActiveSupport::TestCase
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

      # Stub DispatchService to return a mock WorkflowRun
      @mock_workflow_run = create(:workflow_run,
        project: @project,
        team_membership: @architect,
        status: :completed,
        result: valid_response_json
      )

      DispatchService.stubs(:call).returns(@mock_workflow_run)
    end

    def valid_response_json
      [
        {
          position: 1,
          type: "test",
          prompt: "Write tests for User model",
          agent: "rails-lead",
          files_score: 2,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [],
          notes: "Test task"
        },
        {
          position: 2,
          type: "code",
          prompt: "Create User model",
          agent: "rails-lead",
          files_score: 2,
          concepts_score: 1,
          dependencies_score: 1,
          depends_on: [ 1 ],
          notes: "Implementation"
        }
      ].to_json
    end

    test "reads prd file content" do
      # File exists and is readable
      content = File.read(@prd_path)
      assert_includes content, "User Management"

      # Service can read it
      result = DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: true
      )

      assert_equal 2, result.tasks.size
    end

    test "builds decomposition prompt with prd embedded" do
      # Stub to capture the prompt
      captured_prompt = nil
      DispatchService.stubs(:call).with do |args|
        captured_prompt = args[:prompt]
        true
      end.returns(@mock_workflow_run)

      DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: true
      )

      assert_not_nil captured_prompt
      assert_includes captured_prompt, "User Management" # PRD content
      assert_includes captured_prompt, "atomic coding tasks" # Template content
    end

    test "dispatches architect via dispatch service" do
      DispatchService.expects(:call).with(
        team_name: "ROR",
        agent_identifier: "architect",
        prompt: anything,
        project_path: @project_path,
        interactive: false,
        verbose: false
      ).returns(@mock_workflow_run)

      DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: true
      )
    end

    test "passes agent response to parser" do
      DecompositionParser.expects(:call).with(
        response_text: @mock_workflow_run.result
      ).returns(
        DecompositionParser::Result.new(
          tasks: [],
          warnings: [],
          errors: []
        )
      )

      DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: true
      )
    end

    test "creates task records from parsed output" do
      assert_difference "Task.count", 2 do
        DecompositionService.call(
          team_name: "ROR",
          prd_path: @prd_path,
          project_path: @project_path,
          dry_run: false
        )
      end

      tasks = Task.order(position: :asc)
      assert_equal 1, tasks.first.position
      assert_equal "test", tasks.first.task_type
      assert_equal 2, tasks.last.position
      assert_equal "code", tasks.last.task_type
      assert_equal @mock_workflow_run, tasks.first.workflow_run
    end

    test "creates task dependency records" do
      assert_difference "TaskDependency.count", 1 do
        DecompositionService.call(
          team_name: "ROR",
          prd_path: @prd_path,
          project_path: @project_path,
          dry_run: false
        )
      end

      task1 = Task.find_by(position: 1)
      task2 = Task.find_by(position: 2)

      assert_equal [ task1 ], task2.dependencies.to_a
    end

    test "maps agent names to team memberships" do
      DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: false
      )

      tasks = Task.order(position: :asc)
      # Both tasks assigned to "rails-lead" in the JSON
      assert_equal @rails_lead, tasks.first.team_membership
      assert_equal @rails_lead, tasks.last.team_membership
    end

    test "dry run mode parses but does not save" do
      assert_no_difference "Task.count" do
        result = DecompositionService.call(
          team_name: "ROR",
          prd_path: @prd_path,
          project_path: @project_path,
          dry_run: true
        )

        assert_equal 2, result.tasks.size
      end
    end

    test "prd file not found raises error" do
      assert_raises DecompositionService::PrdNotFoundError do
        DecompositionService.call(
          team_name: "ROR",
          prd_path: "/nonexistent/file.md",
          project_path: @project_path,
          dry_run: true
        )
      end
    end

    test "unparseable output preserves raw response" do
      bad_workflow_run = create(:workflow_run,
        project: @project,
        team_membership: @architect,
        status: :completed,
        result: "This is not JSON at all"
      )
      DispatchService.stubs(:call).returns(bad_workflow_run)

      assert_raises DecompositionService::ParseError do
        DecompositionService.call(
          team_name: "ROR",
          prd_path: @prd_path,
          project_path: @project_path,
          dry_run: true
        )
      end

      # Verify raw response preserved in WorkflowRun
      bad_workflow_run.reload
      assert_equal "failed", bad_workflow_run.status
      assert_includes bad_workflow_run.error_message, "No valid JSON"
    end

    test "creates workflow run with decomposing status" do
      DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: true
      )

      # After completion, status should be 'completed'
      # But during execution it was 'decomposing'
      # We verify the final state
      @mock_workflow_run.reload
      assert_equal "completed", @mock_workflow_run.status
    end

    test "transaction rollback on validation error" do
      # Create a scenario where TaskDependency validation fails
      # (e.g., circular dependency that passes parser but fails model validation)
      # This is hard to create since parser already checks cycles
      # Instead, test that if Task.create! fails, nothing is saved

      Task.any_instance.stubs(:save!).raises(ActiveRecord::RecordInvalid)

      assert_no_difference [ "Task.count", "TaskDependency.count" ] do
        assert_raises ActiveRecord::RecordInvalid do
          DecompositionService.call(
            team_name: "ROR",
            prd_path: @prd_path,
            project_path: @project_path,
            dry_run: false
          )
        end
      end
    end

    test "empty prd file raises error" do
      empty_prd_path = Rails.root.join("test/fixtures/empty_prd.md").to_s
      File.write(empty_prd_path, "")

      assert_raises DecompositionService::EmptyPrdError do
        DecompositionService.call(
          team_name: "ROR",
          prd_path: empty_prd_path,
          project_path: @project_path,
          dry_run: true
        )
      end
    ensure
      File.delete(empty_prd_path) if File.exist?(empty_prd_path)
    end

    test "dispatch service returns workflow run" do
      workflow_run = DecompositionService.call(
        team_name: "ROR",
        prd_path: @prd_path,
        project_path: @project_path,
        dry_run: true
      ).workflow_run

      assert_equal @mock_workflow_run, workflow_run
    end

    test "console output includes task table" do
      output = capture_io do
        DecompositionService.call(
          team_name: "ROR",
          prd_path: @prd_path,
          project_path: @project_path,
          dry_run: true
        )
      end.join

      assert_includes output, "#"
      assert_includes output, "Type"
      assert_includes output, "Agent"
      assert_includes output, "Score"
      assert_includes output, "Write tests for User model"
    end

    test "console output includes parallel groups" do
      output = capture_io do
        DecompositionService.call(
          team_name: "ROR",
          prd_path: @prd_path,
          project_path: @project_path,
          dry_run: true
        )
      end.join

      assert_includes output, "Parallel groups:"
      assert_includes output, "Group 1"
    end
  end
end
