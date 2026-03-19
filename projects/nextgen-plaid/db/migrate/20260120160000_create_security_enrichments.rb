class CreateSecurityEnrichments < ActiveRecord::Migration[8.1]
  def change
    create_table :security_enrichments do |t|
      t.string :security_id, null: false
      t.string :source, null: false
      t.datetime :enriched_at, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :data, null: false, default: {}
      t.jsonb :notes, null: false, default: []

      t.timestamps
    end

    add_index :security_enrichments, [ :security_id, :source ], unique: true
    add_index :security_enrichments, :data, using: :gin
  end
end
