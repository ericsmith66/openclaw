class CreateSensors < ActiveRecord::Migration[8.1]
  def change
    create_table :sensors do |t|
      t.references :accessory, null: false, foreign_key: true

      # Service identification
      t.string :service_uuid, null: false
      t.string :service_type, null: false

      # Characteristic identification
      t.string :characteristic_uuid, null: false
      t.string :characteristic_type, null: false
      t.string :characteristic_homekit_type

      # Current value and metadata
      t.jsonb :current_value
      t.string :value_format
      t.string :units
      t.float :min_value
      t.float :max_value
      t.float :step_value

      # Permissions and capabilities
      t.jsonb :properties, default: []
      t.boolean :supports_events, default: false
      t.boolean :is_writable, default: false

      # Full metadata from Prefab
      t.jsonb :metadata, default: {}

      # Timestamps
      t.datetime :last_updated_at

      t.timestamps
    end

    add_index :sensors, [ :accessory_id, :characteristic_uuid ], unique: true, name: 'index_sensors_on_accessory_and_characteristic'
    add_index :sensors, :service_type
    add_index :sensors, :characteristic_type
    add_index :sensors, :last_updated_at
    add_index :sensors, :supports_events
  end
end
