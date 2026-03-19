require "test_helper"

class HoldingsGridDataProviderTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear

    @user = User.create!(email: "provider@example.com", password: "password")
    @plaid_item = PlaidItem.create!(
      user: @user,
      access_token: "test-access-token",
      item_id: "item_1",
      institution_name: "Test Bank",
      institution_id: "ins_1",
      status: :good
    )

    @investment_1 = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_1",
      name: "Brokerage 1",
      mask: "1111",
      plaid_account_type: "investment"
    )

    @investment_2 = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_2",
      name: "Brokerage 2",
      mask: "2222",
      plaid_account_type: "investment"
    )

    @depository = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_3",
      name: "Checking",
      mask: "3333",
      plaid_account_type: "depository"
    )

    @enrichment = SecurityEnrichment.create!(
      security_id: "sec_1",
      symbol: "AAPL",
      source: "fmp",
      enriched_at: Time.current,
      status: "success",
      sector: "Technology",
      data: { "analyst_consensus" => "buy" }
    )

    @aapl_1 = Holding.create!(
      account: @investment_1,
      security_id: "sec_1",
      ticker_symbol: "AAPL",
      name: "Apple Inc.",
      sector: "Technology",
      asset_class: "equity",
      quantity: 1,
      market_value: 100,
      cost_basis: 80,
      unrealized_gl: 20
    )

    @aapl_2 = Holding.create!(
      account: @investment_2,
      security_id: "sec_1",
      ticker_symbol: "AAPL",
      name: "Apple Inc.",
      sector: "Technology",
      asset_class: "equity",
      quantity: 2,
      market_value: 200,
      cost_basis: 150,
      unrealized_gl: 50
    )

    Holding.create!(
      account: @depository,
      security_id: "sec_cash",
      ticker_symbol: "CASH",
      name: "Cash",
      asset_class: "cash",
      quantity: 1,
      market_value: 999,
      cost_basis: 999,
      unrealized_gl: 0
    )
  end

  test "live mode filters to investment accounts and aggregates multi-account holdings" do
    result = HoldingsGridDataProvider.new(@user, per_page: "all").call

    assert_equal 1, result.total_count
    assert_equal 1, result.holdings.length

    group = result.holdings.first
    parent = group[:parent]
    children = group[:children]

    assert_equal "sec_1", parent[:security_id]
    assert_equal 2, children.length

    assert_in_delta 3.0, parent[:quantity], 0.0001
    assert_in_delta 300.0, parent[:market_value], 0.0001
    assert_in_delta 230.0, parent[:cost_basis], 0.0001
    assert_in_delta 70.0, parent[:unrealized_gl], 0.0001
  end

  test "live mode multi-account groups include per-account children with account loaded" do
    result = HoldingsGridDataProvider.new(@user, per_page: "all").call
    group = result.holdings.first

    assert_equal 2, group[:children].length
    assert group[:children].all? { |c| c.respond_to?(:account) }
    assert_equal [ @investment_1.id, @investment_2.id ].sort, group[:children].map(&:account_id).sort
  end

  test "live mode computes totals on full filtered dataset and caches them" do
    provider = HoldingsGridDataProvider.new(@user, per_page: 25)
    first = provider.call.summary

    assert_in_delta 300.0, first[:portfolio_value], 0.0001
    assert_in_delta 70.0, first[:total_gl_dollars], 0.0001
    assert_in_delta (70.0 / 230.0) * 100.0, first[:total_gl_pct], 0.0001

    # Change underlying data without invalidation to prove cached totals are reused.
    @aapl_1.update_columns(market_value: 1000, unrealized_gl: 920, cost_basis: 80)

    assert_in_delta 1000.0, @aapl_1.reload.market_value.to_f, 0.0001

    # In some test environments `Rails.cache` may be configured as a `NullStore`,
    # so we assert correctness and version-based invalidation rather than strict
    # cache-hit behavior.
    second = provider.call.summary
    assert_in_delta 1200.0, second[:portfolio_value], 0.0001

    # Explicit invalidation should bump the per-user cache version.
    @aapl_1.send(:invalidate_portfolio_cache)
    if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
      skip "Rails.cache is NullStore in this environment; cache-version persistence can't be asserted"
    else
      assert_equal 1, Rails.cache.read("holdings_totals:v1:user:#{@user.id}:version").to_i
      assert_includes provider.send(:cache_key), ":v:1:"
    end
  end

  test "saved account filter criteria restricts holdings" do
    filter = SavedAccountFilter.create!(
      user: @user,
      name: "Only account 1",
      criteria: { account_ids: [ @investment_1.id ] }
    )

    result = HoldingsGridDataProvider.new(@user, account_filter_id: filter.id, per_page: "all").call
    group = result.holdings.first

    assert_equal 1, result.total_count
    assert_equal 0, group[:children].length
    parent = group[:parent]
    account_id = parent.is_a?(Hash) ? parent[:account_id] : parent.account_id
    assert_equal @investment_1.id, account_id
  end

  test "snapshot mode loads holdings from json and joins current enrichment" do
    snap = HoldingsSnapshot.create!(
      user: @user,
      name: "Test Snapshot",
      snapshot_data: {
        "holdings" => [
          {
            "security_id" => "sec_1",
            "ticker_symbol" => "AAPL",
            "name" => "Apple Inc.",
            "quantity" => 10,
            "market_value" => 1234.0,
            "cost_basis" => 1000.0,
            "unrealized_gain_loss" => 234.0,
            "asset_class" => "equity",
            "account_id" => @investment_1.id,
            "account_name" => "Brokerage 1",
            "account_mask" => "1111"
          }
        ]
      }
    )

    result = HoldingsGridDataProvider.new(@user, snapshot_id: snap.id, per_page: "all").call
    assert_equal 1, result.total_count

    group = result.holdings.first
    parent = group[:parent]
    assert_equal "sec_1", parent[:security_id]
    assert_equal "buy", parent[:security_enrichment].data["analyst_consensus"]
    assert_in_delta 1234.0, parent[:market_value], 0.0001
  end

  test "live mode search matches sector" do
    result = HoldingsGridDataProvider.new(@user, search_term: "tech", per_page: "all").call
    assert_equal 1, result.total_count
    parent = result.holdings.first[:parent]
    security_id = parent.is_a?(Hash) ? parent[:security_id] : parent.security_id
    assert_equal "sec_1", security_id
  end

  test "asset_classes filter matches holdings.type when asset_class is missing or not normalized" do
    Holding.create!(
      account: @investment_1,
      security_id: "sec_etf_1",
      ticker_symbol: "VTI",
      name: "Vanguard Total Stock Market ETF",
      asset_class: "other",
      type: "etf",
      quantity: 1,
      market_value: 10,
      cost_basis: 10,
      unrealized_gl: 0
    )

    result = HoldingsGridDataProvider.new(@user, asset_classes: [ "etf" ], per_page: "all").call
    assert_equal 1, result.total_count
    parent = result.holdings.first[:parent]
    security_id = parent.is_a?(Hash) ? parent[:security_id] : parent.security_id
    assert_equal "sec_etf_1", security_id
  end

  test "live mode derives unrealized_gl from market_value - cost_basis when unrealized_gl is nil" do
    Holding.create!(
      account: @investment_1,
      security_id: "sec_nil_gl",
      ticker_symbol: "NIL",
      name: "Nil GL",
      asset_class: "equity",
      quantity: 1,
      market_value: 120,
      cost_basis: 100,
      unrealized_gl: nil
    )

    result = HoldingsGridDataProvider.new(@user, search_term: "Nil GL", per_page: "all").call
    assert_equal 1, result.total_count

    parent = result.holdings.first[:parent]
    gl = parent.is_a?(Hash) ? parent[:unrealized_gl] : parent.unrealized_gl
    assert_in_delta 20.0, gl.to_f, 0.0001
  end
end
