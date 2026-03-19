# frozen_string_literal: true

module AgentDesk
  module Agent
    # Computes the cost of a single LLM call from token counts and per-token rates.
    #
    # Mirrors AiderDesk's +calculateCost()+ from +src/main/models/providers/default.ts+.
    #
    # Cost formula:
    #   input_cost        = prompt_tokens    * input_cost_per_token
    #   output_cost       = completion_tokens * output_cost_per_token
    #   cache_read_cost   = cache_read_tokens  * cache_read_cost_per_token
    #   cache_write_cost  = cache_write_tokens * cache_write_cost_per_token
    #   total             = input_cost + output_cost + cache_read_cost + cache_write_cost
    #
    # When +provider_reported_cost+ is provided it takes precedence over the
    # calculated value — matching AiderDesk's provider-override pattern (e.g.
    # OpenRouter returns a pre-computed cost in the API response).
    #
    # All nil/zero rate components return 0.0 rather than raising an error.
    #
    # @example Basic calculation
    #   rates = {
    #     input_cost_per_token:  0.000003,
    #     output_cost_per_token: 0.000015
    #   }
    #   CostCalculator.calculate(prompt_tokens: 1000, completion_tokens: 500, model_rates: rates)
    #   # => 0.0105
    #
    # @example Provider-override
    #   CostCalculator.calculate(
    #     prompt_tokens: 1000, completion_tokens: 500,
    #     model_rates: rates,
    #     provider_reported_cost: 0.042
    #   )
    #   # => 0.042
    module CostCalculator
      # Calculates the cost for a single LLM call.
      #
      # @param prompt_tokens [Integer, nil] tokens sent to the LLM
      # @param completion_tokens [Integer, nil] tokens received from the LLM
      # @param cache_read_tokens [Integer, nil] cache-read input tokens (optional)
      # @param cache_write_tokens [Integer, nil] cache-write input tokens (optional)
      # @param model_rates [Hash, nil] per-token cost rates hash with keys:
      #   +:input_cost_per_token+, +:output_cost_per_token+,
      #   +:cache_read_cost_per_token+, +:cache_write_cost_per_token+
      # @param provider_reported_cost [Float, nil] when present, returned as-is
      # @return [Float] computed (or provider-reported) cost in dollars
      def self.calculate(
        prompt_tokens: 0,
        completion_tokens: 0,
        cache_read_tokens: 0,
        cache_write_tokens: 0,
        model_rates: nil,
        provider_reported_cost: nil
      )
        return provider_reported_cost.to_f if provider_reported_cost

        rates = model_rates || {}

        input_rate        = rates[:input_cost_per_token].to_f
        output_rate       = rates[:output_cost_per_token].to_f
        cache_read_rate   = rates[:cache_read_cost_per_token].to_f
        cache_write_rate  = rates[:cache_write_cost_per_token].to_f

        input_cost       = (prompt_tokens.to_i)    * input_rate
        output_cost      = (completion_tokens.to_i) * output_rate
        cache_read_cost  = (cache_read_tokens.to_i)  * cache_read_rate
        cache_write_cost = (cache_write_tokens.to_i) * cache_write_rate

        input_cost + output_cost + cache_read_cost + cache_write_cost
      end
    end
  end
end
