# frozen_string_literal: true

require "test_helper"

module Legion
  class PostgresBusTest < ActiveSupport::TestCase
    setup do
      @project = create(:project)
      @team = create(:agent_team, project: @project)
      @tm = create(:team_membership, agent_team: @team)
      @workflow_run = create(:workflow_run, project: @project, team_membership: @tm)
      @skip_event_types = []
    end

    test "includes message bus interface" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)
      assert bus.is_a?(AgentDesk::MessageBus::MessageBusInterface)
    end

    test "publish creates workflow event with correct fields" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

      event = build_event(type: "agent.started", agent_id: "test-agent", task_id: "task-1", payload: { profile_name: "qa" })

      bus.publish("agent.started", event)

      workflow_event = WorkflowEvent.last
      assert_equal @workflow_run.id, workflow_event.workflow_run_id
      assert_equal "agent.started", workflow_event.event_type
      assert_equal "agent.started", workflow_event.channel
      assert_equal "test-agent", workflow_event.agent_id
      assert_equal "task-1", workflow_event.task_id
      assert_equal({ "profile_name" => "qa" }, workflow_event.payload)
      assert_in_delta event.timestamp, workflow_event.recorded_at, 1.second
    end

    test "publish forwards to callback bus subscribers" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

      received_events = []
      bus.subscribe("agent.*") do |channel, event|
        received_events << { channel: channel, type: event.type, payload: event.payload }
      end

      event = build_event(type: "agent.started", agent_id: "test-agent", task_id: "task-1", payload: {})
      bus.publish("agent.started", event)

      assert_equal 1, received_events.length
      assert_equal "agent.started", received_events.first[:channel]
      assert_equal "agent.started", received_events.first[:type]
    end

    test "subscribe delegates to callback bus" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

      # Count subscribers before
      callback_bus = bus.instance_variable_get(:@callback_bus)
      before_count = callback_bus.instance_variable_get(:@subscriptions).values.flatten.length

      bus.subscribe("test.pattern") { |channel, event| }

      # Count subscribers after
      after_count = callback_bus.instance_variable_get(:@subscriptions).values.flatten.length

      assert_equal before_count + 1, after_count
    end

    test "wildcard subscription receives matching events" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

      received_events = []
      bus.subscribe("agent.*") do |channel, event|
        received_events << channel
      end

      bus.publish("agent.started", build_event(type: "agent.started", agent_id: "a", task_id: "t", payload: {}))
      bus.publish("agent.completed", build_event(type: "agent.completed", agent_id: "a", task_id: "t", payload: {}))
      bus.publish("tool.called", build_event(type: "tool.called", agent_id: "a", task_id: "t", payload: {}))

      assert_equal 2, received_events.length
      assert_includes received_events, "agent.started"
      assert_includes received_events, "agent.completed"
    end

    test "unsubscribe removes subscriber from callback bus" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

      callback_bus = bus.instance_variable_get(:@callback_bus)

      # Add a subscriber
      bus.subscribe("test.pattern") { |channel, event| }

      # Verify subscriber exists
      before_count = callback_bus.instance_variable_get(:@subscriptions).values.flatten.length
      assert before_count > 0

      # Remove the subscriber
      bus.unsubscribe("test.pattern")

      # Verify subscriber was removed
      after_count = callback_bus.instance_variable_get(:@subscriptions).values.flatten.length
      assert_equal 0, after_count
    end

    test "clear removes subscribers does not delete db records" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

      # Add some subscribers
      bus.subscribe("test.*") { |channel, event| }
      bus.subscribe("tool.*") { |channel, event| }

      # Create some DB records
      bus.publish("test.event", build_event(type: "test.event", agent_id: "a", task_id: "t", payload: {}))
      bus.publish("tool.event", build_event(type: "tool.event", agent_id: "a", task_id: "t", payload: {}))

      # Verify DB records exist
      assert_equal 2, WorkflowEvent.count

      # Clear subscribers
      bus.clear

      # Verify subscribers removed but DB records still exist
      callback_bus = bus.instance_variable_get(:@callback_bus)
      after_count = callback_bus.instance_variable_get(:@subscriptions).values.flatten.length
      assert_equal 0, after_count
      assert_equal 2, WorkflowEvent.count
    end

    test "db failure is logged and does not raise" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)
      log_output = StringIO.new
      Rails.logger = Logger.new(log_output)

      @workflow_run.delete

      assert_nothing_raised do
        bus.publish("agent.started", build_event(type: "agent.started", agent_id: "a", task_id: "t", payload: {}))
      end

      assert_match "[PostgresBus] DB write failed:", log_output.string
      assert_match /ActiveRecord::/, log_output.string
    ensure
      Rails.logger = ActiveSupport::Logger.new($stdout)
    end

    test "db failure still delivers to callback bus" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)
      received_events = []
      bus.subscribe("agent.*") { |_channel, event| received_events << event }

      @workflow_run.delete

      assert_nothing_raised do
        bus.publish("agent.started", build_event(type: "agent.started", agent_id: "a", task_id: "t", payload: {}))
      end

      assert_equal 1, received_events.length
      assert_equal "agent.started", received_events.first.type
    end

    test "skip_event_types prevents db write still delivers to callback bus" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: [ "response.chunk" ])

      # Publish a skipped event
      bus.publish("response.chunk", build_event(type: "response.chunk", agent_id: "a", task_id: "t", payload: { content: "chunk" }))

      # Verify no DB record created
      assert_equal 0, WorkflowEvent.where(event_type: "response.chunk").count

      # Verify callback bus still received it
      received_events = []
      bus.subscribe("response.*") do |channel, event|
        received_events << event
      end

      bus.publish("response.chunk", build_event(type: "response.chunk", agent_id: "a", task_id: "t", payload: { content: "chunk2" }))

      assert_equal 1, received_events.length
    end

    test "handles all 12 gem event types" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

      # All 12 gem event types from the source
      event_types = [
        "response.chunk",
        "response.complete",
        "tool.called",
        "tool.result",
        "agent.started",
        "agent.completed",
        "approval.request",
        "approval.response",
        "conversation.compacted",
        "conversation.handoff",
        "conversation.budget_warning",
        "usage_recorded"
      ]

      event_types.each do |type|
        payload = case type
        when "response.chunk"
          { content: "chunk" }
        when "response.complete"
          { usage: { input_tokens: 10, output_tokens: 5 } }
        when "tool.called", "tool.result"
          { tool_name: "power---bash", arguments: {} }
        when "agent.started"
          { profile_name: "qa" }
        when "agent.completed"
          { iterations: 3 }
        when "approval.request", "approval.response"
          { tool_name: "power---bash" }
        when "conversation.compacted"
          { messages_removed: 5, summary_length: 200 }
        when "conversation.handoff"
          { new_task_id: "new-uuid", prompt_excerpt: "continue..." }
        when "conversation.budget_warning"
          { tier: :threshold, usage_percentage: 80.0, remaining_tokens: 1000 }
        when "usage_recorded"
          { agent_id: "a", task_id: "t", input_tokens: 10, output_tokens: 5, message_cost: 0.001 }
        else
          {}
        end

        event = AgentDesk::MessageBus::Event.new(
          type: type,
          agent_id: "test-agent",
          task_id: "task-1",
          payload: payload
        )

        bus.publish(type, event)
      end

      assert_equal 12, WorkflowEvent.count
      event_types.each do |type|
        assert_equal 1, WorkflowEvent.where(event_type: type).count
      end
    end

    test "malformed payload stored with error marker" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

      # Create an event with a non-Hash payload (string)
      event = AgentDesk::MessageBus::Event.new(
        type: "test.event",
        agent_id: "test-agent",
        task_id: "task-1",
        timestamp: Time.now,
        payload: "not a hash"
      )

      bus.publish("test.channel", event)

      workflow_event = WorkflowEvent.last
      # The error marker should be set when payload is not a Hash
      assert workflow_event.payload.key?("error")
      assert_includes workflow_event.payload["error"], "not serializable"
    end

    test "batch_mode_defaults_to_false_and_is_accepted" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)
      assert_equal false, bus.instance_variable_get(:@batch_mode)

      bus_with_mode = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types, batch_mode: true)
      assert_equal true, bus_with_mode.instance_variable_get(:@batch_mode)
    end

    test "subscribe raises argument error on nil or empty pattern" do
      bus = Legion::PostgresBus.new(workflow_run: @workflow_run, skip_event_types: @skip_event_types)

      assert_raises(ArgumentError) do
        bus.subscribe(nil) { |channel, event| }
      end

      assert_raises(ArgumentError) do
        bus.subscribe("") { |channel, event| }
      end
    end

    private

    def build_event(type:, agent_id:, task_id:, payload: {})
      AgentDesk::MessageBus::Event.new(
        type: type,
        agent_id: agent_id,
        task_id: task_id,
        payload: payload
      )
    end
  end
end
