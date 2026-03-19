# frozen_string_literal: true

require "test_helper"

class CompactionStrategyContractTest < Minitest::Test
  def build_mock_mm(content = "Summary")
    AgentDesk::Test::MockModelManager.new(
      responses: [
        { role: "assistant", content: content, tool_calls: nil,
          usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 } }
      ]
    )
  end

  def sample_conversation
    [
      { role: "user", content: "Do the thing" },
      { role: "assistant", content: "On it" }
    ]
  end

  def sample_snapshot
    AgentDesk::Agent::StateSnapshot.build(original_prompt: "Do the thing", conversation: [])
  end

  def test_compact_strategy_returns_continue_or_stop
    strategy = AgentDesk::Agent::CompactStrategy.new
    result = strategy.execute(
      context: { project_dir: "/tmp" }, conversation: sample_conversation,
      state_snapshot: sample_snapshot, model_manager: build_mock_mm
    )
    assert_includes [ :continue, :stop ], result
  end

  def test_handoff_strategy_returns_continue_or_stop
    strategy = AgentDesk::Agent::HandoffStrategy.new
    result = strategy.execute(
      context: { project_dir: "/tmp" }, conversation: sample_conversation,
      state_snapshot: sample_snapshot, model_manager: build_mock_mm
    )
    assert_includes [ :continue, :stop ], result
  end

  def test_tiered_strategy_returns_continue_or_stop
    strategy = AgentDesk::Agent::TieredStrategy.new
    result = strategy.execute(
      context: { project_dir: "/tmp", threshold_tier: :tier_1 },
      conversation: sample_conversation.dup,
      state_snapshot: sample_snapshot,
      model_manager: build_mock_mm
    )
    assert_includes [ :continue, :stop ], result
  end

  def test_strategies_accept_optional_hook_manager_and_message_bus
    strategy = AgentDesk::Agent::CompactStrategy.new
    hm = AgentDesk::Hooks::HookManager.new
    bus = AgentDesk::MessageBus::CallbackBus.new

    # Should not raise
    strategy.execute(
      context: { project_dir: "/tmp" }, conversation: sample_conversation,
      state_snapshot: sample_snapshot, model_manager: build_mock_mm,
      hook_manager: hm, message_bus: bus
    )
  end
end
