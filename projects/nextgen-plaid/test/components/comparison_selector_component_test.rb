# frozen_string_literal: true

require "test_helper"

class ComparisonSelectorComponentTest < ViewComponent::TestCase
  def test_disabled_when_in_live_mode
    user = users(:one)
    snap = user.holdings_snapshots.create!(snapshot_data: { "holdings" => [] }, created_at: 1.day.ago)

    rendered = render_inline(ComparisonSelectorComponent.new(
      user: user,
      selected_snapshot_id: "live",
      compare_to: nil,
      base_params: { snapshot_id: "live", sort: "market_value", dir: "desc" },
      turbo_frame_id: "portfolio_holdings_grid",
      holdings_path_helper: :portfolio_holdings_path
    ))

    assert_includes rendered.text, "Compare to"
    assert_includes rendered.to_html, "disabled=\"disabled\""
    assert_includes rendered.to_html, "Select a snapshot first"
    assert_includes rendered.to_html, "value=\"current\""
    assert_includes rendered.to_html, "value=\"#{snap.id}\""
  end

  def test_excludes_selected_snapshot_from_options
    user = users(:one)
    selected = user.holdings_snapshots.create!(snapshot_data: { "holdings" => [] }, created_at: 2.days.ago)
    other = user.holdings_snapshots.create!(snapshot_data: { "holdings" => [] }, created_at: 1.day.ago)

    rendered = render_inline(ComparisonSelectorComponent.new(
      user: user,
      selected_snapshot_id: selected.id,
      compare_to: other.id,
      base_params: { snapshot_id: selected.id, sort: "market_value", dir: "desc" },
      turbo_frame_id: "portfolio_holdings_grid",
      holdings_path_helper: :portfolio_holdings_path
    ))

    # The selected snapshot must not appear as a selectable comparison option.
    # (It will still appear as the hidden `snapshot_id` field.)
    refute_includes rendered.to_html, "option value=\"#{selected.id}\""
    assert_includes rendered.to_html, "value=\"#{other.id}\""
    assert_includes rendered.text, "Clear comparison"
  end
end
