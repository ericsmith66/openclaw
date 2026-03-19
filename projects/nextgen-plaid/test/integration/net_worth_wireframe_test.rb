# frozen_string_literal: true

require "test_helper"

class NetWorthWireframeTest < ActionDispatch::IntegrationTest
  def test_dashboard_serves_net_worth_dashboard
    sign_in users(:one)
    get "/dashboard"
    assert_response :success
  end

  def test_net_worth_dashboard_uses_authenticated_layout_when_enabled
    user = users(:one)

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      sign_in user
      get "/net_worth/dashboard"
      assert_response :success

      assert_includes @response.body, "authenticated-drawer"
      assert_includes @response.body, "Net Worth Dashboard"

      assert_includes @response.body, "net-worth-summary-frame"
      assert_includes @response.body, "allocation-pie-frame"
      assert_includes @response.body, "sector-table-frame"
      assert_includes @response.body, "holdings-summary-frame"
      assert_includes @response.body, "transactions-summary-frame"
    end
  end

  def test_sector_weights_frame_renders
    user = users(:one)

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      sign_in user
      get "/net_worth/sectors"
      assert_response :success

      assert_includes @response.body, "sector-table-frame"
      assert_includes @response.body, "Sector Weights"
    end
  end
end
