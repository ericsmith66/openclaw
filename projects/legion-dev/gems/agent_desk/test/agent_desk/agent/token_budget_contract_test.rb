# frozen_string_literal: true

require "test_helper"

# Contract tests for the TokenBudget sub-system (TokenBudgetTracker + CostCalculator).
#
# These tests verify integration-level contracts:
# - Usage is tracked across multiple record calls
# - Threshold tier crossing is correctly detected
# - Cost budget enforcement works independently of token thresholds
class TokenBudgetContractTest < Minitest::Test
  def build_tracker(**opts)
    defaults = { context_window: 200_000, threshold: 80 }
    AgentDesk::Agent::TokenBudgetTracker.new(**defaults.merge(opts))
  end

  # Cumulative token counts accumulate correctly across multiple calls.
  def test_tracks_usage
    t = build_tracker
    t.record(sent_tokens: 10_000, received_tokens: 1_000)
    t.record(sent_tokens: 20_000, received_tokens: 2_000)
    assert_equal 30_000, t.cumulative_sent
    assert_equal 3_000,  t.cumulative_received
  end

  # Threshold tier changes when usage crosses the configured percentage.
  def test_triggers_compaction
    t = build_tracker(context_window: 200_000, threshold: 80)
    # Below threshold
    t.record(sent_tokens: 100_000)
    assert_nil t.threshold_tier
    # Cross threshold — last response alone exceeds 80%
    t2 = build_tracker(context_window: 200_000, threshold: 80)
    t2.record(sent_tokens: 170_000)
    assert_equal :threshold, t2.threshold_tier
  end

  # cost_exceeded? returns true once cumulative cost >= cost_budget.
  def test_triggers_handoff
    t = build_tracker(cost_budget: 0.50)
    t.record(message_cost: 0.30)
    refute t.cost_exceeded?
    t.record(message_cost: 0.25)
    assert t.cost_exceeded?
  end
end
