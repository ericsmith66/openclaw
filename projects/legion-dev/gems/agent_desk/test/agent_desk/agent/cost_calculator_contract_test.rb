# frozen_string_literal: true

require "test_helper"

# Contract tests for AgentDesk::Agent::CostCalculator.
#
# These tests verify the public API contract that TokenBudgetTracker and the
# Runner depend on. They must pass regardless of internal implementation changes.
class CostCalculatorContractTest < Minitest::Test
  RATES = {
    input_cost_per_token:  0.000003,
    output_cost_per_token: 0.000015
  }.freeze

  # #calculate returns a non-negative Float.
  def test_calculates_token_cost
    cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:     1000,
      completion_tokens: 500,
      model_rates:       RATES
    )
    assert_instance_of Float, cost
    assert cost >= 0, "cost must be non-negative"
    # (1000 * 0.000003) + (500 * 0.000015) = 0.0105
    assert_in_delta 0.0105, cost, 0.0000001
  end

  # Supports any model rates hash — nil rates return 0 without raising.
  def test_supports_provider_models
    # Nil rates → 0
    nil_cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:     1000,
      completion_tokens: 500,
      model_rates:       nil
    )
    assert_in_delta 0.0, nil_cost, 0.0000001

    # Different provider rates
    custom_rates = { input_cost_per_token: 0.000010, output_cost_per_token: 0.000030 }
    custom_cost = AgentDesk::Agent::CostCalculator.calculate(
      prompt_tokens:     500,
      completion_tokens: 200,
      model_rates:       custom_rates
    )
    expected = (500 * 0.000010) + (200 * 0.000030)
    assert_in_delta expected, custom_cost, 0.0000001
  end
end
