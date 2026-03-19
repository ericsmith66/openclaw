# frozen_string_literal: true

module NetWorth
  class SummaryCardComponent < BaseCardComponent
    def initialize(summary:, timestamp: nil)
      @summary = summary.to_h
      @timestamp = timestamp
    end

    private

    attr_reader :summary, :timestamp

    def total
      safe_to_f(safe_get(summary, :total, 0.0))
    end

    def day_delta_usd
      safe_to_f(safe_get(summary, :day_delta_usd, 0.0))
    end

    def day_delta_pct
      safe_to_f(safe_get(summary, :day_delta_pct, computed_day_delta_pct))
    end

    def thirty_day_delta_usd
      safe_to_f(safe_get(summary, :thirty_day_delta_usd, 0.0))
    end

    def thirty_day_delta_pct
      safe_to_f(safe_get(summary, :thirty_day_delta_pct, computed_thirty_day_delta_pct))
    end

    def computed_day_delta_pct
      base = total - day_delta_usd
      return 0.0 if base.to_f.zero?

      (day_delta_usd / base) * 100.0
    end

    def computed_thirty_day_delta_pct
      base = total - thirty_day_delta_usd
      return 0.0 if base.to_f.zero?

      (thirty_day_delta_usd / base) * 100.0
    end

    def last_updated_text
      return nil if timestamp.nil?

      "Last updated #{time_ago_in_words(timestamp)} ago"
    end

    def delta_style(delta)
      delta.to_f >= 0 ? "text-success" : "text-error"
    end

    def delta_symbol(delta)
      delta.to_f >= 0 ? "↑" : "↓"
    end

    def signed_currency(delta)
      amount = number_to_currency(delta.to_f, precision: 0)
      delta.to_f >= 0 ? "+#{amount}" : amount
    end

    def signed_percentage(pct)
      formatted = number_to_percentage(pct.to_f.abs, precision: 1)
      pct.to_f >= 0 ? "+#{formatted}" : "-#{formatted}"
    end
  end
end
