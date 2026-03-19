class AddTypeToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :type, :string
    add_index :transactions, :type
  end
end
