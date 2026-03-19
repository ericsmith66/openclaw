class FixOtherIncomesColumnsForPrd110 < ActiveRecord::Migration[8.1]
  def up
    # Rename legacy columns if they still exist
    rename_column :other_incomes, :projected_amount, :amount if column_exists?(:other_incomes, :projected_amount)
    rename_column :other_incomes, :date, :start_date if column_exists?(:other_incomes, :date)

    if column_exists?(:other_incomes, :amount)
      change_column :other_incomes, :amount, :decimal, precision: 12, scale: 2, null: false
    end

    add_column :other_incomes, :frequency, :string, null: false, default: "annual" unless column_exists?(:other_incomes, :frequency)
    add_column :other_incomes, :end_date, :date unless column_exists?(:other_incomes, :end_date)
    add_column :other_incomes, :category, :string unless column_exists?(:other_incomes, :category)
    add_column :other_incomes, :taxable, :boolean, null: false, default: true unless column_exists?(:other_incomes, :taxable)
    add_column :other_incomes, :notes, :text unless column_exists?(:other_incomes, :notes)

    change_column_null :other_incomes, :suggested_tax_rate, true if column_exists?(:other_incomes, :suggested_tax_rate)

    # Ensure index on user + start_date
    if index_exists?(:other_incomes, [ :user_id, :start_date ])
      # ok
    else
      remove_index :other_incomes, column: [ :user_id, :date ] if index_exists?(:other_incomes, [ :user_id, :date ])
      add_index :other_incomes, [ :user_id, :start_date ]
    end
  end

  def down
    # Best-effort rollback (not strictly required for this PRD)
    remove_index :other_incomes, column: [ :user_id, :start_date ] if index_exists?(:other_incomes, [ :user_id, :start_date ])

    remove_column :other_incomes, :notes if column_exists?(:other_incomes, :notes)
    remove_column :other_incomes, :taxable if column_exists?(:other_incomes, :taxable)
    remove_column :other_incomes, :category if column_exists?(:other_incomes, :category)
    remove_column :other_incomes, :end_date if column_exists?(:other_incomes, :end_date)
    remove_column :other_incomes, :frequency if column_exists?(:other_incomes, :frequency)

    rename_column :other_incomes, :start_date, :date if column_exists?(:other_incomes, :start_date) && !column_exists?(:other_incomes, :date)
    rename_column :other_incomes, :amount, :projected_amount if column_exists?(:other_incomes, :amount) && !column_exists?(:other_incomes, :projected_amount)

    add_index :other_incomes, [ :user_id, :date ] if column_exists?(:other_incomes, :date) && !index_exists?(:other_incomes, [ :user_id, :date ])
  end
end
