# frozen_string_literal: true

require "test_helper"

class NetWorthPerformancePageTest < ActionDispatch::IntegrationTest
  test "performance page renders component" do
    user = users(:one)

    FinancialSnapshot.create!(
      user: user,
      snapshot_at: Time.use_zone(APP_TIMEZONE) { Time.zone.now.beginning_of_day },
      schema_version: 1,
      status: :complete,
      data: {
        "historical_totals" => [
          { "date" => "2026-01-20", "total" => 1_000, "delta" => nil },
          { "date" => "2026-01-21", "total" => 1_100, "delta" => 100 }
        ]
      }
    )

    sign_in user

    get "/net_worth/performance"
    assert_response :success
    assert_includes response.body, "performance-chart-frame"
    assert_includes response.body, "net-worth-performance-chart"
  end
end
