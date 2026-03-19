# frozen_string_literal: true

require "test_helper"

class HookManagerContractTest < Minitest::Test
  def setup
    @manager = AgentDesk::Hooks::HookManager.new
  end

  def test_responds_to_on
    # HookManager#on(event, &block) registers a hook
    assert_respond_to @manager, :on
    assert_equal @manager, @manager.on(:on_tool_called) { nil }
  end

  def test_responds_to_trigger
    # HookManager#trigger(event, *args) triggers hooks
    assert_respond_to @manager, :trigger
    result = @manager.trigger(:on_tool_called)
    assert_kind_of AgentDesk::Hooks::HookResult, result
    refute result.blocked
  end

  def test_responds_to_clear
    # HookManager#clear(event) clears hooks for event
    assert_respond_to @manager, :clear
    assert_equal @manager, @manager.clear
  end

  def test_trigger_returns_blocked_result
    # HookManager#trigger returns blocked result when hook blocks
    @manager.on(:on_tool_called) do |_event, _context|
      AgentDesk::Hooks::HookResult.new(blocked: true)
    end
    result = @manager.trigger(:on_tool_called)
    assert_kind_of AgentDesk::Hooks::HookResult, result
    assert result.blocked
  end

  def test_responds_to_register_event
    # HookManager#register_event(event) allows adding new event types
    assert_respond_to @manager, :register_event
    assert_equal @manager, @manager.register_event(:custom_event)
  end
end
