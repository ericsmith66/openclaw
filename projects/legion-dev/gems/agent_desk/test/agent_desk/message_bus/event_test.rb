# frozen_string_literal: true

require "test_helper"

class EventTest < Minitest::Test
  Event  = AgentDesk::MessageBus::Event
  Events = AgentDesk::MessageBus::Events

  # ---------------------------------------------------------------------------
  # Event struct
  # ---------------------------------------------------------------------------

  def test_event_initializes_with_required_type
    event = Event.new(type: "response.chunk")
    assert_equal "response.chunk", event.type
  end

  def test_event_defaults_source_to_agent_desk
    event = Event.new(type: "test")
    assert_equal "agent_desk", event.source
  end

  def test_event_defaults_agent_id_to_nil
    event = Event.new(type: "test")
    assert_nil event.agent_id
  end

  def test_event_defaults_task_id_to_nil
    event = Event.new(type: "test")
    assert_nil event.task_id
  end

  def test_event_defaults_payload_to_empty_hash
    event = Event.new(type: "test")
    assert_equal({}, event.payload)
  end

  def test_event_defaults_timestamp_to_approximately_now
    before = Time.now
    event  = Event.new(type: "test")
    after  = Time.now
    assert event.timestamp >= before
    assert event.timestamp <= after
  end

  def test_event_accepts_all_keyword_arguments
    ts    = Time.now
    event = Event.new(
      type:      "tool.called",
      source:    "custom",
      agent_id:  "qa-1",
      task_id:   "task-99",
      timestamp: ts,
      payload:   { tool: "bash" }
    )
    assert_equal "tool.called", event.type
    assert_equal "custom",      event.source
    assert_equal "qa-1",        event.agent_id
    assert_equal "task-99",     event.task_id
    assert_equal ts,            event.timestamp
    assert_equal({ tool: "bash" }, event.payload)
  end

  def test_event_is_immutable
    event = Event.new(type: "test")
    assert_raises(NoMethodError, FrozenError) { event.type = "other" }
  end

  # ---------------------------------------------------------------------------
  # Events convenience constructors
  # ---------------------------------------------------------------------------

  def test_response_chunk_constructor
    ev = Events.response_chunk(agent_id: "a1", task_id: "t1", content: "Hello")
    assert_equal "response.chunk", ev.type
    assert_equal "a1",             ev.agent_id
    assert_equal "t1",             ev.task_id
    assert_equal "Hello",          ev.payload[:content]
  end

  def test_response_complete_constructor
    ev = Events.response_complete(agent_id: "a1", task_id: "t1", usage: { tokens: 50 })
    assert_equal "response.complete", ev.type
    assert_equal({ tokens: 50 },      ev.payload[:usage])
  end

  def test_response_complete_defaults_usage_to_empty_hash
    ev = Events.response_complete(agent_id: "a1", task_id: "t1")
    assert_equal({}, ev.payload[:usage])
  end

  def test_tool_called_constructor
    ev = Events.tool_called(agent_id: "a1", task_id: "t1", tool_name: "power---bash", arguments: { cmd: "ls" })
    assert_equal "tool.called",   ev.type
    assert_equal "power---bash",  ev.payload[:tool_name]
    assert_equal({ cmd: "ls" },   ev.payload[:arguments])
  end

  def test_tool_result_constructor
    ev = Events.tool_result(agent_id: "a1", task_id: "t1", tool_name: "power---bash", result: "file.rb")
    assert_equal "tool.result",  ev.type
    assert_equal "power---bash", ev.payload[:tool_name]
    assert_equal "file.rb",      ev.payload[:result]
  end

  def test_agent_started_constructor
    ev = Events.agent_started(agent_id: "a1", task_id: "t1", profile_name: "default")
    assert_equal "agent.started", ev.type
    assert_equal "default",       ev.payload[:profile_name]
  end

  def test_agent_completed_constructor
    ev = Events.agent_completed(agent_id: "a1", task_id: "t1", iterations: 5)
    assert_equal "agent.completed", ev.type
    assert_equal 5,                 ev.payload[:iterations]
  end

  def test_approval_request_constructor
    ev = Events.approval_request(agent_id: "a1", task_id: "t1", tool_name: "power---bash")
    assert_equal "approval.request", ev.type
    assert_equal "power---bash",     ev.payload[:tool_name]
  end

  def test_approval_response_constructor_approved
    ev = Events.approval_response(agent_id: "a1", task_id: "t1", tool_name: "power---bash", approved: true)
    assert_equal "approval.response", ev.type
    assert_equal true,                ev.payload[:approved]
  end

  def test_approval_response_constructor_denied
    ev = Events.approval_response(agent_id: "a1", task_id: "t1", tool_name: "power---bash", approved: false)
    assert_equal false, ev.payload[:approved]
  end

  # ---------------------------------------------------------------------------
  # Compaction events (PRD-0092b)
  # ---------------------------------------------------------------------------

  def test_conversation_compacted_constructor
    ev = Events.conversation_compacted(agent_id: "a1", task_id: "t1", messages_removed: 6, summary_length: 500)
    assert_equal "conversation.compacted", ev.type
    assert_equal "a1",                     ev.agent_id
    assert_equal "t1",                     ev.task_id
    assert_equal 6,                        ev.payload[:messages_removed]
    assert_equal 500,                      ev.payload[:summary_length]
  end

  def test_conversation_handoff_constructor
    ev = Events.conversation_handoff(agent_id: "a1", task_id: "t1", new_task_id: "new-uuid-123", prompt_excerpt: "Continue from here...")
    assert_equal "conversation.handoff", ev.type
    assert_equal "new-uuid-123",         ev.payload[:new_task_id]
    assert_equal "Continue from here...", ev.payload[:prompt_excerpt]
  end

  def test_token_budget_warning_constructor
    ev = Events.token_budget_warning(
      agent_id: "a1", task_id: "t1",
      tier: :tier_1, usage_percentage: 65.0, remaining_tokens: 70_000
    )
    assert_equal "conversation.budget_warning", ev.type
    assert_equal :tier_1,                       ev.payload[:tier]
    assert_in_delta 65.0,                       ev.payload[:usage_percentage], 0.01
    assert_equal 70_000,                        ev.payload[:remaining_tokens]
  end

  def test_all_events_use_agent_desk_source
    constructors = [
      -> { Events.response_chunk(agent_id: "a", task_id: "t", content: "x") },
      -> { Events.response_complete(agent_id: "a", task_id: "t") },
      -> { Events.tool_called(agent_id: "a", task_id: "t", tool_name: "n") },
      -> { Events.tool_result(agent_id: "a", task_id: "t", tool_name: "n", result: "r") },
      -> { Events.agent_started(agent_id: "a", task_id: "t", profile_name: "p") },
      -> { Events.agent_completed(agent_id: "a", task_id: "t", iterations: 1) },
      -> { Events.approval_request(agent_id: "a", task_id: "t", tool_name: "n") },
      -> { Events.approval_response(agent_id: "a", task_id: "t", tool_name: "n", approved: true) },
      -> { Events.conversation_compacted(agent_id: "a", task_id: "t", messages_removed: 2, summary_length: 100) },
      -> { Events.conversation_handoff(agent_id: "a", task_id: "t", new_task_id: "id", prompt_excerpt: "x") },
      -> { Events.token_budget_warning(agent_id: "a", task_id: "t", tier: :tier_1, usage_percentage: 60.0, remaining_tokens: 80_000) }
    ]
    constructors.each do |lam|
      ev = lam.call
      assert_equal "agent_desk", ev.source, "Expected source 'agent_desk' for #{ev.type}"
    end
  end
end
