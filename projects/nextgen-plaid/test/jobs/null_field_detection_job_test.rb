require "test_helper"
require "fileutils"

class NullFieldDetectionJobTest < ActiveJob::TestCase
  test "generates report grouped by institution and flags persistent nulls" do
    output_path = nil
    user = User.create!(email: "null-fields@example.com", password: "Password!123")

    item_1 = PlaidItem.create!(
      user: user,
      item_id: "it_null_1",
      institution_name: "Inst 1",
      institution_id: "ins_1",
      access_token: "tok_1",
      status: "good"
    )
    item_2 = PlaidItem.create!(
      user: user,
      item_id: "it_null_2",
      institution_name: "Inst 2",
      institution_id: "ins_2",
      access_token: "tok_2",
      status: "good"
    )

    account_1 = item_1.accounts.create!(account_id: "acc_1", mask: "1111")
    account_2 = item_2.accounts.create!(account_id: "acc_2", mask: "2222")

    # Holdings: make cost_basis always null for ins_1
    Holding.create!(account: account_1, security_id: "sec_1", cost_basis: nil, market_value: 10, source: "plaid")
    Holding.create!(account: account_1, security_id: "sec_2", cost_basis: nil, market_value: 20, source: "plaid")
    Holding.create!(account: account_2, security_id: "sec_3", cost_basis: 5, market_value: 30, source: "plaid")

    # Transactions: include at least one row so the section is non-empty
    Transaction.create!(account: account_1, source: "manual", name: "Test", date: Date.current, amount: 1.23)

    # Balance snapshots: make available_balance always null for ins_1
    AccountBalanceSnapshot.create!(account: account_1, snapshot_date: Date.current, available_balance: nil, current_balance: 10, synced_at: Time.current)
    AccountBalanceSnapshot.create!(account: account_1, snapshot_date: Date.current - 1.day, available_balance: nil, current_balance: 10, synced_at: Time.current)

    # Liabilities: create a credit account to ensure the liabilities section includes rows
    item_1.accounts.create!(account_id: "acc_credit_1", mask: "9999", plaid_account_type: "credit")

    output_path = Rails.root.join("tmp", "null_fields_report_test.md")
    FileUtils.rm_f(output_path)

    NullFieldDetectionJob.perform_now(output_path.to_s)

    assert File.exist?(output_path)
    content = File.read(output_path)

    assert_includes content, "# Null Fields Report"
    assert_includes content, "Institution: ins_1"
    assert_includes content, "### Accounts"
    assert_includes content, "### Holdings"
    assert_includes content, "`cost_basis`"
    assert_includes content, "always null"

    assert_includes content, "### Balance Snapshots"
    assert_includes content, "`available_balance`"
  ensure
    FileUtils.rm_f(output_path) if output_path.present?
  end

  test "writes a report even when there is no data" do
    output_path = nil
    output_path = Rails.root.join("tmp", "null_fields_report_empty_test.md")
    FileUtils.rm_f(output_path)

    NullFieldDetectionJob.perform_now(output_path.to_s)

    assert File.exist?(output_path)
    content = File.read(output_path)
    assert_includes content, "No data found"
  ensure
    FileUtils.rm_f(output_path) if output_path.present?
  end
end
