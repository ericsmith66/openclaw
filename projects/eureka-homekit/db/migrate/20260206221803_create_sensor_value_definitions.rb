class CreateSensorValueDefinitions < ActiveRecord::Migration[8.1]
  def change
    create_table :sensor_value_definitions do |t|
      t.references :room, foreign_key: true
      t.references :accessory, foreign_key: true
      t.references :sensor, foreign_key: true
      t.string :value
      t.string :label
      t.datetime :last_seen_at
      t.integer :occurrence_count, default: 0

      t.timestamps
    end
    add_index :sensor_value_definitions, [ :sensor_id, :value ], unique: true
  end
end
