class CreateSceneAccessories < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_accessories do |t|
      t.references :scene, null: false, foreign_key: true
      t.references :accessory, null: false, foreign_key: true

      t.timestamps
    end
  end
end
