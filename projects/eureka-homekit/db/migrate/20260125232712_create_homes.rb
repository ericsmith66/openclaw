class CreateHomes < ActiveRecord::Migration[8.1]
  def change
    create_table :homes do |t|
      t.string :name
      t.string :uuid
      t.string :homekit_home_id

      t.timestamps
    end
    add_index :homes, :name
    add_index :homes, :uuid, unique: true
  end
end
