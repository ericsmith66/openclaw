# frozen_string_literal: true

require "test_helper"

class CostCalculatorTest < Minitest::Test
  RATES = {
    input_cost_per_token:       0.000003,
    output_cost_per_token:      0.000015,
    cache_read_cost_per_token:  0.0000003,
    cache_write_cost_per_token: 0.00000375
  }.freeze

  # ---------------------------------------------------------------------------
  # Basic cost computation
  # ---------------------------------------------------------------------------

  def test_calculates_input_and_output_cost
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:     1000,
      completion_tokens: 500,
      model_rates:       RATES
    )
    # (1000 * 0.000003) + (500 * 0.000015) = 0.003 + 0.0075 = 0.0105
    assert_in_delta 0.0105, cost, 0.0000001
  end

  def test_returns_zero_when_no_tokens
    cost = AgentDesk::Agent::CostCalculator.calculate(model_rates: RATES)
    assert_in_delta 0.0, cost, 0.0000001
  end

  def test_includes_cache_read_cost
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:    0,
      completion_tokens: 0,
      cache_read_tokens: 10_000,
      model_rates:       RATES
    )
    # 10_000 * 0.0000003 = 0.003
    assert_in_delta 0.003, cost, 0.0000001
  end

  def test_includes_cache_write_cost
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:      0,
      completion_tokens:  0,
      cache_write_tokens: 200,
      model_rates:        RATES
    )
    # 200 * 0.00000375 = 0.00075
    assert_in_delta 0.00075, cost, 0.0000001
  end

  def test_sums_all_components
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:      1000,
      completion_tokens:  500,
      cache_read_tokens:  2000,
      cache_write_tokens: 100,
      model_rates:        RATES
    )
    expected = (1000 * 0.000003) + (500 * 0.000015) + (2000 * 0.0000003) + (100 * 0.00000375)
    assert_in_delta expected, cost, 0.0000001
  end

  # ---------------------------------------------------------------------------
  # Provider-reported cost override
  # ---------------------------------------------------------------------------

  def test_provider_reported_cost_takes_precedence
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:          1_000_000,
      completion_tokens:      1_000_000,
      model_rates:            RATES,
      provider_reported_cost: 0.042
    )
    assert_in_delta 0.042, cost, 0.0000001
  end

  def test_provider_reported_cost_zero_returns_zero
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:          500,
      completion_tokens:      200,
      model_rates:            RATES,
      provider_reported_cost: 0.0
    )
    assert_in_delta 0.0, cost, 0.0000001
  end

  # ---------------------------------------------------------------------------
  # Nil / missing rates — returns 0, no crash
  # ---------------------------------------------------------------------------

  def test_nil_model_rates_returns_zero
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:     1000,
      completion_tokens: 500,
      model_rates:       nil
    )
    assert_in_delta 0.0, cost, 0.0000001
  end

  def test_empty_model_rates_returns_zero
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:     1000,
      completion_tokens: 500,
      model_rates:       {}
    )
    assert_in_delta 0.0, cost, 0.0000001
  end

  def test_partial_rates_skips_missing_components
    rates = { input_cost_per_token: 0.000003 } # output_cost_per_token missing
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:     1000,
      completion_tokens: 500,
      model_rates:       rates
    )
    # only input contributes: 1000 * 0.000003 = 0.003
    assert_in_delta 0.003, cost, 0.0000001
  end

  def test_nil_token_counts_treated_as_zero
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:     nil,
      completion_tokens: nil,
      model_rates:       RATES
    )
    assert_in_delta 0.0, cost, 0.0000001
  end
end
