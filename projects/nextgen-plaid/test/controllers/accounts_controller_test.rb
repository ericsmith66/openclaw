require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  test "destroy deletes account even when it has soft-deleted transactions" do
    user = users(:one)
    sign_in user

    item = PlaidItem.create!(
      user: user,
      item_id: "it_accounts_destroy",
      institution_name: "Bank",
      access_token: "tok",
      status: "good"
    )
    account = item.accounts.create!(
      account_id: "acc_accounts_destroy",
      name: "Checking",
      plaid_account_type: "depository",
      subtype: "checking",
      mask: "0000"
    )

    tx = account.transactions.create!(
      source: "manual",
      date: Date.current,
      amount: 12.34,
      name: "Coffee"
    )
    tx.update_column(:deleted_at, Time.current)

    assert_difference [ "Account.count", "Transaction.unscoped.count" ], -1 do
      delete account_path(account)
      assert_redirected_to accounts_url
    end
  end
end
