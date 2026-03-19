class CreateHomekitEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :homekit_events do |t|
      t.string :event_type
      t.string :accessory_name
      t.string :characteristic
      t.jsonb :value
      t.jsonb :raw_payload
      t.datetime :timestamp

      t.timestamps
    end
    add_index :homekit_events, :event_type
    add_index :homekit_events, :accessory_name
    add_index :homekit_events, :timestamp
  end
end
