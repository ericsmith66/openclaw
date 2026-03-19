
accessory_count = 0
sensor_count = 0

Accessory.find_each do |acc|
  accessory_count += 1
  raw = acc.raw_data
  next unless raw && raw['services']

  raw['services'].each do |svc|
    svc_type = svc['typeName']
    next unless svc['characteristics']

    svc['characteristics'].each do |char|
      char_type = char['typeName']

      # Basic heuristics for what we consider a 'sensor' for the dashboard
      # Temperature, Motion, Humidity, Battery Level, Light Level, Contact, Occupancy
      is_sensor = [
        'Current Temperature', 'Motion Detected', 'Current Relative Humidity',
        'Battery Level', 'Current Ambient Light Level', 'Contact Sensor State',
        'Occupancy Detected', 'Status Low Battery'
      ].include?(char_type)

      if is_sensor
        Sensor.find_or_create_by!(
          accessory: acc,
          characteristic_uuid: char['uniqueIdentifier']
        ) do |s|
          s.service_uuid = svc['uniqueIdentifier']
          s.service_type = svc_type
          s.characteristic_type = char_type
          s.current_value = char['value']
          s.value_format = char.dig('metadata', 'format')
          s.supports_events = char['properties']&.include?('HMCharacteristicPropertySupportsEventNotification')
          s.is_writable = char['properties']&.include?('HMCharacteristicPropertyWritable')
        end
        sensor_count += 1
      end
    end
  end
end

puts "Processed #{accessory_count} accessories."
puts "Created #{sensor_count} sensors."
