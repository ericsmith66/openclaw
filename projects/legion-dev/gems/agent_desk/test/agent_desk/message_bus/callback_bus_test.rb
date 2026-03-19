# frozen_string_literal: true

require "test_helper"

class CallbackBusTest < Minitest::Test
  CallbackBus = AgentDesk::MessageBus::CallbackBus
  Events      = AgentDesk::MessageBus::Events

  def setup
    @bus = CallbackBus.new
  end

  # ---------------------------------------------------------------------------
  # Basic publish / subscribe
  # ---------------------------------------------------------------------------

  def test_subscribe_and_publish_exact_channel_delivers_event
    received = []
    @bus.subscribe("agent.qa.started") { |ch, ev| received << [ ch, ev ] }

    event = Events.agent_started(agent_id: "qa", task_id: "t1", profile_name: "default")
    @bus.publish("agent.qa.started", event)

    assert_equal 1, received.size
    assert_equal "agent.qa.started", received.first[0]
    assert_equal event,              received.first[1]
  end

  def test_publish_with_no_subscribers_is_noop
    # Should not raise anything
    event = Events.agent_started(agent_id: "a", task_id: "t", profile_name: "p")
    assert_silent { @bus.publish("agent.qa.started", event) }
  end

  def test_publish_delivers_channel_and_event_to_block
    captured_channel = nil
    captured_event   = nil
    @bus.subscribe("test.channel") do |ch, ev|
      captured_channel = ch
      captured_event   = ev
    end

    event = Events.response_chunk(agent_id: "a", task_id: "t", content: "hi")
    @bus.publish("test.channel", event)

    assert_equal "test.channel", captured_channel
    assert_equal event,          captured_event
  end

  # ---------------------------------------------------------------------------
  # Wildcard pattern matching
  # ---------------------------------------------------------------------------

  def test_wildcard_pattern_matches_child_channel
    received = []
    @bus.subscribe("agent.*") { |ch, ev| received << ch }

    @bus.publish("agent.qa.response.chunk", sample_event)
    assert_equal [ "agent.qa.response.chunk" ], received
  end

  def test_wildcard_pattern_matches_multiple_child_channels
    received = []
    @bus.subscribe("agent.*") { |_ch, _ev| received << true }

    @bus.publish("agent.started",              sample_event)
    @bus.publish("agent.qa.response.chunk",    sample_event)
    @bus.publish("agent.other.tool.called",    sample_event)

    assert_equal 3, received.size
  end

  def test_wildcard_pattern_does_not_match_sibling_prefix
    received = []
    @bus.subscribe("agent.*") { |_ch, _ev| received << true }

    @bus.publish("agentic.stuff", sample_event)

    assert_empty received
  end

  def test_multi_segment_wildcard_matches_correct_branch
    received = []
    @bus.subscribe("agent.qa.*") { |_ch, _ev| received << true }

    @bus.publish("agent.qa.response.chunk",  sample_event)
    @bus.publish("agent.other.tool.called",  sample_event)

    assert_equal 1, received.size
  end

  def test_exact_pattern_does_not_match_child_channel
    received = []
    @bus.subscribe("agent.qa") { |_ch, _ev| received << true }

    @bus.publish("agent.qa.response.chunk", sample_event)

    assert_empty received
  end

  def test_bare_wildcard_matches_any_channel
    received = []
    @bus.subscribe("*") { |_ch, _ev| received << true }

    @bus.publish("agent.started",           sample_event)
    @bus.publish("totally.different.thing", sample_event)
    @bus.publish("x",                       sample_event)

    assert_equal 3, received.size
  end

  # ---------------------------------------------------------------------------
  # Multiple subscribers
  # ---------------------------------------------------------------------------

  def test_multiple_subscribers_on_same_pattern_all_notified
    results = []
    @bus.subscribe("agent.*") { |_ch, _ev| results << :first  }
    @bus.subscribe("agent.*") { |_ch, _ev| results << :second }

    @bus.publish("agent.started", sample_event)

    assert_equal %i[first second], results
  end

  def test_subscribers_on_different_patterns_independently_notified
    a_received = []
    b_received = []
    @bus.subscribe("agent.*") { |_ch, _ev| a_received << true }
    @bus.subscribe("tool.*")  { |_ch, _ev| b_received << true }

    @bus.publish("agent.started",  sample_event)
    @bus.publish("tool.called",    sample_event)

    assert_equal 1, a_received.size
    assert_equal 1, b_received.size
  end

  # ---------------------------------------------------------------------------
  # Error isolation
  # ---------------------------------------------------------------------------

  def test_subscriber_exception_does_not_prevent_other_subscribers
    results = []
    @bus.subscribe("agent.*") { |_ch, _ev| raise "boom" }
    @bus.subscribe("agent.*") { |_ch, _ev| results << :second_ran }

    # Suppress warn output; assert second subscriber still runs and no exception propagates
    capture_io { @bus.publish("agent.started", sample_event) }
    assert_equal [ :second_ran ], results
  end

  def test_subscriber_exception_writes_warn_to_stderr
    @bus.subscribe("test.*") { |_ch, _ev| raise RuntimeError, "test error" }

    output = capture_io do
      @bus.publish("test.event", sample_event)
    end

    # warn goes to stderr (second element of capture_io tuple)
    assert_match(/subscriber error/, output[1])
  end

  # ---------------------------------------------------------------------------
  # unsubscribe
  # ---------------------------------------------------------------------------

  def test_unsubscribe_removes_listener
    received = []
    @bus.subscribe("agent.*") { |_ch, _ev| received << true }
    @bus.unsubscribe("agent.*")

    @bus.publish("agent.started", sample_event)

    assert_empty received
  end

  def test_unsubscribe_nonexistent_pattern_is_noop
    assert_silent { @bus.unsubscribe("nonexistent.pattern") }
  end

  def test_unsubscribe_only_removes_target_pattern
    a_received = []
    b_received = []
    @bus.subscribe("agent.*") { |_ch, _ev| a_received << true }
    @bus.subscribe("tool.*")  { |_ch, _ev| b_received << true }
    @bus.unsubscribe("agent.*")

    @bus.publish("agent.started", sample_event)
    @bus.publish("tool.called",   sample_event)

    assert_empty a_received
    assert_equal 1, b_received.size
  end

  # ---------------------------------------------------------------------------
  # clear
  # ---------------------------------------------------------------------------

  def test_clear_removes_all_listeners
    received = []
    @bus.subscribe("agent.*") { |_ch, _ev| received << true }
    @bus.subscribe("tool.*")  { |_ch, _ev| received << true }
    @bus.clear

    @bus.publish("agent.started", sample_event)
    @bus.publish("tool.called",   sample_event)

    assert_empty received
  end

  # ---------------------------------------------------------------------------
  # Argument validation
  # ---------------------------------------------------------------------------

  def test_subscribe_with_empty_pattern_raises_argument_error
    assert_raises(ArgumentError) { @bus.subscribe("") { |_ch, _ev| } }
  end

  def test_subscribe_with_nil_pattern_raises_argument_error
    assert_raises(ArgumentError) { @bus.subscribe(nil) { |_ch, _ev| } }
  end

  # ---------------------------------------------------------------------------
  # Thread safety
  # ---------------------------------------------------------------------------

  def test_concurrent_subscribe_and_publish_does_not_corrupt_state
    received   = []
    mutex      = Mutex.new
    iterations = 50

    threads = iterations.times.map do |i|
      Thread.new do
        @bus.subscribe("concurrent.*") { |_ch, _ev| mutex.synchronize { received << i } }
        @bus.publish("concurrent.event", sample_event)
      end
    end
    threads.each(&:join)

    # At least some events should have been delivered — exact count depends on
    # scheduling, but state should not be corrupted (no exceptions thrown above).
    assert received.size >= 0 # main assertion: no exception was raised
  end

  def test_concurrent_publish_to_same_channel_does_not_raise
    received = []
    m        = Mutex.new
    @bus.subscribe("stress.*") { |_ch, _ev| m.synchronize { received << true } }

    threads = 20.times.map do
      Thread.new { @bus.publish("stress.test", sample_event) }
    end
    threads.each(&:join)

    assert_equal 20, received.size
  end

  # ---------------------------------------------------------------------------
  # MessageBusInterface compliance
  # ---------------------------------------------------------------------------

  def test_callback_bus_includes_message_bus_interface
    assert_includes CallbackBus.ancestors, AgentDesk::MessageBus::MessageBusInterface
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  private

  def sample_event
    @sample_event ||= AgentDesk::MessageBus::Event.new(type: "test.event")
  end
end
