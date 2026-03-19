class AddBalanceSyncFieldsToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :available_balance, :decimal

    add_column :accounts, :balances_last_synced_at, :datetime
    add_column :accounts, :balances_last_sync_status, :string
    add_column :accounts, :balances_last_sync_error, :text
  end
end
