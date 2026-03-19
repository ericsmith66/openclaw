# frozen_string_literal: true

require "test_helper"

class NetWorth::HoldingsSummaryComponentTest < ViewComponent::TestCase
  def test_renders_empty_state
    rendered = render_inline(NetWorth::HoldingsSummaryComponent.new(top_holdings: []))

    assert_includes rendered.text, "No holdings available"
  end

  def test_renders_top_holdings_rows
    top = [
      { "ticker" => "AAPL", "name" => "Apple Inc", "value" => 123_000, "pct_portfolio" => 0.12 },
      { "ticker" => "MSFT", "name" => "Microsoft", "value" => 98_000, "pct_portfolio" => 0.09 }
    ]

    rendered = render_inline(NetWorth::HoldingsSummaryComponent.new(top_holdings: top, expanded: false))

    assert_includes rendered.text, "Holdings Summary"
    assert_includes rendered.text, "AAPL"
    assert_includes rendered.text, "Apple Inc"
    assert_includes rendered.text, "$123,000"
    assert_includes rendered.text, "Expand"
  end
end
