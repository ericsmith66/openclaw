# frozen_string_literal: true

require "test_helper"

class TokenBudgetTrackerTest < Minitest::Test
  RATES = {
    input_cost_per_token:  0.000003,
    output_cost_per_token: 0.000015
  }.freeze

  def tracker(context_window: 200_000, threshold: 0, tiered_thresholds: nil,
              cost_budget: 0, model_rates: nil)
    AgentDesk::Agent::TokenBudgetTracker.new(
      context_window:    context_window,
      threshold:         threshold,
      tiered_thresholds: tiered_thresholds,
      cost_budget:       cost_budget,
      model_rates:       model_rates
    )
  end

  # ---------------------------------------------------------------------------
  # Constructor / initial state
  # ---------------------------------------------------------------------------

  def test_initial_cumulative_values_are_zero
    t = tracker
    assert_equal 0, t.cumulative_sent
    assert_equal 0, t.cumulative_received
    assert_equal 0, t.cumulative_cache_read
    assert_in_delta 0.0, t.cumulative_cost, 0.0000001
  end

  def test_initial_remaining_tokens_equals_context_window
    t = tracker(context_window: 200_000)
    assert_equal 200_000, t.remaining_tokens
  end

  def test_initial_usage_percentage_is_zero
    t = tracker
    assert_in_delta 0.0, t.usage_percentage, 0.0001
  end

  def test_initial_threshold_tier_is_nil
    t = tracker(threshold: 80)
    assert_nil t.threshold_tier
  end

  # ---------------------------------------------------------------------------
  # Record usage — token accumulation
  # ---------------------------------------------------------------------------

  def test_record_accumulates_sent_tokens
    t = tracker
    t.record(sent_tokens: 50_000)
    assert_equal 50_000, t.cumulative_sent
  end

  def test_record_accumulates_received_tokens
    t = tracker
    t.record(received_tokens: 5_000)
    assert_equal 5_000, t.cumulative_received
  end

  def test_record_accumulates_cache_read_tokens
    t = tracker
    t.record(cache_read_tokens: 10_000)
    assert_equal 10_000, t.cumulative_cache_read
  end

  def test_record_multiple_calls_accumulate
    t = tracker(context_window: 200_000)
    t.record(sent_tokens: 50_000, received_tokens: 5_000)
    t.record(sent_tokens: 30_000, received_tokens: 3_000)
    assert_equal 80_000, t.cumulative_sent
    assert_equal 8_000,  t.cumulative_received
  end

  def test_remaining_tokens_decreases_after_record
    t = tracker(context_window: 200_000)
    t.record(sent_tokens: 50_000, received_tokens: 5_000)
    # used = 55_000, remaining = 200_000 - 55_000 = 145_000
    assert_equal 145_000, t.remaining_tokens
  end

  def test_remaining_tokens_never_negative
    t = tracker(context_window: 10_000)
    t.record(sent_tokens: 20_000)
    assert_equal 0, t.remaining_tokens
  end

  def test_usage_percentage_calculation
    t = tracker(context_window: 200_000)
    t.record(sent_tokens: 50_000, received_tokens: 5_000)
    # used = 55_000 / 200_000 * 100 = 27.5
    assert_in_delta 27.5, t.usage_percentage, 0.01
  end

  # ---------------------------------------------------------------------------
  # Threshold detection — flat threshold
  # ---------------------------------------------------------------------------

  def test_threshold_tier_nil_when_below_threshold
    t = tracker(context_window: 200_000, threshold: 80)
    t.record(sent_tokens: 100_000, received_tokens: 10_000)
    # last total = 110_000 / 200_000 = 55% < 80% => nil
    assert_nil t.threshold_tier
  end

  def test_threshold_tier_returns_threshold_when_crossed
    t = tracker(context_window: 200_000, threshold: 80)
    t.record(sent_tokens: 170_000, received_tokens: 10_000)
    # last total = 180_000 / 200_000 = 90% >= 80% => :threshold
    assert_equal :threshold, t.threshold_tier
  end

  def test_threshold_tier_exactly_at_threshold
    t = tracker(context_window: 200_000, threshold: 80)
    t.record(sent_tokens: 160_000)
    # last total = 160_000 / 200_000 = 80.0% >= 80% => :threshold
    assert_equal :threshold, t.threshold_tier
  end

  def test_threshold_zero_disables_checking
    t = tracker(context_window: 200_000, threshold: 0)
    t.record(sent_tokens: 190_000, received_tokens: 9_900)
    assert_nil t.threshold_tier
  end

  # ---------------------------------------------------------------------------
  # Threshold detection — tiered thresholds
  # ---------------------------------------------------------------------------

  def test_tiered_threshold_tier_1_crossed
    t = tracker(
      context_window:    200_000,
      tiered_thresholds: { tier_1: 60, tier_2: 75, tier_3: 85 }
    )
    t.record(sent_tokens: 140_000)
    # 140_000 / 200_000 = 70% >= 60% (tier_1) but < 75% (tier_2) => :tier_1
    assert_equal :tier_1, t.threshold_tier
  end

  def test_tiered_threshold_tier_2_crossed
    t = tracker(
      context_window:    200_000,
      tiered_thresholds: { tier_1: 60, tier_2: 75, tier_3: 85 }
    )
    t.record(sent_tokens: 160_000)
    # 160_000 / 200_000 = 80% >= 75% (tier_2) but < 85% (tier_3) => :tier_2
    assert_equal :tier_2, t.threshold_tier
  end

  def test_tiered_threshold_tier_3_crossed
    t = tracker(
      context_window:    200_000,
      tiered_thresholds: { tier_1: 60, tier_2: 75, tier_3: 85 }
    )
    t.record(sent_tokens: 174_000)
    # 174_000 / 200_000 = 87% >= 85% (tier_3) => :tier_3
    assert_equal :tier_3, t.threshold_tier
  end

  def test_tiered_threshold_nil_when_below_all_tiers
    t = tracker(
      context_window:    200_000,
      tiered_thresholds: { tier_1: 60, tier_2: 75, tier_3: 85 }
    )
    t.record(sent_tokens: 100_000)
    # 100_000 / 200_000 = 50% < 60% => nil
    assert_nil t.threshold_tier
  end

  # ---------------------------------------------------------------------------
  # Nil / missing usage data — graceful handling
  # ---------------------------------------------------------------------------

  def test_record_with_all_nil_values_does_not_raise
    t = tracker(context_window: 200_000, threshold: 80)
    raised = nil
    begin
      t.record(sent_tokens: nil, received_tokens: nil, cache_read_tokens: nil)
    rescue StandardError => e
      raised = e
    end
    assert_nil raised, "expected no exception but got: #{raised&.inspect}"
  end

  def test_record_with_nil_values_does_not_cross_threshold
    t = tracker(context_window: 200_000, threshold: 80)
    t.record(sent_tokens: nil, received_tokens: nil)
    assert_nil t.threshold_tier
  end

  def test_record_with_nil_values_does_not_change_cumulative_counts
    t = tracker
    t.record(sent_tokens: nil, received_tokens: nil)
    assert_equal 0, t.cumulative_sent
    assert_equal 0, t.cumulative_received
  end

  # ---------------------------------------------------------------------------
  # Cost tracking — provider-reported cost
  # ---------------------------------------------------------------------------

  def test_record_with_message_cost_accumulates
    t = tracker
    t.record(sent_tokens: 1000, received_tokens: 500, message_cost: 0.01)
    t.record(sent_tokens: 1000, received_tokens: 500, message_cost: 0.02)
    t.record(sent_tokens: 1000, received_tokens: 500, message_cost: 0.03)
    assert_in_delta 0.06, t.cumulative_cost, 0.0000001
  end

  def test_last_message_cost_reflects_most_recent
    t = tracker
    t.record(message_cost: 0.01)
    t.record(message_cost: 0.05)
    assert_in_delta 0.05, t.last_message_cost, 0.0000001
  end

  # ---------------------------------------------------------------------------
  # Cost tracking — auto-calculation
  # ---------------------------------------------------------------------------

  def test_auto_calculates_cost_when_message_cost_nil
    t = tracker(model_rates: RATES)
    t.record(sent_tokens: 1000, received_tokens: 500, message_cost: nil)
    # (1000 * 0.000003) + (500 * 0.000015) = 0.003 + 0.0075 = 0.0105
    assert_in_delta 0.0105, t.last_message_cost, 0.0000001
    assert_in_delta 0.0105, t.cumulative_cost,   0.0000001
  end

  def test_auto_cost_zero_when_no_rates_configured
    t = tracker(model_rates: nil)
    t.record(sent_tokens: 50_000, received_tokens: 5_000)
    assert_in_delta 0.0, t.last_message_cost, 0.0000001
  end

  # ---------------------------------------------------------------------------
  # Cost budget enforcement
  # ---------------------------------------------------------------------------

  def test_cost_exceeded_false_when_budget_is_zero
    t = tracker(cost_budget: 0, model_rates: RATES)
    t.record(message_cost: 500.0)
    refute t.cost_exceeded?
  end

  def test_cost_exceeded_false_before_budget_is_reached
    t = tracker(cost_budget: 0.10, model_rates: RATES)
    t.record(message_cost: 0.05)
    refute t.cost_exceeded?
  end

  def test_cost_exceeded_true_at_budget_limit
    t = tracker(cost_budget: 0.10)
    t.record(message_cost: 0.10)
    assert t.cost_exceeded?
  end

  def test_cost_exceeded_true_when_over_budget
    t = tracker(cost_budget: 0.10)
    t.record(message_cost: 0.08)
    t.record(message_cost: 0.03)
    # cumulative_cost = 0.11 >= 0.10
    assert t.cost_exceeded?
  end

  def test_cost_exceeded_false_when_nil_budget
    t = tracker(cost_budget: 0)
    t.record(message_cost: 99.99)
    refute t.cost_exceeded?
  end

  # ---------------------------------------------------------------------------
  # Return self for chaining
  # ---------------------------------------------------------------------------

  def test_record_returns_self
    t = tracker
    result = t.record(sent_tokens: 100)
    assert_same t, result
  end
end
