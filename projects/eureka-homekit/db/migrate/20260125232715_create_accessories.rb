class CreateAccessories < ActiveRecord::Migration[8.1]
  def change
    create_table :accessories do |t|
      t.string :name
      t.string :uuid
      t.references :room, null: false, foreign_key: true
      t.jsonb :characteristics, default: {}

      t.timestamps
    end
    add_index :accessories, :name
    add_index :accessories, :uuid, unique: true
  end
end
