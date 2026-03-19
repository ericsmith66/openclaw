# frozen_string_literal: true

require "test_helper"

class Portfolio::HoldingsGridComponentTest < ViewComponent::TestCase
  def test_enrichment_renders_as_dot_with_tooltip
    user = users(:one)
    enriched_at = Time.zone.parse("2026-02-09 19:52")
    enrichment = Struct.new(:enriched_at).new(enriched_at)

    rendered = render_inline(Portfolio::HoldingsGridComponent.new(
      user: user,
      holdings_groups: [
        {
          parent: {
            security_id: "sec_1",
            ticker_symbol: "AAPL",
            name: "Apple",
            asset_class: "equity",
            quantity: 1,
            market_value: 100,
            cost_basis: 80,
            unrealized_gl: 20,
            security_enrichment: enrichment
          },
          children: []
        }
      ],
      summary: { portfolio_value: 100 },
      total_count: 1,
      page: 1,
      per_page: 25,
      sort: "ticker_symbol",
      dir: "asc",
      snapshot_id: "live",
      compare_to: nil,
      comparison: nil
    ))

    assert_includes rendered.to_html, "inline-block w-3 h-3 rounded-full"
    assert_includes rendered.to_html, "data-tip=\"Enriched:"
  end

  def test_enrichment_nil_renders_gray_dot_with_not_enriched_tooltip
    user = users(:one)

    rendered = render_inline(Portfolio::HoldingsGridComponent.new(
      user: user,
      holdings_groups: [
        {
          parent: {
            security_id: "sec_1",
            ticker_symbol: "AAPL",
            name: "Apple",
            asset_class: "equity",
            quantity: 1,
            market_value: 100,
            cost_basis: 80,
            unrealized_gl: 20
          },
          children: []
        }
      ],
      summary: { portfolio_value: 100 },
      total_count: 1,
      page: 1,
      per_page: 25,
      sort: "ticker_symbol",
      dir: "asc",
      snapshot_id: "live",
      compare_to: nil,
      comparison: nil
    ))

    assert_includes rendered.to_html, "bg-gray-300"
    assert_includes rendered.to_html, "data-tip=\"Not enriched\""
  end

  def test_unrealized_gl_and_pct_render_from_fallback_when_unrealized_gl_is_nil
    user = users(:one)

    rendered = render_inline(Portfolio::HoldingsGridComponent.new(
      user: user,
      holdings_groups: [
        {
          parent: {
            security_id: "sec_1",
            ticker_symbol: "AAPL",
            name: "Apple",
            asset_class: "equity",
            quantity: 1,
            market_value: 120,
            cost_basis: 100,
            unrealized_gl: nil
          },
          children: []
        }
      ],
      summary: { portfolio_value: 120 },
      total_count: 1,
      page: 1,
      per_page: 25,
      sort: "ticker_symbol",
      dir: "asc",
      snapshot_id: "live",
      compare_to: nil,
      comparison: nil
    ))

    assert_includes rendered.text, "$20"
    assert_includes rendered.text, "20.0%"
  end

  def test_symbol_link_targets_top_frame_for_non_expandable_rows
    user = users(:one)

    rendered = render_inline(Portfolio::HoldingsGridComponent.new(
      user: user,
      holdings_groups: [
        {
          parent: {
            security_id: "sec_1",
            ticker_symbol: "AAPL",
            name: "Apple",
            asset_class: "equity",
            quantity: 1,
            market_value: 100,
            cost_basis: 80,
            unrealized_gl: 20
          },
          children: []
        }
      ],
      summary: { portfolio_value: 100 },
      total_count: 1,
      page: 1,
      per_page: 25,
      sort: "ticker_symbol",
      dir: "asc",
      snapshot_id: "live",
      compare_to: nil,
      comparison: nil
    ))

    assert_includes rendered.to_html, "href=\"/portfolio/securities/sec_1"
    assert_includes rendered.to_html, "data-turbo-frame=\"_top\""
  end

  def test_symbol_link_targets_top_frame_for_expandable_rows
    user = users(:one)

    rendered = render_inline(Portfolio::HoldingsGridComponent.new(
      user: user,
      holdings_groups: [
        {
          parent: {
            security_id: "sec_1",
            ticker_symbol: "AAPL",
            name: "Apple",
            asset_class: "equity",
            quantity: 3,
            market_value: 300,
            cost_basis: 230,
            unrealized_gl: 70
          },
          children: [
            {
              account_name: "Brokerage",
              account_mask: "1111",
              quantity: 1,
              market_value: 100,
              cost_basis: 80,
              unrealized_gl: 20
            }
          ]
        }
      ],
      summary: { portfolio_value: 300 },
      total_count: 1,
      page: 1,
      per_page: 25,
      sort: "ticker_symbol",
      dir: "asc",
      snapshot_id: "live",
      compare_to: nil,
      comparison: nil
    ))

    assert_includes rendered.to_html, "href=\"/portfolio/securities/sec_1"
    assert_includes rendered.to_html, "data-turbo-frame=\"_top\""
  end

  def test_column_count_matches_widths_without_comparison
    user = users(:one)

    component = Portfolio::HoldingsGridComponent.new(
      user: user,
      holdings_groups: [ { parent: { ticker_symbol: "AAPL", name: "Apple", asset_class: "stock" }, children: [] } ],
      summary: {},
      total_count: 1,
      page: 1,
      per_page: 25,
      sort: "ticker_symbol",
      dir: "asc",
      snapshot_id: "live",
      compare_to: nil,
      comparison: nil
    )

    widths = component.send(:holdings_grid_column_widths)
    assert_equal widths.length, component.send(:comparison_column_count)
    assert_equal "grid-template-columns: #{widths.join(' ')};", component.send(:expandable_parent_grid_style)
  end

  def test_column_count_matches_widths_with_comparison
    user = users(:one)

    component = Portfolio::HoldingsGridComponent.new(
      user: user,
      holdings_groups: [ { parent: { ticker_symbol: "AAPL", name: "Apple", asset_class: "stock" }, children: [] } ],
      summary: {},
      total_count: 1,
      page: 1,
      per_page: 25,
      sort: "ticker_symbol",
      dir: "asc",
      snapshot_id: "123",
      compare_to: "current",
      comparison: { overall: {} }
    )

    widths = component.send(:holdings_grid_column_widths)
    assert_equal 13, widths.length
    assert_equal widths.length, component.send(:comparison_column_count)
    assert_equal "grid-template-columns: #{widths.join(' ')};", component.send(:expandable_parent_grid_style)
  end
end
