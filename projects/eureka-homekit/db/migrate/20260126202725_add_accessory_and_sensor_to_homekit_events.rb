class AddAccessoryAndSensorToHomekitEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :homekit_events, :accessory, null: true, foreign_key: true
    add_reference :homekit_events, :sensor, null: true, foreign_key: true
  end
end
