require "test_helper"

class SecurityDetailDataProviderTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear

    @user = User.create!(email: "security-detail-provider@example.com", password: "password")
    @plaid_item = PlaidItem.create!(
      user: @user,
      access_token: "test-access-token",
      item_id: "item_1",
      institution_name: "Test Bank",
      institution_id: "ins_1",
      status: :good
    )

    @account = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_1",
      name: "Brokerage",
      mask: "1111",
      plaid_account_type: "investment"
    )

    @enrichment = SecurityEnrichment.create!(
      security_id: "sec_1",
      symbol: "AAPL",
      company_name: "Apple Inc.",
      source: "fmp",
      enriched_at: Time.current,
      status: "success",
      sector: "Technology",
      price: 123.45,
      data: {}
    )

    Holding.create!(
      account: @account,
      security_id: "sec_1",
      ticker_symbol: "AAPL",
      name: "Apple Inc.",
      asset_class: "equity",
      quantity: 2,
      market_value: 200,
      cost_basis: 150,
      unrealized_gl: 50
    )

    Transaction.create!(
      account: @account,
      source: :manual,
      date: Date.new(2026, 1, 1),
      name: "Buy AAPL",
      amount: -100,
      security_id: "sec_1",
      transaction_type: "buy",
      quantity: 1,
      price: 100
    )

    Transaction.create!(
      account: @account,
      source: :manual,
      date: Date.new(2026, 1, 2),
      name: "Sell AAPL",
      amount: 50,
      security_id: "sec_1",
      transaction_type: "sell",
      quantity: 0.5,
      price: 100
    )

    Transaction.create!(
      account: @account,
      source: :manual,
      date: Date.new(2026, 1, 3),
      name: "Dividend AAPL",
      amount: 5,
      security_id: "sec_1",
      transaction_type: "dividend"
    )
  end

  test "computes holdings summary and transaction totals" do
    result = SecurityDetailDataProvider.new(@user, "sec_1", per_page: "all").call
    assert result.present?

    assert_in_delta 2.0, result.holdings_summary[:total_quantity], 0.0001
    assert_in_delta 200.0, result.holdings_summary[:total_market_value], 0.0001
    assert_in_delta 150.0, result.holdings_summary[:total_cost_basis], 0.0001
    assert_in_delta 50.0, result.holdings_summary[:total_unrealized_gl], 0.0001

    assert_in_delta 100.0, result.transaction_totals[:invested], 0.0001
    assert_in_delta 50.0, result.transaction_totals[:proceeds], 0.0001
    assert_in_delta(-50.0, result.transaction_totals[:net_cash_flow], 0.0001)
    assert_in_delta 5.0, result.transaction_totals[:dividends], 0.0001
  end

  test "paginates transactions" do
    result = SecurityDetailDataProvider.new(@user, "sec_1", per_page: 2, page: 1).call
    assert_equal 3, result.transaction_total_count
    assert_equal 2, result.transactions.length
    assert_equal Date.new(2026, 1, 3), result.transactions.first.date
  end
end
