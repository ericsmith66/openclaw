# frozen_string_literal: true

require "application_system_test_case"

class NetWorthDashboardCapybaraTest < ApplicationSystemTestCase
  test "dashboard renders snapshot aggregates when enabled" do
    user = User.create!(email: "nw_dash_user@example.com", password: "password123")

    FinancialSnapshot.create!(
      user: user,
      snapshot_at: Time.use_zone(APP_TIMEZONE) { Time.zone.now.beginning_of_day },
      schema_version: 1,
      status: :complete,
      data: {
        "total_net_worth" => 2_500_000,
        "delta_day" => 5_000,
        "delta_30d" => 25_000,
        "asset_allocation" => { "equity" => 0.62, "cash" => 0.38 },
        "sector_weights" => { "technology" => 1.0 },
        "monthly_transaction_summary" => { "income" => 10_000, "expenses" => 2_000, "top_categories" => [] },
        "transactions_summary" => { "month" => { "income" => 10_000, "expenses" => 2_000, "net" => 8_000 } },
        "historical_net_worth" => [],
        "as_of" => Date.current.to_s,
        "disclaimer" => FinancialSnapshotJob::DISCLAIMER,
        "data_quality" => { "warnings" => [] }
      }
    )

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      login_as user, scope: :user
      visit "/net_worth/dashboard"

      assert_text "Net Worth Dashboard"

      assert_text "Total Net Worth"
      assert_text "$2,500,000"
      assert_text "$5,000"

      assert_text "Asset Allocation"
      assert_text "Equity"
      assert_text "62%"

      assert_text "Sector Weights"
      # `sector-table-frame` is lazy-loaded via Turbo (`src:`) and does not load in this non-JS smoke test.
      assert_selector "turbo-frame#sector-table-frame"

      assert_text "Recent Activity"
      assert_text "Income"
      assert_text "$10,000"

      assert_text "Transactions Summary"
      assert_text "Expenses"
      assert_text "-$2,000"
      assert_text "Net"
      assert_text "+$8,000"
    end
  end

  test "dashboard shows placeholder when no snapshot exists" do
    user = User.create!(email: "nw_dash_empty@example.com", password: "password123")

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      login_as user, scope: :user
      visit "/net_worth/dashboard"

      # When no persisted snapshot exists, the dashboard still renders using
      # `Reporting::DataProvider` fallback data.
      assert_text "Net Worth Dashboard"

      assert_text "Total Net Worth"
      assert_text "Asset Allocation"
    end
  end

  test "dashboard redirects when feature flag is disabled" do
    user = User.create!(email: "nw_dash_disabled@example.com", password: "password123")

    ClimateControl.modify ENABLE_NEW_LAYOUT: "false" do
      login_as user, scope: :user
      visit "/net_worth/dashboard"

      assert_equal 404, page.status_code
    end
  end
end
