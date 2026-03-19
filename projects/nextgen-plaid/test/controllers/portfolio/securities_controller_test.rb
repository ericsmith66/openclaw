require "test_helper"

class Portfolio::SecuritiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "portfolio-securities@example.com", password: "password")
    sign_in @user, scope: :user
  end

  test "show renders successfully when security is accessible" do
    fake_result = SecurityDetailDataProvider::Result.new(
      security_id: "sec_123",
      enrichment: nil,
      holdings: [],
      holdings_summary: { total_quantity: 0, total_market_value: 0, total_cost_basis: 0, total_unrealized_gl: 0, total_unrealized_gl_pct: 0 },
      holdings_by_account: [],
      transactions: [],
      transaction_totals: { invested: 0, proceeds: 0, net_cash_flow: 0, dividends: 0 },
      transaction_total_count: 0,
      page: 1,
      per_page: 25,
      return_to: nil
    )

    provider = Struct.new(:call).new(fake_result)

    SecurityDetailDataProvider.stub(:new, ->(*_args) { provider }) do
      get portfolio_security_path("sec_123")
    end

    assert_response :success
    assert_includes response.body, "Transactions"
    assert_includes response.body, "Per-Account Breakdown"
  end

  test "show returns 404 when security is not accessible" do
    provider = Struct.new(:call).new(nil)

    SecurityDetailDataProvider.stub(:new, ->(*_args) { provider }) do
      get portfolio_security_path("missing")
    end

    assert_response :not_found
    assert_includes response.body, "Security not found or no longer accessible"
  end
end
