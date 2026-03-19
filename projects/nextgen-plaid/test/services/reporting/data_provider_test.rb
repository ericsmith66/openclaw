require "test_helper"

class ReportingDataProviderTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "dp_user@example.com", password: "password")
    @other_user = User.create!(email: "dp_other@example.com", password: "password")

    @plaid_item = PlaidItem.create!(
      user: @user,
      item_id: "item_1",
      institution_name: "Test Bank",
      status: PlaidItem.statuses[:good]
    )

    @other_plaid_item = PlaidItem.create!(
      user: @other_user,
      item_id: "item_2",
      institution_name: "Other Bank",
      status: PlaidItem.statuses[:good]
    )

    @depository = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_1",
      mask: "0000",
      plaid_account_type: "depository",
      current_balance: 25_000
    )

    @credit = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_2",
      mask: "1111",
      plaid_account_type: "credit",
      current_balance: 75_000
    )

    @other_account = Account.create!(
      plaid_item: @other_plaid_item,
      account_id: "acc_3",
      mask: "2222",
      plaid_account_type: "depository",
      current_balance: 999_999
    )

    Holding.create!(
      account: @depository,
      security_id: "sec_1",
      market_value: 100_000,
      asset_class: "equity",
      sector: "Technology",
      symbol: "AAA",
      name: "AAA Corp"
    )

    Holding.create!(
      account: @depository,
      security_id: "sec_2",
      market_value: 50_000,
      asset_class: "cash",
      sector: nil,
      symbol: "CASH",
      name: "Cash"
    )

    Holding.create!(
      account: @other_account,
      security_id: "sec_3",
      market_value: 999_999,
      asset_class: "equity",
      sector: "Energy",
      symbol: "ZZZ",
      name: "ZZZ Corp"
    )

    Transaction.create!(
      account: @depository,
      source: "manual",
      date: Date.current,
      amount: 100,
      name: "Groceries",
      personal_finance_category_label: "Food"
    )

    Transaction.create!(
      account: @depository,
      source: "manual",
      date: Date.current,
      amount: -500,
      name: "Paycheck",
      personal_finance_category_label: "Income"
    )

    SyncLog.create!(plaid_item: @plaid_item, job_type: "holdings", status: "success")
  end

  test "core_aggregates computes total_net_worth using user-scoped sums" do
    provider = Reporting::DataProvider.new(@user)
    result = provider.core_aggregates

    # holdings: 100k + 50k = 150k
    # cash accounts: 25k
    # credit accounts: 75k
    # net worth = 150k + 25k - 75k = 100k
    assert_in_delta 100_000, result[:total_net_worth], 0.0001
  end

  test "asset_allocation_breakdown returns percentages that sum to 1" do
    provider = Reporting::DataProvider.new(@user)
    result = provider.asset_allocation_breakdown
    assert result.key?("equity")
    assert result.key?("cash")
    assert_in_delta 1.0, result.values.sum, 0.0001
  end

  test "asset_allocation_breakdown buckets nil/unknown asset_class into other" do
    Holding.create!(
      account: @depository,
      security_id: "sec_other",
      market_value: 25_000,
      asset_class: nil,
      sector: nil,
      symbol: "OTH",
      name: "Other"
    )

    provider = Reporting::DataProvider.new(@user)
    result = provider.asset_allocation_breakdown
    assert result.key?("other")
    assert_in_delta 1.0, result.values.sum, 0.0001
  end

  test "sector_weights only considers equity holdings and returns percentages" do
    provider = Reporting::DataProvider.new(@user)
    result = provider.sector_weights
    assert_equal [ "technology" ], result.keys
    assert_in_delta 1.0, result.values.sum, 0.0001
  end

  test "sector_weights buckets nil/blank sectors into unknown" do
    Holding.create!(
      account: @depository,
      security_id: "sec_unknown",
      market_value: 25_000,
      asset_class: "equity",
      sector: nil,
      symbol: "UNK",
      name: "Unknown Equity"
    )

    provider = Reporting::DataProvider.new(@user)
    result = provider.sector_weights
    assert result.key?("technology")
    assert result.key?("unknown")
    assert_in_delta 1.0, result.values.sum, 0.0001
  end

  test "sector_weights returns nil when user has no equities" do
    user = User.create!(email: "dp_no_equity@example.com", password: "password")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "item_no_equity",
      institution_name: "No Equity Bank",
      status: PlaidItem.statuses[:good]
    )

    depository = Account.create!(
      plaid_item: plaid_item,
      account_id: "acc_no_equity",
      mask: "3333",
      plaid_account_type: "depository",
      current_balance: 0
    )

    Holding.create!(
      account: depository,
      security_id: "sec_cash_only",
      market_value: 10_000,
      asset_class: "cash",
      sector: nil,
      symbol: "CASH",
      name: "Cash"
    )

    provider = Reporting::DataProvider.new(user)
    assert_nil provider.sector_weights
  end

  test "top_holdings returns top holdings with pct_portfolio" do
    user = User.create!(email: "dp_holdings@example.com", password: "password")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "item_holdings",
      institution_name: "Holdings Bank",
      status: PlaidItem.statuses[:good]
    )

    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "acc_holdings",
      mask: "4444",
      plaid_account_type: "investment",
      current_balance: 0
    )

    total = 0.0
    10.times do |i|
      value = (10 - i) * 10_000
      total += value
      Holding.create!(
        account: account,
        security_id: "sec_#{i}",
        market_value: value,
        asset_class: "equity",
        sector: "Technology",
        symbol: "TICK#{i}",
        name: "Company #{i}"
      )
    end

    provider = Reporting::DataProvider.new(user)
    holdings = provider.top_holdings
    assert_equal 10, holdings.size
    assert_equal 100_000, holdings.first["value"]
    assert_in_delta 100_000.0 / total, holdings.first["pct_portfolio"], 0.0001
  end

  test "monthly_transaction_summary computes income, expenses, and top_categories for last 30 days" do
    user = User.create!(email: "dp_txn_summary@example.com", password: "password")
    plaid_item = PlaidItem.create!(
      user: user,
      item_id: "item_txn_summary",
      institution_name: "Txn Bank",
      status: PlaidItem.statuses[:good]
    )

    account = Account.create!(
      plaid_item: plaid_item,
      account_id: "acc_txn_summary",
      mask: "5555",
      plaid_account_type: "depository",
      current_balance: 0
    )

    Transaction.create!(
      account: account,
      source: "manual",
      date: 15.days.ago.to_date,
      amount: 5_000,
      name: "Salary",
      personal_finance_category_label: "Salary"
    )

    Transaction.create!(
      account: account,
      source: "manual",
      date: 10.days.ago.to_date,
      amount: -2_000,
      name: "Rent",
      personal_finance_category_label: "Housing"
    )

    Transaction.create!(
      account: account,
      source: "manual",
      date: 60.days.ago.to_date,
      amount: 1_000,
      name: "Old",
      personal_finance_category_label: "Old"
    )

    provider = Reporting::DataProvider.new(user)
    summary = provider.monthly_transaction_summary
    assert_in_delta 5_000, summary["income"], 0.0001
    assert_in_delta 2_000, summary["expenses"], 0.0001
    assert summary["top_categories"].size <= 5
  end

  test "historical_trends returns net worth history sorted ascending by date" do
    5.times do |i|
      FinancialSnapshot.create!(
        user: @user,
        snapshot_at: (i + 1).days.ago,
        schema_version: 1,
        status: :complete,
        data: { "total_net_worth" => 500_000 + ((4 - i) * 10_000) }
      )
    end

    provider = Reporting::DataProvider.new(@user)
    history = provider.historical_trends(30)

    assert_equal 5, history.size
    assert_operator history.first["date"], :<, history.last["date"]
    assert_equal 540_000, history.last["value"]
  end

  test "historical_trends returns empty array when there are no prior complete snapshots" do
    provider = Reporting::DataProvider.new(@other_user)
    assert_equal [], provider.historical_trends(30)
  end

  test "with_date_range is chainable" do
    provider = Reporting::DataProvider.new(@user)
    assert_same provider, provider.with_date_range(30.days.ago.to_date, Date.current)
    assert provider.core_aggregates.key?(:total_net_worth)
  end

  test "sync_freshness uses latest successful sync_log and is not stale when recent" do
    provider = Reporting::DataProvider.new(@user)
    result = provider.sync_freshness

    assert_equal false, result[:stale]
    assert result[:last_sync_at].present?
  end

  test "memoization returns stable results across calls" do
    provider = Reporting::DataProvider.new(@user)
    first = provider.core_aggregates
    second = provider.core_aggregates

    assert_equal first, second
    assert_same first, second
  end

  test "to_tableau_json returns flattened hash" do
    provider = Reporting::DataProvider.new(@user)
    tableau = provider.to_tableau_json

    assert tableau.is_a?(Hash)
    assert tableau.key?("total_net_worth")
    assert tableau.key?("allocation_equity")

    tableau.each do |_k, v|
      refute v.is_a?(Hash) unless v.is_a?(Hash) && v.empty?
    end
  end
end
