class RenameTransactionsPersonalFinanceCategoryToLabel < ActiveRecord::Migration[8.1]
  def change
    # `transactions.personal_finance_category` conflicts with the existing
    # `belongs_to :personal_finance_category` association on Transaction.
    rename_column :transactions, :personal_finance_category, :personal_finance_category_label

    remove_index :transactions, :personal_finance_category_label, if_exists: true
    remove_index :transactions, :personal_finance_category, if_exists: true
    add_index :transactions, :personal_finance_category_label
  end
end
