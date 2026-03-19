class AddPersonalFinanceCategoryToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :personal_finance_category, :string
    add_index :transactions, :personal_finance_category
  end
end
