class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.string :name
      t.string :uuid
      t.references :home, null: false, foreign_key: true

      t.timestamps
    end
    add_index :rooms, :name
    add_index :rooms, :uuid, unique: true
  end
end
