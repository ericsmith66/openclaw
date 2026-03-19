class CreateOtherIncomes < ActiveRecord::Migration[8.1]
  def change
    create_table :other_incomes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.date :date, null: false
      t.decimal :projected_amount, precision: 15, scale: 2, null: false
      t.decimal :accrued_amount, precision: 15, scale: 2
      t.decimal :suggested_tax_rate, precision: 8, scale: 4, null: false

      t.timestamps
    end

    add_index :other_incomes, [ :user_id, :date ]
  end
end
