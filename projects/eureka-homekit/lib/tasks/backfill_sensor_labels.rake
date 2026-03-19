namespace :sensors do
  desc "Backfill missing labels in sensor_value_definitions"
  task backfill_labels: :environment do
    definitions = SensorValueDefinition.where(label: [ nil, "" ])
    puts "Found #{definitions.count} definitions with missing labels."

    updated_count = 0
    definitions.find_each do |definition|
      sensor = definition.sensor
      next unless sensor

      new_label = sensor.format_value(definition.value)
      if new_label.present?
        definition.update_columns(label: new_label)
        updated_count += 1
      end
    end

    puts "Updated #{updated_count} definitions with new labels."
  end
end
