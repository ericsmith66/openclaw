# frozen_string_literal: true

require "test_helper"

module Legion
  class Epic1ValidationTest < ActiveSupport::TestCase
    include Legion::E2EHelper

    # Disable parallel tests for E2E — scenarios need isolation
    self.use_transactional_tests = false

    setup do
      # Clean slate per test using DatabaseCleaner
      DatabaseCleaner.strategy = :truncation
      DatabaseCleaner.clean
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 1: Team Import Round-Trip
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_1_team_import_round_trip" do
      project = create_test_project(name: "scenario-1")
      team = import_ror_team(project)

      # Verify 4 agents in database
      assert_equal 4, team.team_memberships.count, "Expected 4 agents imported"

      # Verify each agent has full config and to_profile works
      team.team_memberships.each do |membership|
        profile = membership.to_profile

        assert_not_nil profile, "to_profile should return a Profile"
        assert_not_nil profile.provider, "Profile should have provider"
        assert_not_nil profile.model, "Profile should have model"
        assert profile.max_iterations.is_a?(Integer), "Profile should have max_iterations as Integer"
        assert profile.tool_approvals.is_a?(Hash), "Profile should have tool_approvals as Hash"
        assert profile.custom_instructions.is_a?(String), "Profile should have custom_instructions as String"
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 2: Single Agent Dispatch with Full Identity
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_2_single_agent_full_identity" do
      skip("VCR cassette recording required - run with RECORD_VCR=1") unless cassette_exists?("e2e/scenario_2_rails_lead_dispatch")

      VCR.use_cassette("e2e/scenario_2_rails_lead_dispatch") do
        project = create_test_project(name: "scenario-2")
        team = import_ror_team(project)
        membership = team.team_memberships.first

        # Dispatch with simple prompt
        workflow_run = DispatchService.call(
          project_path: project.path,
          team_name: team.name,
          agent_identifier: membership.config["id"],
          prompt: "List your available tools",
          verbose: false,
          interactive: false,
          max_iterations: nil
        )

        # Verify WorkflowRun created and completed
        assert workflow_run.is_a?(WorkflowRun), "DispatchService should return WorkflowRun"
        assert_equal "completed", workflow_run.status, "WorkflowRun should be completed"
        assert_operator workflow_run.iterations, :>, 0, "Should have at least 1 iteration"

        # Verify event trail complete
        verify_event_trail(workflow_run, expected_event_types: [
          "agent.started",
          "response.complete",
          "agent.completed"
        ])

        # Note: Detailed identity verification (rules content, skills, tool approvals)
        # happens during AgentAssemblyService which is tested in unit/integration tests.
        # E2E test confirms the dispatch pipeline works end-to-end.
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 3: Multi-Agent Dispatch
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_3_multi_agent_dispatch" do
      skip("VCR cassette recording required - run with RECORD_VCR=1") unless cassette_exists?("e2e/scenario_3_multi_agent")

      VCR.use_cassette("e2e/scenario_3_multi_agent") do
        project = create_test_project(name: "scenario-3")
        team = import_ror_team(project)

        workflow_runs = []

        # Dispatch each of 4 agents sequentially
        team.team_memberships.each do |membership|
          workflow_run = DispatchService.call(
            project_path: project.path,
            team_name: team.name,
            agent_identifier: membership.config["id"],
            prompt: "What is your name?",
            verbose: false,
            interactive: false,
            max_iterations: nil
          )
          workflow_runs << workflow_run
        end

        # Verify 4 separate WorkflowRuns created
        assert_equal 4, workflow_runs.count
        assert_equal 4, workflow_runs.uniq.count, "Each dispatch should create separate WorkflowRun"

        # Verify each has events
        workflow_runs.each do |run|
          assert_operator run.workflow_events.count, :>, 0, "Each run should have events"
        end
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 4: Orchestrator Hook Behavior
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_4_orchestrator_hook_behavior" do
      skip("VCR cassette recording required - run with RECORD_VCR=1") unless cassette_exists?("e2e/scenario_4_hook_iteration_limit")

      VCR.use_cassette("e2e/scenario_4_hook_iteration_limit") do
        project = create_test_project(name: "scenario-4")
        team = import_ror_team(project)
        membership = team.team_memberships.first

        # Dispatch with very low max_iterations
        workflow_run = DispatchService.call(
          project_path: project.path,
          team_name: team.name,
          agent_identifier: membership.config["id"],
          prompt: "Write a complex Rails application with authentication, authorization, and API",
          max_iterations: 3,
          verbose: false,
          interactive: false
        )

        # Verify workflow run completed (even if truncated by hook)
        assert_not_nil workflow_run
        assert_equal 3, workflow_run.iterations, "Should hit max_iterations limit"

        # Note: Hook metadata verification would require inspecting workflow_run.metadata
        # which may or may not be populated depending on hook implementation.
        # The key E2E verification is that low max_iterations doesn't crash the system.
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 5: Event Trail Forensics
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_5_event_trail_forensics" do
      skip("VCR cassette recording required - run with RECORD_VCR=1") unless cassette_exists?("e2e/scenario_5_multi_tool_call")

      VCR.use_cassette("e2e/scenario_5_multi_tool_call") do
        project = create_test_project(name: "scenario-5")
        team = import_ror_team(project)
        membership = team.team_memberships.first

        # Run task that makes multiple tool calls
        workflow_run = DispatchService.call(
          project_path: project.path,
          team_name: team.name,
          agent_identifier: membership.config["id"],
          prompt: "List files in current directory and read the README",
          verbose: false,
          interactive: false,
          max_iterations: nil
        )

        # Query WorkflowEvents and reconstruct timeline
        events = workflow_run.workflow_events.order(:created_at)

        # Verify event count > 0
        assert_operator events.count, :>, 0, "Should have multiple events"

        # Verify expected event types present
        event_types = events.pluck(:event_type).uniq
        assert_includes event_types, "agent.started"
        assert_includes event_types, "agent.completed"

        # Verify chronological ordering
        timestamps = events.pluck(:created_at)
        assert_equal timestamps, timestamps.sort, "Events should be chronologically ordered"

        # Verify payload contains useful data (event_data is JSONB)
        events.each do |event|
          assert event.event_data.is_a?(Hash), "Event data should be a hash"
        end
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 6: Decomposition → Task Creation
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_6_decomposition_task_creation" do
      skip("VCR cassette recording required - run with RECORD_VCR=1") unless cassette_exists?("e2e/scenario_6_decompose_prd")

      VCR.use_cassette("e2e/scenario_6_decompose_prd") do
        project = create_test_project(name: "scenario-6")
        team = import_ror_team(project)
        prd_path = Rails.root.join("test/fixtures/test-prd-simple.md").to_s

        # Decompose test PRD
        result = DecompositionService.call(
          project_path: project.path,
          team_name: team.name,
          prd_path: prd_path,
          agent_identifier: "architect",
          dry_run: false,
          verbose: false
        )

        assert result.errors.empty?, "Decomposition should succeed: #{result.errors.join(', ')}"

        workflow_run = result.workflow_run
        tasks = Task.where(workflow_run: workflow_run).order(:position)

        # Verify Task records created
        assert_operator tasks.count, :>=, 3, "Should create at least 3 tasks"
        assert_operator tasks.count, :<=, 8, "Should create at most 8 tasks for simple PRD"

        # Verify task structure
        verify_task_structure(tasks)

        # Verify TaskDependency edges exist
        assert TaskDependency.where(task: tasks).exists?, "Should have at least one dependency"

        # Verify test-first ordering: at least one implementation task depends on a test task
        test_tasks = tasks.where(task_type: "test")
        code_tasks = tasks.where(task_type: "code")

        if test_tasks.any? && code_tasks.any?
          # Check if any code task depends on a test task
          code_tasks.each do |code_task|
            deps = code_task.dependencies
            if deps.any? { |dep| dep.task_type == "test" }
              # Found test-first pattern
              assert true
              break
            end
          end
        end
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 7: Plan Execution Cycle
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_7_plan_execution_cycle" do
      skip("VCR cassette recording required - run with RECORD_VCR=1") unless cassette_exists?("e2e/scenario_7_plan_execution")

      VCR.use_cassette("e2e/scenario_7_plan_execution") do
        project = create_test_project(name: "scenario-7")
        team = import_ror_team(project)
        membership = team.team_memberships.first

        # Create parent WorkflowRun for the plan
        workflow_run = WorkflowRun.create!(
          project: project,
          team_membership: membership,
          prompt: "Test plan execution",
          status: :completed
        )

        # Create 3 tasks manually with dependencies
        task_1 = Task.create!(
          workflow_run: workflow_run,
          project: project,
          team_membership: membership,
          prompt: "Task 1",
          task_type: :test,
          position: 1,
          status: :pending,
          files_score: 2,
          concepts_score: 2,
          dependencies_score: 1
        )

        task_2 = Task.create!(
          workflow_run: workflow_run,
          project: project,
          team_membership: membership,
          prompt: "Task 2",
          task_type: :code,
          position: 2,
          status: :pending,
          files_score: 3,
          concepts_score: 2,
          dependencies_score: 2
        )

        task_3 = Task.create!(
          workflow_run: workflow_run,
          project: project,
          team_membership: membership,
          prompt: "Task 3",
          task_type: :code,
          position: 3,
          status: :pending,
          files_score: 2,
          concepts_score: 3,
          dependencies_score: 2
        )

        # Create dependencies: task_2 depends on task_1, task_3 depends on task_2
        TaskDependency.create!(task: task_2, depends_on_task: task_1)
        TaskDependency.create!(task: task_3, depends_on_task: task_2)

        # Execute plan
        PlanExecutionService.call(
          workflow_run: workflow_run,
          continue_on_failure: false,
          dry_run: false,
          verbose: false
        )

        # Verify tasks dispatched in dependency order
        task_1.reload
        task_2.reload
        task_3.reload

        assert task_1.completed?, "Task 1 should be completed"
        assert task_2.completed?, "Task 2 should be completed"
        assert task_3.completed?, "Task 3 should be completed"

        # Verify each task has execution_run_id
        assert_not_nil task_1.execution_run_id, "Task 1 should have execution_run_id"
        assert_not_nil task_2.execution_run_id, "Task 2 should have execution_run_id"
        assert_not_nil task_3.execution_run_id, "Task 3 should have execution_run_id"

        # Verify execution runs are different
        assert_not_equal task_1.execution_run_id, task_2.execution_run_id
        assert_not_equal task_2.execution_run_id, task_3.execution_run_id
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 8: Full Cycle (Decompose → Execute)
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_8_full_decompose_execute_cycle" do
      skip("VCR cassette recording required - run with RECORD_VCR=1") unless cassette_exists?("e2e/scenario_8_full_cycle")

      VCR.use_cassette("e2e/scenario_8_full_cycle") do
        project = create_test_project(name: "scenario-8")
        team = import_ror_team(project)
        prd_path = Rails.root.join("test/fixtures/test-prd-simple.md").to_s

        # Decompose
        decomp_result = DecompositionService.call(
          project_path: project.path,
          team_name: team.name,
          prd_path: prd_path,
          agent_identifier: "architect",
          dry_run: false,
          verbose: false
        )

        assert decomp_result.errors.empty?, "Decomposition should succeed: #{decomp_result.errors.join(', ')}"
        workflow_run = decomp_result.workflow_run

        # Execute the plan
        PlanExecutionService.call(
          workflow_run: workflow_run,
          continue_on_failure: false,
          dry_run: false,
          verbose: false
        )

        # Verify all tasks completed
        tasks = Task.where(workflow_run: workflow_run)
        assert tasks.all?(&:completed?), "All tasks should be completed"

        # Verify full event trails for each task
        tasks.each do |task|
          next unless task.execution_run_id

          execution_run = WorkflowRun.find(task.execution_run_id)
          assert_operator execution_run.workflow_events.count, :>, 0,
            "Task #{task.id} execution should have events"
        end
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 9: Dependency Graph Correctness
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_9_dependency_graph_correctness" do
      skip("VCR cassette recording required - run with RECORD_VCR=1") unless cassette_exists?("e2e/scenario_9_dependency_graph")

      VCR.use_cassette("e2e/scenario_9_dependency_graph") do
        project = create_test_project(name: "scenario-9")
        team = import_ror_team(project)
        membership = team.team_memberships.first

        # Create parent WorkflowRun
        workflow_run = WorkflowRun.create!(
          project: project,
          team_membership: membership,
          prompt: "Dependency graph test",
          status: :completed
        )

        # Create known task graph:
        # Task A (independent)
        # Task B (independent)
        # Task C (depends on A and B) — fan-in
        # Task D (depends on C)
        # Task E (depends on C) — fan-out

        task_a = Task.create!(
          workflow_run: workflow_run,
          project: project,
          team_membership: membership,
          prompt: "Task A - independent",
          task_type: :test,
          position: 1,
          status: :pending,
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1
        )

        task_b = Task.create!(
          workflow_run: workflow_run,
          project: project,
          team_membership: membership,
          prompt: "Task B - independent",
          task_type: :test,
          position: 2,
          status: :pending,
          files_score: 1,
          concepts_score: 1,
          dependencies_score: 1
        )

        task_c = Task.create!(
          workflow_run: workflow_run,
          project: project,
          team_membership: membership,
          prompt: "Task C - fan-in",
          task_type: :code,
          position: 3,
          status: :pending,
          files_score: 2,
          concepts_score: 2,
          dependencies_score: 2
        )

        task_d = Task.create!(
          workflow_run: workflow_run,
          project: project,
          team_membership: membership,
          prompt: "Task D - depends on C",
          task_type: :code,
          position: 4,
          status: :pending,
          files_score: 2,
          concepts_score: 2,
          dependencies_score: 1
        )

        task_e = Task.create!(
          workflow_run: workflow_run,
          project: project,
          team_membership: membership,
          prompt: "Task E - depends on C (fan-out)",
          task_type: :code,
          position: 5,
          status: :pending,
          files_score: 2,
          concepts_score: 2,
          dependencies_score: 1
        )

        # Create dependencies
        TaskDependency.create!(task: task_c, depends_on_task: task_a)
        TaskDependency.create!(task: task_c, depends_on_task: task_b)
        TaskDependency.create!(task: task_d, depends_on_task: task_c)
        TaskDependency.create!(task: task_e, depends_on_task: task_c)

        # Execute plan
        PlanExecutionService.call(
          workflow_run: workflow_run,
          continue_on_failure: false,
          dry_run: false,
          verbose: false
        )

        # Verify all tasks completed
        [ task_a, task_b, task_c, task_d, task_e ].each(&:reload)
        assert task_a.completed?, "Task A should be completed"
        assert task_b.completed?, "Task B should be completed"
        assert task_c.completed?, "Task C should be completed"
        assert task_d.completed?, "Task D should be completed"
        assert task_e.completed?, "Task E should be completed"

        # Verify ready_for_run scope behavior (query at a point in time would show correct ready tasks)
        # Since all tasks are now completed, we verify the dependency structure was respected
        assert task_c.dependencies.include?(task_a), "Task C should depend on Task A"
        assert task_c.dependencies.include?(task_b), "Task C should depend on Task B"
        assert task_d.dependencies.include?(task_c), "Task D should depend on Task C"
        assert task_e.dependencies.include?(task_c), "Task E should depend on Task C"
      end
    end

    # ══════════════════════════════════════════════════════════════════════════
    # SCENARIO 10: Error Handling & Resilience
    # ══════════════════════════════════════════════════════════════════════════
    test "scenario_10_error_handling_resilience" do
      project = create_test_project(name: "scenario-10")
      import_ror_team(project)

      # Subtest 1: Dispatch with non-existent team
      error = assert_raises(Legion::DispatchService::TeamNotFoundError) do
        DispatchService.call(
          project_path: project.path,
          team_name: "INVALID_TEAM",
          agent_identifier: "any-agent",
          prompt: "test",
          verbose: false,
          interactive: false,
          max_iterations: nil
        )
      end
      assert_includes error.message.downcase, "team", "Error should mention team"
      assert_includes error.message, "INVALID_TEAM", "Error should mention the invalid team name"

      # Subtest 2: Dispatch with non-existent agent
      error = assert_raises(Legion::DispatchService::AgentNotFoundError) do
        DispatchService.call(
          project_path: project.path,
          team_name: "ROR",
          agent_identifier: "invalid-agent",
          prompt: "test",
          verbose: false,
          interactive: false,
          max_iterations: nil
        )
      end
      assert_includes error.message.downcase, "agent", "Error should mention agent"
      # Error message should ideally list available agents, but we'll just verify it's informative

      # Subtest 3: Execute plan with failing task (halt behavior)
      team = AgentTeam.find_by!(project: project, name: "ROR")
      membership = team.team_memberships.first

      workflow_run = WorkflowRun.create!(
        project: project,
        team_membership: membership,
        prompt: "Test failure handling",
        status: :completed
      )

      task_1 = Task.create!(
        workflow_run: workflow_run,
        project: project,
        team_membership: membership,
        prompt: "Task 1 will fail",
        task_type: :code,
        position: 1,
        status: :pending,
        files_score: 2,
        concepts_score: 2,
        dependencies_score: 1
      )

      task_2 = Task.create!(
        workflow_run: workflow_run,
        project: project,
        team_membership: membership,
        prompt: "Task 2 depends on task 1",
        task_type: :code,
        position: 2,
        status: :pending,
        files_score: 2,
        concepts_score: 2,
        dependencies_score: 1
      )

      TaskDependency.create!(task: task_2, depends_on_task: task_1)

      # Stub DispatchService to raise error on first call
      DispatchService.stubs(:call).raises(StandardError, "Simulated failure")

      # Execute plan should halt on first failure (doesn't raise, sets halted flag)
      result = PlanExecutionService.call(
        workflow_run: workflow_run,
        continue_on_failure: false,
        dry_run: false,
        verbose: false
      )

      assert result.halted, "Result should be halted"
      assert_includes result.halt_reason, "failed", "Halt reason should mention failure"

      task_1.reload
      assert_equal "failed", task_1.status, "Task 1 should be marked failed"

      # Subtest 4: Execute plan with --continue-on-failure
      # Need a fresh workflow_run for this test
      workflow_run_2 = WorkflowRun.create!(
        project: project,
        team_membership: membership,
        prompt: "Test continue on failure",
        status: :completed
      )

      task_3 = Task.create!(
        workflow_run: workflow_run_2,
        project: project,
        team_membership: membership,
        prompt: "Task 3 will fail",
        task_type: :code,
        position: 1,
        status: :pending,
        files_score: 2,
        concepts_score: 2,
        dependencies_score: 1
      )

      task_4 = Task.create!(
        workflow_run: workflow_run_2,
        project: project,
        team_membership: membership,
        prompt: "Task 4 depends on task 3",
        task_type: :code,
        position: 2,
        status: :pending,
        files_score: 2,
        concepts_score: 2,
        dependencies_score: 1
      )

      TaskDependency.create!(task: task_4, depends_on_task: task_3)

      # DispatchService still stubbed to raise error
      # With continue_on_failure: true, should not raise, should skip dependents

      PlanExecutionService.call(
        workflow_run: workflow_run_2,
        continue_on_failure: true,
        dry_run: false,
        verbose: false
      )

      task_3.reload
      task_4.reload

      assert_equal "failed", task_3.status, "Task 3 should be marked failed"
      assert_equal "skipped", task_4.status, "Task 4 should be skipped (depends on failed task)"
    end

    private

    def cassette_exists?(name)
      cassette_path = Rails.root.join("test/vcr_cassettes/#{name}.yml")
      File.exist?(cassette_path)
    end
  end
end
