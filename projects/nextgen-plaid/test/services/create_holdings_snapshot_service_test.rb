require "test_helper"

class CreateHoldingsSnapshotServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "snapper@example.com", password: "password")
    @plaid_item = PlaidItem.create!(
      user: @user,
      access_token: "test-access-token",
      item_id: "item_1",
      institution_name: "Test Bank",
      institution_id: "ins_1",
      status: :good
    )

    @investment = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_1",
      name: "Brokerage 1",
      mask: "1111",
      plaid_account_type: "investment"
    )

    Holding.create!(
      account: @investment,
      security_id: "sec_1",
      ticker_symbol: "AAPL",
      name: "Apple Inc.",
      asset_class: "equity",
      sector: "Technology",
      quantity: 2,
      market_value: 200,
      cost_basis: 150,
      unrealized_gl: 50
    )
  end

  test "creates a snapshot with expected JSON shape" do
    result = CreateHoldingsSnapshotService.new(user_id: @user.id, force: true).call

    assert result.success?
    assert result.snapshot.present?
    snap = result.snapshot

    assert_equal @user.id, snap.user_id
    assert_nil snap.account_id

    data = snap.snapshot_data
    assert data.key?("holdings")
    assert data.key?("totals")
    assert_kind_of Array, data["holdings"]

    first = data["holdings"].first
    assert_equal "sec_1", first["security_id"]
    assert_equal "AAPL", first["ticker_symbol"]
    assert_equal "Apple Inc.", first["name"]
    assert_equal @investment.id, first["account_id"]
    assert_equal "Brokerage 1", first["account_name"]
    assert_equal "1111", first["account_mask"]
    assert first.key?("unrealized_gain_loss")

    totals = data["totals"]
    assert_in_delta 200.0, totals["portfolio_value"].to_f, 0.0001
    assert_in_delta 50.0, totals["total_gl_dollars"].to_f, 0.0001
    assert totals.key?("total_gl_pct")
  end

  test "serializes unrealized_gain_loss using fallback when holding.unrealized_gl is nil" do
    Holding.create!(
      account: @investment,
      security_id: "sec_2",
      ticker_symbol: "MSFT",
      name: "Microsoft",
      asset_class: "equity",
      sector: "Technology",
      quantity: 1,
      market_value: 120,
      cost_basis: 100,
      unrealized_gl: nil
    )

    result = CreateHoldingsSnapshotService.new(user_id: @user.id, force: true).call
    assert result.success?

    holdings = result.snapshot.snapshot_data["holdings"]
    msft = holdings.find { |h| h["security_id"] == "sec_2" }
    assert msft.present?
    assert_in_delta 20.0, msft["unrealized_gain_loss"].to_f, 0.0001
  end

  test "idempotency skips when a recent snapshot exists" do
    HoldingsSnapshot.create!(
      user: @user,
      account_id: nil,
      name: "Daily #{Date.current}",
      snapshot_data: { holdings: [], totals: { portfolio_value: 0, total_gl_dollars: 0, total_gl_pct: 0 } },
      created_at: 1.hour.ago
    )

    assert_no_difference "HoldingsSnapshot.count" do
      result = CreateHoldingsSnapshotService.new(user_id: @user.id, force: false).call
      assert result.skipped?
    end
  end

  test "force bypasses idempotency and creates a new snapshot" do
    HoldingsSnapshot.create!(
      user: @user,
      account_id: nil,
      name: "Daily #{Date.current}",
      snapshot_data: { holdings: [], totals: { portfolio_value: 0, total_gl_dollars: 0, total_gl_pct: 0 } },
      created_at: 1.hour.ago
    )

    assert_difference "HoldingsSnapshot.count", 1 do
      result = CreateHoldingsSnapshotService.new(user_id: @user.id, force: true).call
      assert result.success?
    end
  end

  test "empty portfolio creates snapshot with empty holdings" do
    empty_user = User.create!(email: "empty@example.com", password: "password")
    empty_item = PlaidItem.create!(
      user: empty_user,
      access_token: "test-access-token-2",
      item_id: "item_2",
      institution_name: "Test Bank",
      institution_id: "ins_1",
      status: :good
    )
    Account.create!(
      plaid_item: empty_item,
      account_id: "acc_2",
      name: "Brokerage 2",
      mask: "2222",
      plaid_account_type: "investment"
    )

    result = CreateHoldingsSnapshotService.new(user_id: empty_user.id, force: true).call

    assert result.success?
    assert_equal [], result.snapshot.snapshot_data["holdings"]
    assert_equal 0.0, result.snapshot.snapshot_data.dig("totals", "portfolio_value").to_f
  end
end
