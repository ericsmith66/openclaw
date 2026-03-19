class CreateFloorplans < ActiveRecord::Migration[8.1]
  def change
    create_table :floorplans do |t|
      t.references :home, null: false, foreign_key: true
      t.integer :level
      t.string :name

      t.timestamps
    end
  end
end
