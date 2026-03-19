# frozen_string_literal: true

require "test_helper"

module Legion
  class E2EHelperTest < ActiveSupport::TestCase
    include Legion::E2EHelper

    self.use_transactional_tests = false

    setup do
      DatabaseCleaner.strategy = :truncation
      DatabaseCleaner.clean
    end

    teardown do
      DatabaseCleaner.clean
    end

    # Plan item 11: verify create_test_project helper
    test "create_test_project_helper creates project with unique path" do
      project1 = create_test_project(name: "test-a")
      project2 = create_test_project(name: "test-a")

      assert_not_nil project1
      assert_not_nil project2
      assert_not_equal project1.path, project2.path, "Paths should be unique across calls"
      assert Project.exists?(project1.id)
      assert Project.exists?(project2.id)
    end

    # Plan item 12: verify import_ror_team helper
    test "import_ror_team_helper returns AgentTeam" do
      project = create_test_project(name: "helper-import")
      team = import_ror_team(project)

      assert_kind_of AgentTeam, team
      assert_equal "ROR", team.name
      assert_equal 4, team.team_memberships.count
    end

    # Plan item 13: verify verify_profile_attributes helper
    test "verify_profile_attributes_helper validates matching attributes" do
      project = create_test_project(name: "helper-profile")
      team    = import_ror_team(project)
      membership = team.team_memberships.first
      profile    = membership.to_profile

      assert_nothing_raised do
        verify_profile_attributes(profile, {
          provider: profile.provider,
          model:    profile.model
        })
      end
    end

    # Plan item 14: verify verify_event_trail helper
    test "verify_event_trail_helper validates event presence and ordering" do
      project    = create_test_project(name: "helper-events")
      team       = import_ror_team(project)
      membership = team.team_memberships.first

      workflow_run = WorkflowRun.create!(
        project:         project,
        team_membership: membership,
        prompt:          "test prompt",
        status:          :completed
      )

      WorkflowEvent.create!(
        workflow_run: workflow_run,
        event_type:   "agent.started",
        payload:      {},
        recorded_at:  Time.current
      )

      assert_nothing_raised do
        verify_event_trail(workflow_run, expected_event_types: [ "agent.started" ])
      end
    end

    # Plan item 15: verify verify_task_structure helper
    test "verify_task_structure_helper validates task attributes" do
      project    = create_test_project(name: "helper-tasks")
      team       = import_ror_team(project)
      membership = team.team_memberships.first

      workflow_run = WorkflowRun.create!(
        project:         project,
        team_membership: membership,
        prompt:          "test prompt",
        status:          :completed
      )

      task = Task.create!(
        workflow_run:       workflow_run,
        project:            project,
        team_membership:    membership,
        prompt:             "test task prompt",
        task_type:          :test,
        position:           1,
        status:             :pending,
        files_score:        2,
        concepts_score:     2,
        dependencies_score: 1
      )

      assert_nothing_raised do
        verify_task_structure([ task ])
      end
    end
  end
end
