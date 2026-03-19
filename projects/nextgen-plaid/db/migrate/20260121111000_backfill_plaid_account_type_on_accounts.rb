class BackfillPlaidAccountTypeOnAccounts < ActiveRecord::Migration[8.1]
  class AccountRow < ApplicationRecord
    self.table_name = "accounts"
    self.inheritance_column = :_type_disabled
  end

  def up
    AccountRow.unscoped.in_batches(of: 1000) do |batch|
      batch.update_all("plaid_account_type = type")
    end

    null_count = AccountRow.where(plaid_account_type: nil).count
    raise "Found #{null_count} accounts with NULL plaid_account_type" if null_count.positive?
  end

  def down
    # Intentionally no-op: do not clear backfilled data.
  end
end
