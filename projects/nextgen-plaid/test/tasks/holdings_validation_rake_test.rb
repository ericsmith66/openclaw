require "test_helper"
require "rake"
require "tempfile"

class HoldingsValidationRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["holdings:validate_positions_csv"].reenable
  end

  test "only prints tickers where cost difference exceeds $10 but still prints account totals" do
    user = User.create!(email: "holdings-validate@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_holdings_validate", institution_name: "Test Inst", access_token: "tok_1", status: "good")
    account = Account.create!(
      plaid_item: item,
      account_id: "acc_1",
      name: "Brokerage",
      mask: "5009",
      plaid_account_type: "investment",
      subtype: "brokerage"
    )

    Holding.create!(account: account, security_id: "sec_a", symbol: "AAPL", quantity: 1, market_value: 1, cost_basis: 100)
    Holding.create!(account: account, security_id: "sec_m", symbol: "MSFT", quantity: 1, market_value: 1, cost_basis: 100)

    csv = Tempfile.new(%w[positions .csv])
    csv.write("Account number,Ticker,Quantity,Value,Cost\n")
    csv.write("D...5009,AAPL,1,1,115\n")
    csv.write("D...5009,MSFT,1,1,105\n")
    csv.write("D...5009,0USD,1,1,9999\n")
    csv.close

    out, _err = capture_io do
      exit_err = assert_raises(SystemExit) do
        Rake::Task["holdings:validate_positions_csv"].invoke(csv.path, user.id)
      end
      assert_equal 2, exit_err.status
    end

    assert_includes out, "Mismatch for account id=#{account.id}", "expected account mismatch header"
    assert_includes out, "totals:", "expected per-account totals line"
    assert_includes out, "csv_cost=220.0", "expected totals to exclude ignored ticker 0USD"
    assert_includes out, "ticker=AAPL", "expected AAPL to be shown (diff > $10)"
    refute_includes out, "ticker=MSFT", "expected MSFT to be hidden (diff <= $10)"
    refute_includes out, "ticker=0USD", "expected 0USD to be ignored"
  ensure
    csv.unlink if csv
  end
end
