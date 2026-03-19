class UpdateOtherIncomesForPrd110 < ActiveRecord::Migration[8.1]
  def change
    rename_column :other_incomes, :projected_amount, :amount
    rename_column :other_incomes, :date, :start_date

    change_column :other_incomes, :amount, :decimal, precision: 12, scale: 2, null: false

    add_column :other_incomes, :frequency, :string, null: false, default: "annual"
    add_column :other_incomes, :end_date, :date
    add_column :other_incomes, :category, :string
    add_column :other_incomes, :taxable, :boolean, null: false, default: true
    add_column :other_incomes, :notes, :text

    change_column_null :other_incomes, :suggested_tax_rate, true

    if index_exists?(:other_incomes, [ :user_id, :start_date ])
      # no-op
    elsif index_exists?(:other_incomes, [ :user_id, :date ])
      remove_index :other_incomes, column: [ :user_id, :date ]
      add_index :other_incomes, [ :user_id, :start_date ]
    else
      add_index :other_incomes, [ :user_id, :start_date ]
    end
  end
end
