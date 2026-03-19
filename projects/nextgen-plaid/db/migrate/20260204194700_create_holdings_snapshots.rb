class CreateHoldingsSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :holdings_snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.references :account, null: true, foreign_key: true
      t.string :name
      t.jsonb :snapshot_data, null: false, default: {}

      t.timestamps
    end

    add_index :holdings_snapshots, [ :user_id, :created_at ]
  end
end
