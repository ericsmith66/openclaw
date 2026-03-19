# frozen_string_literal: true

require "test_helper"

class PostgresBusIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @project = create(:project)
    @team = create(:agent_team, project: @project)
    @tm = create(:team_membership, agent_team: @team)
    @workflow_run = create(:workflow_run, project: @project, team_membership: @tm)
  end

  test "full cycle workflow run to events to subscribers" do
    bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: [])

    # Subscribe BEFORE publishing events so we capture all of them
    received_events = []
    bus.subscribe("*") do |channel, event|
      received_events << { channel: channel, type: event.type, payload: event.payload }
    end

    # Publish several events
    event1 = AgentDesk::MessageBus::Event.new(
      type: "agent.started",
      agent_id: "test-agent",
      task_id: "task-1",
      payload: { profile_name: "qa" }
    )
    bus.publish("agent.started", event1)

    event2 = AgentDesk::MessageBus::Event.new(
      type: "agent.completed",
      agent_id: "test-agent",
      task_id: "task-1",
      payload: { iterations: 5 }
    )
    bus.publish("agent.completed", event2)

    event3 = AgentDesk::MessageBus::Event.new(
      type: "tool.called",
      agent_id: "test-agent",
      task_id: "task-1",
      payload: { tool_name: "power---bash", arguments: {} }
    )
    bus.publish("tool.called", event3)

    # Verify DB records created
    assert_equal 3, WorkflowEvent.where(workflow_run_id: @workflow_run.id).count

    # Verify all events persisted
    db_events = WorkflowEvent.where(workflow_run_id: @workflow_run.id).order(recorded_at: :asc)
    assert_equal "agent.started", db_events.first.event_type
    assert_equal "agent.completed", db_events[1].event_type
    assert_equal "tool.called", db_events[2].event_type

    # Verify subscriber received all events
    assert_equal 3, received_events.length
    assert_equal "agent.started", received_events[0][:type]
    assert_equal "agent.completed", received_events[1][:type]
    assert_equal "tool.called", received_events[2][:type]
  end

  test "event ordering preserved in db" do
    bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: [])

    # Publish events rapidly
    10.times do |i|
      event = AgentDesk::MessageBus::Event.new(
        type: "test.event.#{i}",
        agent_id: "test-agent",
        task_id: "task-1",
        payload: { index: i }
      )
      bus.publish("test.channel", event)

      # Small delay to ensure different timestamps
      sleep(0.01) if i < 9
    end

    # Verify ordering by recorded_at
    db_events = WorkflowEvent.where(workflow_run_id: @workflow_run.id).order(recorded_at: :asc)

    db_events.each_with_index do |event, i|
      assert_equal "test.event.#{i}", event.event_type
      assert_equal i, event.payload["index"]
    end
  end

  test "by_type scope returns correct subset" do
    bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: [])

    # Publish mixed event types
    bus.publish("agent.started", build_event(type: "agent.started", agent_id: "a", task_id: "t", payload: {}))
    bus.publish("agent.started", build_event(type: "agent.started", agent_id: "a", task_id: "t", payload: {}))
    bus.publish("tool.called", build_event(type: "tool.called", agent_id: "a", task_id: "t", payload: {}))
    bus.publish("agent.completed", build_event(type: "agent.completed", agent_id: "a", task_id: "t", payload: {}))

    # Verify by_type scope
    agent_started_events = WorkflowEvent.by_type("agent.started")
    assert_equal 2, agent_started_events.count

    tool_called_events = WorkflowEvent.by_type("tool.called")
    assert_equal 1, tool_called_events.count

    agent_completed_events = WorkflowEvent.by_type("agent.completed")
    assert_equal 1, agent_completed_events.count

    nonexistent_events = WorkflowEvent.by_type("nonexistent")
    assert_equal 0, nonexistent_events.count
  end

  private

  def build_event(type:, agent_id:, task_id:, payload:)
    AgentDesk::MessageBus::Event.new(
      type: type,
      agent_id: agent_id,
      task_id: task_id,
      payload: payload
    )
  end
end
