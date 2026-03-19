# frozen_string_literal: true

require "test_helper"
require "json"

class SchemaIntegrationTest < ActiveSupport::TestCase
  test "full object graph" do
    # Create project
    project = Project.create!(name: "Legion", path: "/tmp/test/project-123")
    # Create team
    team = AgentTeam.create!(project: project, name: "ROR", team_rules: {})
    # Create membership with config
    membership = TeamMembership.create!(
      agent_team: team,
      position: 0,
      config: {
        "id" => "test-id",
        "name" => "Test Agent",
        "provider" => "openai",
        "model" => "gpt-4",
        "maxIterations" => 100,
        "usePowerTools" => true,
        "toolApprovals" => {},
        "toolSettings" => {},
        "customInstructions" => ""
      }
    )
    # Create workflow run
    workflow_run = WorkflowRun.create!(
      project: project,
      team_membership: membership,
      prompt: "Test prompt",
      status: :queued
    )
    # Create workflow event
    event = WorkflowEvent.create!(
      workflow_run: workflow_run,
      event_type: "agent.started",
      recorded_at: Time.current,
      payload: {}
    )
    # Create task
    task = Task.create!(
      project: project,
      team_membership: membership,
      workflow_run: workflow_run,
      prompt: "Test task",
      task_type: :code,
      status: :pending
    )
    # Create task dependency (self-referential not allowed, need another task)
    task2 = Task.create!(
      project: project,
      team_membership: membership,
      workflow_run: workflow_run,
      prompt: "Another task",
      task_type: :test,
      status: :pending
    )
    dependency = TaskDependency.create!(
      task: task,
      depends_on_task: task2
    )

    # Verify associations
    assert_equal team, membership.agent_team
    assert_equal project, workflow_run.project
    assert_equal membership, workflow_run.team_membership
    assert_equal workflow_run, event.workflow_run
    assert_equal workflow_run, task.workflow_run
    assert_equal task, dependency.task
    assert_equal task2, dependency.depends_on_task
    assert_includes task.dependencies, task2
    assert_includes task2.dependents, task
  end

  test "associations navigable" do
    project = create(:project)
    team = create(:agent_team, project: project)
    membership = create(:team_membership, agent_team: team)
    workflow_run = create(:workflow_run, project: project, team_membership: membership)
    event = create(:workflow_event, workflow_run: workflow_run)
    task = create(:task, project: project, team_membership: membership, workflow_run: workflow_run)
    task2 = create(:task, project: project, team_membership: membership, workflow_run: workflow_run)
    dependency = create(:task_dependency, task: task, depends_on_task: task2)

    # Navigate from project down
    assert_includes project.agent_teams, team
    assert_includes project.workflow_runs, workflow_run
    assert_includes project.tasks, task
    # Navigate from team up and down
    assert_equal project, team.project
    assert_includes team.team_memberships, membership
    # Navigate from membership
    assert_equal team, membership.agent_team
    assert_includes membership.workflow_runs, workflow_run
    # Navigate from workflow_run
    assert_equal project, workflow_run.project
    assert_equal membership, workflow_run.team_membership
    assert_includes workflow_run.workflow_events, event
    assert_includes workflow_run.tasks, task
    # Navigate from task
    assert_equal project, task.project
    assert_equal membership, task.team_membership
    assert_equal workflow_run, task.workflow_run
    assert_includes task.dependencies, task2
    # Navigate from dependency
    assert_equal task, dependency.task
    assert_equal task2, dependency.depends_on_task
  end

  test "to_profile real config" do
    config_path = Rails.root.join(".aider-desk/agents/ror-rails-legion/config.json")
    config_data = JSON.parse(File.read(config_path))
    project = create(:project)
    team = create(:agent_team, project: project)
    membership = TeamMembership.create!(
      agent_team: team,
      position: 0,
      config: config_data
    )

    profile = membership.to_profile
    assert_instance_of AgentDesk::Agent::Profile, profile
    # Required fields
    assert_equal config_data["id"], profile.id
    assert_equal config_data["name"], profile.name
    assert_equal config_data["provider"], profile.provider
    assert_equal config_data["model"], profile.model
    # Optional fields with defaults
    assert profile.max_iterations.is_a?(Integer)
    assert profile.use_power_tools.in?([ true, false ])
    # Subagent config if enabled
    if config_data["subagent"] && config_data["subagent"]["enabled"]
      assert_instance_of AgentDesk::SubagentConfig, profile.subagent_config
    end
    # Tool settings normalization
    tool_settings = profile.tool_settings
    assert tool_settings.is_a?(Hash)
    # Ensure no camelCase keys in inner hashes
    tool_settings.each_value do |opts|
      next unless opts.is_a?(Hash)
      opts.keys.each do |key|
        assert_no_match(/[A-Z]/, key, "tool_settings key #{key} should be snake_case")
      end
    end
  end
end
