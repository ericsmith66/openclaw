class CreateScenes < ActiveRecord::Migration[8.1]
  def change
    create_table :scenes do |t|
      t.string :name
      t.string :uuid
      t.references :home, null: false, foreign_key: true
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    add_index :scenes, :name
    add_index :scenes, :uuid, unique: true
  end
end
