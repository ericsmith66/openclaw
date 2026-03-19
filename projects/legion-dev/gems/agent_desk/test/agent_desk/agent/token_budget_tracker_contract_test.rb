# frozen_string_literal: true

require "test_helper"

# Contract tests for AgentDesk::Agent::TokenBudgetTracker.
#
# These tests verify the public API contract that PRD-0092b (compaction
# strategies) and the Runner depend on. They must pass regardless of internal
# implementation changes.
class TokenBudgetTrackerContractTest < Minitest::Test
  def build_tracker(**opts)
    defaults = { context_window: 200_000, threshold: 80 }
    AgentDesk::Agent::TokenBudgetTracker.new(**defaults.merge(opts))
  end

  # Tracks per-call and cumulative token usage via #record.
  def test_tracks_token_usage
    t = build_tracker
    t.record(sent_tokens: 10_000, received_tokens: 2_000)
    assert_equal 10_000, t.cumulative_sent
    assert_equal 2_000,  t.cumulative_received
    assert_instance_of Hash, t.last_usage
  end

  # #remaining_tokens reflects consumed tokens against context_window.
  def test_provides_current_usage
    t = build_tracker(context_window: 200_000)
    t.record(sent_tokens: 50_000, received_tokens: 5_000)
    assert t.remaining_tokens < 200_000
    assert t.usage_percentage > 0
  end

  # #remaining_budget delegates to #remaining_tokens.
  def test_provides_remaining_budget
    t = build_tracker(context_window: 200_000)
    t.record(sent_tokens: 50_000, received_tokens: 5_000)
    assert_equal t.remaining_tokens, 200_000 - 55_000
  end

  # #threshold_tier returns a Symbol or nil — never raises.
  def test_threshold_tier_returns_symbol_or_nil
    t = build_tracker(threshold: 80)
    t.record(sent_tokens: 180_000)
    tier = t.threshold_tier
    assert(tier.nil? || tier.is_a?(Symbol),
           "expected Symbol or nil, got #{tier.inspect}")
  end
end
