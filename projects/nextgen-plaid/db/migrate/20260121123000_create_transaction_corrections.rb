class CreateTransactionCorrections < ActiveRecord::Migration[8.1]
  def change
    create_table :transaction_corrections do |t|
      t.references :original_transaction, null: false, foreign_key: { to_table: :transactions }
      t.references :corrected_transaction, null: false, foreign_key: { to_table: :transactions }
      t.string :reason, null: false
      t.jsonb :plaid_correction_data
      t.datetime :corrected_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
    end

    add_index :transaction_corrections, :corrected_at
    add_index :transaction_corrections,
              [ :original_transaction_id, :corrected_transaction_id ],
              unique: true,
              name: "idx_txn_corrections_unique"
  end
end
