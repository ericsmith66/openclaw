# frozen_string_literal: true

require "test_helper"

class NetWorthHoldingsFrameTest < ActionDispatch::IntegrationTest
  def test_holdings_frame_defaults_expanded
    user = users(:one)

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      sign_in user
      get "/net_worth/holdings"
      assert_response :success

      assert_includes @response.body, "holdings-summary-frame"
      assert_includes @response.body, "Holdings Summary"
      assert_includes @response.body, "Collapse"
    end
  end

  def test_holdings_frame_collapsed_renders
    user = users(:one)

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      sign_in user
      get "/net_worth/holdings", params: { expanded: false }
      assert_response :success

      assert_includes @response.body, "holdings-summary-frame"
      assert_includes @response.body, "Holdings Summary"
      assert_includes @response.body, "Expand"
    end
  end

  def test_holdings_frame_collapsed_does_not_show_empty_state_when_holdings_exist
    user = users(:one)

    fake_provider = Struct.new(:top_holdings).new(
      [ { "ticker" => "AAPL", "name" => "Apple Inc", "value" => 123_000, "pct_portfolio" => 0.12 } ]
    )

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      FinancialSnapshot.stub(:latest_for_user, nil) do
        Reporting::DataProvider.stub(:new, fake_provider) do
          sign_in user
          get "/net_worth/holdings", params: { expanded: false }
          assert_response :success

          assert_includes @response.body, "AAPL"
          refute_includes @response.body, "No holdings available"
        end
      end
    end
  end

  def test_holdings_frame_expanded_renders
    user = users(:one)

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      sign_in user
      get "/net_worth/holdings", params: { expanded: true }
      assert_response :success

      assert_includes @response.body, "holdings-summary-frame"
      assert_includes @response.body, "Holdings Summary"
      assert_includes @response.body, "Collapse"
    end
  end
end
