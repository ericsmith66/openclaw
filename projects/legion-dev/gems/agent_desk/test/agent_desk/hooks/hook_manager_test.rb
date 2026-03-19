# frozen_string_literal: true

require "test_helper"

class HookManagerTest < Minitest::Test
  def setup
    @manager = AgentDesk::Hooks::HookManager.new
  end

  # HookResult tests
  def test_hook_result_defaults
    result = AgentDesk::Hooks::HookResult.new
    refute result.blocked
    assert_equal({}, result.event)
    assert_nil result.result
  end

  def test_hook_result_with_values
    result = AgentDesk::Hooks::HookResult.new(blocked: true, event: { foo: :bar }, result: 42)
    assert result.blocked
    assert_equal({ foo: :bar }, result.event)
    assert_equal 42, result.result
  end

  # HookManager#on
  def test_on_registers_handler
    called = false
    @manager.on(:on_tool_called) { called = true }
    @manager.trigger(:on_tool_called)
    assert called
  end

  def test_on_returns_self_for_chaining
    assert_same @manager, @manager.on(:on_tool_called) { nil }
  end

  def test_on_with_unregistered_event_raises
    assert_raises(ArgumentError) do
      @manager.on(:unknown_event) { nil }
    end
  end

  # HookManager#trigger
  def test_trigger_with_no_handlers_returns_unblocked_result
    result = @manager.trigger(:on_tool_called, { arg: 1 }, { ctx: 2 })
    assert_kind_of AgentDesk::Hooks::HookResult, result
    refute result.blocked
    assert_equal({ arg: 1 }, result.event)
    assert_nil result.result
  end

  def test_trigger_passes_event_data_and_context_to_handler
    captured_event = nil
    captured_context = nil
    @manager.on(:on_tool_called) do |event, context|
      captured_event = event
      captured_context = context
      nil
    end
    @manager.trigger(:on_tool_called, { tool: :bash }, { user: :admin })
    assert_equal({ tool: :bash }, captured_event)
    assert_equal({ user: :admin }, captured_context)
  end

  def test_trigger_handlers_called_in_registration_order
    calls = []
    @manager.on(:on_tool_called) { calls << 1 }
    @manager.on(:on_tool_called) { calls << 2 }
    @manager.trigger(:on_tool_called)
    assert_equal [ 1, 2 ], calls
  end

  def test_trigger_ignores_nil_handler_result
    @manager.on(:on_tool_called) { nil }
    result = @manager.trigger(:on_tool_called)
    refute result.blocked
  end

  def test_trigger_updates_event_data_with_hook_result_event
    @manager.on(:on_tool_called) do |event, _|
      AgentDesk::Hooks::HookResult.new(event: event.merge(modified: true))
    end
    result = @manager.trigger(:on_tool_called, { original: 1 })
    assert_equal({ original: 1, modified: true }, result.event)
  end

  def test_trigger_does_not_update_event_if_event_empty
    @manager.on(:on_tool_called) do |_, _|
      AgentDesk::Hooks::HookResult.new(event: {})
    end
    result = @manager.trigger(:on_tool_called, { original: 1 })
    assert_equal({ original: 1 }, result.event)
  end

  def test_trigger_stores_last_non_nil_result
    @manager.on(:on_tool_called) { AgentDesk::Hooks::HookResult.new(result: :first) }
    @manager.on(:on_tool_called) { AgentDesk::Hooks::HookResult.new(result: :second) }
    result = @manager.trigger(:on_tool_called)
    assert_equal :second, result.result
  end

  def test_trigger_short_circuits_on_blocked
    calls = []
    @manager.on(:on_tool_called) { calls << 1 }
    @manager.on(:on_tool_called) do
      calls << 2
      AgentDesk::Hooks::HookResult.new(blocked: true)
    end
    @manager.on(:on_tool_called) { calls << 3 }
    result = @manager.trigger(:on_tool_called)
    assert result.blocked
    assert_equal [ 1, 2 ], calls
  end

  def test_trigger_returns_blocked_result_with_correct_event_and_result
    @manager.on(:on_tool_called) do |event, _|
      AgentDesk::Hooks::HookResult.new(blocked: true, event: event.merge(blocked_at: Time.now), result: :denied)
    end
    result = @manager.trigger(:on_tool_called, { tool: :bash })
    assert result.blocked
    assert_equal :denied, result.result
    assert_equal({ tool: :bash, blocked_at: result.event[:blocked_at] }, result.event)
  end

  def test_trigger_propagates_handler_exception
    @manager.on(:on_tool_called) { raise "handler error" }
    assert_raises(RuntimeError) { @manager.trigger(:on_tool_called) }
  end

  # HookManager#clear
  def test_clear_specific_event
    called = false
    @manager.on(:on_tool_called) { called = true }
    @manager.clear(:on_tool_called)
    @manager.trigger(:on_tool_called)
    refute called
  end

  def test_clear_all_events
    called1 = false
    called2 = false
    @manager.on(:on_tool_called) { called1 = true }
    @manager.on(:on_agent_started) { called2 = true }
    @manager.clear
    @manager.trigger(:on_tool_called)
    @manager.trigger(:on_agent_started)
    refute called1
    refute called2
  end

  def test_clear_returns_self
    assert_same @manager, @manager.clear
  end

  # HookManager#register_event
  def test_register_event_adds_new_event_type
    @manager.register_event(:custom_event)
    called = false
    @manager.on(:custom_event) { called = true }
    @manager.trigger(:custom_event)
    assert called
  end

  def test_register_event_idempotent
    @manager.register_event(:custom_event)
    @manager.register_event(:custom_event) # should not raise
    called = false
    @manager.on(:custom_event) { called = true }
    @manager.trigger(:custom_event)
    assert called
  end

  def test_register_event_returns_self
    assert_same @manager, @manager.register_event(:custom_event)
  end

  # on_handle_approval boolean result override
  def test_on_handle_approval_result_boolean
    @manager.on(:on_handle_approval) do |_, _|
      AgentDesk::Hooks::HookResult.new(result: false)
    end
    result = @manager.trigger(:on_handle_approval)
    assert_equal false, result.result
  end

  # Thread safety (basic)
  def test_concurrent_modification_during_trigger
    # This test ensures that handlers added after trigger started are not called.
    # We simulate by adding a handler from within another handler.
    inner_called = false
    outer_called = false
    @manager.on(:on_tool_called) do
      outer_called = true
      @manager.on(:on_tool_called) { inner_called = true }
    end
    result = @manager.trigger(:on_tool_called)
    refute result.blocked
    assert outer_called
    refute inner_called, "Handler added during trigger should not be called in same run"
  end

  def test_thread_safe_handler_registration
    # This is a simple sanity check; real concurrency testing would require
    # multiple threads, but we trust Mutex.
    threads = 10.times.map do |i|
      Thread.new do
        @manager.on(:on_tool_called) { "handler #{i}" }
      end
    end
    threads.each(&:join)
    # Should have 10 handlers
    handlers = nil
    @manager.instance_variable_get(:@mutex).synchronize do
      handlers = @manager.instance_variable_get(:@handlers)[:on_tool_called].dup
    end
    assert_equal 10, handlers.size
  end

  # Edge cases
  def test_trigger_with_empty_event_data
    result = @manager.trigger(:on_tool_called, {})
    assert_equal({}, result.event)
  end

  def test_trigger_with_nil_context
    @manager.on(:on_tool_called) do |event, context|
      assert_nil context
      nil
    end
    @manager.trigger(:on_tool_called, {}, nil)
  end
end
