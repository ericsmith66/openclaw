# frozen_string_literal: true

require "test_helper"

class SnapshotSelectorComponentTest < ViewComponent::TestCase
  def test_renders_live_option_and_recent_snapshots
    user = users(:one)

    s1 = user.holdings_snapshots.create!(snapshot_data: { "hello" => "world" }, created_at: 2.days.ago)
    s2 = user.holdings_snapshots.create!(snapshot_data: { "foo" => "bar" }, created_at: 1.day.ago)

    rendered = render_inline(SnapshotSelectorComponent.new(
      user: user,
      selected_snapshot_id: "live",
      base_params: { sort: "market_value", dir: "desc" },
      turbo_frame_id: "portfolio_holdings_grid",
      holdings_path_helper: :portfolio_holdings_path
    ))

    assert_includes rendered.text, "Latest (live)"
    assert_includes rendered.text, "View all snapshots"
    assert_includes rendered.to_html, "value=\"#{s1.id}\""
    assert_includes rendered.to_html, "value=\"#{s2.id}\""

    # Live mode should not show historical indicator.
    refute_includes rendered.text, "Historical view"
    refute_includes rendered.text, "Switch to live"
  end

  def test_shows_historical_indicator_when_snapshot_selected
    user = users(:one)
    snap = user.holdings_snapshots.create!(snapshot_data: { "a" => 1 }, created_at: 3.hours.ago)

    rendered = render_inline(SnapshotSelectorComponent.new(
      user: user,
      selected_snapshot_id: snap.id,
      base_params: { sort: "market_value", dir: "desc" },
      turbo_frame_id: "portfolio_holdings_grid",
      holdings_path_helper: :portfolio_holdings_path
    ))

    assert_includes rendered.text, "Viewing snapshot from"
    assert_includes rendered.text, "Switch to live"
  end
end
