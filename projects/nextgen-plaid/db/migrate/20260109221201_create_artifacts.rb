class CreateArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :artifacts do |t|
      t.string :name
      t.string :artifact_type
      t.string :phase
      t.string :owner_persona
      t.jsonb :payload
      t.integer :lock_version, default: 0, null: false

      t.timestamps
    end
    add_index :artifacts, :phase
    add_index :artifacts, :artifact_type
    add_index :artifacts, :owner_persona
  end
end
