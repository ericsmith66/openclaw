class AddPlaidAccountTypeToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :plaid_account_type, :string
    add_index :accounts, :plaid_account_type
  end
end
