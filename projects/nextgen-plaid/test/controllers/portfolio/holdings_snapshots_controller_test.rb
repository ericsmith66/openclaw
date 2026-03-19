# frozen_string_literal: true

require "test_helper"

class Portfolio::HoldingsSnapshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "portfolio-holdings-snapshots@example.com", password: "password")
    sign_in @user, scope: :user
  end

  test "index renders successfully" do
    @user.holdings_snapshots.create!(snapshot_data: { "x" => 1 })

    get portfolio_holdings_snapshots_path
    assert_response :success
    assert_includes response.body, "Holdings Snapshots"
  end
end
