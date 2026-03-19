class CreateFinancialSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :financial_snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :snapshot_at, null: false
      t.jsonb :data, null: false, default: {}
      t.integer :status, null: false, default: 0
      t.integer :schema_version, null: false

      t.timestamps
    end

    # Uniqueness relies on application-level CST normalization (see `FinancialSnapshot#normalize_snapshot_at`).
    add_index :financial_snapshots, [ :user_id, :snapshot_at ], unique: true

    # Secondary index for efficient "recent snapshots" queries.
    add_index :financial_snapshots, [ :user_id, :snapshot_at ], order: { snapshot_at: :desc }, name: "index_financial_snapshots_on_user_id_and_snapshot_at_desc"
    add_index :financial_snapshots, :data, using: :gin
  end
end
