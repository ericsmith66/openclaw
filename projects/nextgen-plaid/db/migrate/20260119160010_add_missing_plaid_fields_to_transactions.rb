class AddMissingPlaidFieldsToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :investment_type, :string
    add_column :transactions, :investment_transaction_id, :string
    add_column :transactions, :security_id, :string

    add_index :transactions, :investment_type
    add_index :transactions, :investment_transaction_id
    add_index :transactions, :security_id
  end
end
