class ClearAccountsTypeForSti < ActiveRecord::Migration[8.1]
  class AccountRow < ApplicationRecord
    self.table_name = "accounts"
    self.inheritance_column = :_type_disabled
  end

  def up
    AccountRow.unscoped.in_batches(of: 1000) do |batch|
      batch.update_all(type: nil)
    end
  end

  def down
    AccountRow.unscoped.in_batches(of: 1000) do |batch|
      batch.update_all("type = plaid_account_type")
    end
  end
end
