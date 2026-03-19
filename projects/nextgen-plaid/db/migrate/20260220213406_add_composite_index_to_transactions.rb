class AddCompositeIndexToTransactions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :transactions, [ :type, :account_id, :date ],
              name: 'idx_transactions_type_account_date',
              algorithm: :concurrently
  end

  def down
    remove_index :transactions, name: 'idx_transactions_type_account_date'
  end
end
