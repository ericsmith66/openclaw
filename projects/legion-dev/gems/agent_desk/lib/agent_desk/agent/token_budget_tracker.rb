# frozen_string_literal: true

module AgentDesk
  module Agent
    # Tracks cumulative token usage and cost throughout an agent run.
    #
    # Mirrors AiderDesk's inline budget tracking in +compactMessagesIfNeeded()+
    # (agent.ts:1620-1688). This class is the *data/measurement layer* — it
    # records usage and reports threshold tier crossings but never acts on them.
    # Acting is the responsibility of PRD-0092b's compaction strategies.
    #
    # == Threshold model
    #
    # Token threshold is checked against the *last* LLM response's usage
    # (+sent + received + cache_read+), matching AiderDesk's approach.
    # Cumulative totals are also tracked for consumers who want trend-based
    # decisions.
    #
    # A +context_compacting_threshold+ of 0 disables token threshold checking.
    # A +cost_budget+ of 0 (or nil) means unlimited — no cost checking.
    #
    # == Tiered thresholds
    #
    # When +tiered_thresholds+ is provided as a hash (e.g.
    # +{ tier_1: 60, tier_2: 75, tier_3: 85 }+), {#threshold_tier} returns the
    # highest crossed tier key. When only a flat +threshold+ is set, the method
    # returns +:threshold+ if crossed, +nil+ otherwise.
    #
    # @example Basic usage
    #   tracker = TokenBudgetTracker.new(context_window: 200_000, threshold: 80)
    #   tracker.record(sent_tokens: 50_000, received_tokens: 5_000)
    #   tracker.usage_percentage  # => 27.5
    #   tracker.remaining_tokens  # => 145_000
    #   tracker.threshold_tier    # => nil  (below 80%)
    #
    # @example Tiered thresholds
    #   tracker = TokenBudgetTracker.new(
    #     context_window:    200_000,
    #     tiered_thresholds: { tier_1: 60, tier_2: 75, tier_3: 85 }
    #   )
    #   tracker.record(sent_tokens: 140_000, received_tokens: 10_000)
    #   tracker.threshold_tier  # => :tier_1  (75% usage, tier_1 crossed at 60%)
    class TokenBudgetTracker
      # @!attribute [r] context_window
      #   @return [Integer] maximum input tokens for the model (e.g. 200_000)
      attr_reader :context_window

      # @!attribute [r] threshold
      #   @return [Integer] flat token-usage percentage that triggers action (0 = disabled)
      attr_reader :threshold

      # @!attribute [r] tiered_thresholds
      #   @return [Hash, nil] tiered threshold levels, e.g. +{ tier_1: 60, tier_2: 75, tier_3: 85 }+
      attr_reader :tiered_thresholds

      # @!attribute [r] cost_budget
      #   @return [Float] cost cap in dollars (0 = unlimited)
      attr_reader :cost_budget

      # @!attribute [r] model_rates
      #   @return [Hash, nil] per-token cost rates for auto-calculating cost
      attr_reader :model_rates

      # @!attribute [r] cumulative_sent
      #   @return [Integer] total tokens sent across all iterations
      attr_reader :cumulative_sent

      # @!attribute [r] cumulative_received
      #   @return [Integer] total tokens received across all iterations
      attr_reader :cumulative_received

      # @!attribute [r] cumulative_cache_read
      #   @return [Integer] total cache-read tokens across all iterations
      attr_reader :cumulative_cache_read

      # @!attribute [r] cumulative_cost
      #   @return [Float] total cost in dollars across all LLM calls
      attr_reader :cumulative_cost

      # @!attribute [r] last_usage
      #   @return [Hash, nil] usage data from the most recent LLM call
      attr_reader :last_usage

      # @!attribute [r] last_message_cost
      #   @return [Float] cost of the most recent LLM call
      attr_reader :last_message_cost

      # Creates a new TokenBudgetTracker.
      #
      # @param context_window [Integer] model's max input token count
      # @param threshold [Integer] flat usage percentage threshold (0 = disabled)
      # @param tiered_thresholds [Hash, nil] tiered threshold hash (keys used as tier names)
      # @param cost_budget [Float] cost cap per run in dollars (0 = unlimited)
      # @param model_rates [Hash, nil] per-token cost rates for auto-cost calculation
      def initialize(
        context_window:,
        threshold: 0,
        tiered_thresholds: nil,
        cost_budget: 0,
        model_rates: nil
      )
        @context_window    = context_window.to_i
        @threshold         = threshold.to_i
        @tiered_thresholds = tiered_thresholds
        @cost_budget       = cost_budget.to_f
        @model_rates       = model_rates

        @cumulative_sent       = 0
        @cumulative_received   = 0
        @cumulative_cache_read = 0
        @cumulative_cost       = 0.0
        @last_usage            = nil
        @last_message_cost     = 0.0
      end

      # Records token usage and cost from a single LLM response.
      #
      # When +message_cost+ is nil, cost is auto-computed using {CostCalculator}
      # and the +model_rates+ supplied at construction.
      #
      # Nil token values are treated as 0 — no exception is raised (graceful
      # handling of providers that omit some usage fields).
      #
      # @param sent_tokens [Integer, nil] tokens sent (prompt tokens)
      # @param received_tokens [Integer, nil] tokens received (completion tokens)
      # @param cache_read_tokens [Integer, nil] cache-read input tokens
      # @param cache_write_tokens [Integer, nil] cache-write input tokens (cost only)
      # @param message_cost [Float, nil] provider-reported cost; nil = auto-calculate
      # @return [self]
      def record(
        sent_tokens: nil,
        received_tokens: nil,
        cache_read_tokens: nil,
        cache_write_tokens: nil,
        message_cost: nil
      )
        sent       = sent_tokens.to_i
        received   = received_tokens.to_i
        cache_read = cache_read_tokens.to_i
        cache_write = cache_write_tokens.to_i

        @cumulative_sent       += sent
        @cumulative_received   += received
        @cumulative_cache_read += cache_read

        @last_usage = {
          sent_tokens:        sent,
          received_tokens:    received,
          cache_read_tokens:  cache_read,
          cache_write_tokens: cache_write
        }

        @last_message_cost = if message_cost
          message_cost.to_f
        else
          CostCalculator.calculate(
            prompt_tokens:     sent,
            completion_tokens: received,
            cache_read_tokens: cache_read,
            cache_write_tokens: cache_write,
            model_rates:       @model_rates
          )
        end

        @cumulative_cost += @last_message_cost

        self
      end

      # Computes tokens remaining before the context window is exhausted.
      #
      # Uses cumulative totals (sent + received + cache_read) to give a
      # conservative remaining estimate.
      #
      # @return [Integer] remaining tokens (never negative)
      def remaining_tokens
        used = @cumulative_sent + @cumulative_received + @cumulative_cache_read
        [ @context_window - used, 0 ].max
      end

      # Computes the percentage of the context window consumed (cumulative).
      #
      # @return [Float] percentage 0.0 – 100.0
      def usage_percentage
        return 0.0 if @context_window.zero?

        used = @cumulative_sent + @cumulative_received + @cumulative_cache_read
        (used.to_f / @context_window) * 100.0
      end

      # Returns the current threshold tier based on last-response token usage,
      # mirroring AiderDesk's check.
      #
      # When +tiered_thresholds+ is set, returns the highest tier key whose
      # percentage is exceeded by the last response's token total. Returns +nil+
      # if no tier is crossed.
      #
      # When only a flat +threshold+ is set (and non-zero), returns +:threshold+
      # if the last response's token total exceeds the threshold percentage.
      #
      # Returns +nil+ when no threshold is configured or no usage has been recorded.
      #
      # @return [Symbol, nil] tier key or +:threshold+ or +nil+
      def threshold_tier
        return nil if @last_usage.nil?

        last_total = @last_usage[:sent_tokens] +
                     @last_usage[:received_tokens] +
                     @last_usage[:cache_read_tokens]

        return nil if @context_window.zero?

        last_pct = (last_total.to_f / @context_window) * 100.0

        if @tiered_thresholds
          # Return the highest crossed tier
          crossed = @tiered_thresholds.select { |_k, pct| last_pct >= pct }
          return nil if crossed.empty?

          # Sort by threshold value descending and return the highest key
          crossed.max_by { |_k, pct| pct }&.first
        elsif @threshold.positive?
          last_pct >= @threshold ? :threshold : nil
        end
      end

      # Returns true when the cost budget is set (> 0) and cumulative cost
      # has reached or exceeded it.
      #
      # Always returns false when +cost_budget+ is 0 (unlimited).
      #
      # @return [Boolean]
      def cost_exceeded?
        @cost_budget.positive? && @cumulative_cost >= @cost_budget
      end
    end
  end
end
