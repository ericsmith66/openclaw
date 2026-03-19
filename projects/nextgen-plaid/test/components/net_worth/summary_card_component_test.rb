# frozen_string_literal: true

require "test_helper"

class NetWorth::SummaryCardComponentTest < ViewComponent::TestCase
  def test_renders_formatted_total_and_deltas
    summary = {
      total: 1_234_567.89,
      day_delta_usd: 12_345,
      day_delta_pct: 1.2,
      thirty_day_delta_usd: -45_678,
      thirty_day_delta_pct: -3.8
    }

    rendered = render_inline(NetWorth::SummaryCardComponent.new(summary: summary, timestamp: 3.hours.ago))

    assert_includes rendered.css(".net-worth-total").text, "$1,234,568"
    assert_includes rendered.css(".delta-day").text, "+$12,345"
    assert_includes rendered.css(".delta-30d").text, "-$45,678"
    assert_match(/Last updated .* ago/, rendered.css(".timestamp").text)
  end
end
