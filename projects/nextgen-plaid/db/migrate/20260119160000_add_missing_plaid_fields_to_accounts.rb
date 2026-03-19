class AddMissingPlaidFieldsToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :official_name, :string
    add_column :accounts, :credit_limit, :decimal, precision: 15, scale: 2
    add_column :accounts, :holder_category, :string
  end
end
