class CreateAccountBalanceSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :account_balance_snapshots do |t|
      t.references :account, null: false, foreign_key: true
      t.date :snapshot_date, null: false

      t.decimal :available_balance, precision: 15, scale: 2
      t.decimal :current_balance, precision: 15, scale: 2
      t.decimal :limit, precision: 15, scale: 2
      t.string :iso_currency_code, default: "USD"

      t.decimal :apr_percentage, precision: 5, scale: 2
      t.decimal :min_payment_amount, precision: 15, scale: 2
      t.date :next_payment_due_date
      t.boolean :is_overdue, default: false

      t.datetime :synced_at
      t.string :source, default: "plaid"

      t.timestamps

      t.index [ :account_id, :snapshot_date ], unique: true, name: "index_balance_snapshots_unique"
      t.index :snapshot_date
      t.index [ :account_id, :synced_at ]
    end
  end
end
