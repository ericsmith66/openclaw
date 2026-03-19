class AddUnitsToSensorValueDefinitions < ActiveRecord::Migration[8.1]
  def change
    add_column :sensor_value_definitions, :units, :string
  end
end
