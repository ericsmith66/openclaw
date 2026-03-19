class HomekitSync
  def self.perform
    new.perform
  end

  def perform(cleanup: false)
    summary = { homes: 0, rooms: 0, accessories: 0, scenes: 0, deleted: 0 }

    homes_data = PrefabClient.homes || []

    if homes_data.blank?
      homes_data = PrefabClient.homes || []
      summary[:sync_retried] = true
    end

    if homes_data.blank?
      summary[:sync_skipped] = true
      summary[:sync_reason] = "no homes returned from Prefab"

      if cleanup
        summary[:cleanup_skipped] = true
        summary[:cleanup_reason] = "no homes returned from Prefab"
        Rails.logger.warn("Cleanup skipped: no homes returned from Prefab")
      end

      Rails.logger.warn("Sync skipped: no homes returned from Prefab")
      Rails.logger.info("Sync complete: #{summary}")
      return summary
    end

    Rails.logger.info("Syncing #{homes_data.size} homes from Prefab (cleanup: #{cleanup})")

    synced_home_ids = []
    synced_room_ids = []
    synced_accessory_ids = []
    synced_sensor_ids = []
    synced_scene_ids = []

    homes_data.each do |home_data|
      begin
        home = sync_home(home_data)
        summary[:homes] += 1
        synced_home_ids << home.id

        # Sync rooms and accessories
        rooms_data = PrefabClient.rooms(home.name)
        rooms_data.each do |room_data|
          room = sync_room(home, room_data)
          summary[:rooms] += 1
          synced_room_ids << room.id

          accessories_data = PrefabClient.accessories(home.name, room.name)
          accessories_data.each do |accessory_data|
            accessory = sync_accessory(room, accessory_data)
            summary[:accessories] += 1
            synced_accessory_ids << accessory.id

            # Extract sensors
            extract_sensors(accessory).each do |sensor|
              synced_sensor_ids << sensor.id
            end
          end
        end

        # Sync scenes
        scenes_data = PrefabClient.scenes(home.name)
        scenes_data.each do |scene_data|
          scene = sync_scene(home, scene_data)
          summary[:scenes] += 1
          synced_scene_ids << scene.id
        end
      rescue StandardError => e
        Rails.logger.error("Error syncing home #{home_data['name']}: #{e.message}")
      end
    end

    if cleanup
      # Use dependent: :destroy logic by loading and destroying records
      # This ensures foreign keys and dependent associations are handled correctly
      # 1. Accessories (and their Sensors/Events via dependent: :destroy)
      Accessory.where.not(id: synced_accessory_ids).find_each do |acc|
        summary[:deleted] += 1 # Count the accessory
        acc.destroy
      end

      # 2. Scenes
      Scene.where.not(id: synced_scene_ids).find_each do |scene|
        summary[:deleted] += 1
        scene.destroy
      end

      # 3. Rooms
      Room.where.not(id: synced_room_ids).find_each do |room|
        summary[:deleted] += 1
        room.destroy
      end

      # 4. Homes
      Home.where.not(id: synced_home_ids).find_each do |home|
        next if home.floorplans.exists?

        summary[:deleted] += 1
        home.destroy
      end
    end

    Rails.logger.info("Sync complete: #{summary}")
    summary
  end

  # Extract sensors from accessory's raw_data (public method)
  def extract_sensors(accessory)
    return [] unless accessory.raw_data["services"]

    created_sensors = []

    accessory.raw_data["services"].each do |service|
      # Skip non-sensor services
      next unless should_extract_service?(service)

      service["characteristics"].each do |char|
        # Skip non-sensor characteristics
        next unless should_extract_characteristic?(char)

        sensor = Sensor.find_or_initialize_by(
          accessory: accessory,
          characteristic_uuid: char["uniqueIdentifier"]
        )

        characteristic_type = char["typeName"].presence || char["description"].presence || "Custom"

        sensor.assign_attributes(
          service_uuid: service["uniqueIdentifier"],
          service_type: service["typeName"] || "Unknown",
          characteristic_type: characteristic_type,
          characteristic_homekit_type: char["type"],
          current_value: char["value"],
          value_format: char["metadata"]&.dig("format"),
          units: char["metadata"]&.dig("units"),
          min_value: char["metadata"]&.dig("minimumValue")&.to_f,
          max_value: char["metadata"]&.dig("maximumValue")&.to_f,
          step_value: char["metadata"]&.dig("stepValue")&.to_f,
          properties: char["properties"] || [],
          supports_events: char["properties"]&.include?("HMCharacteristicPropertySupportsEventNotification") || false,
          is_writable: char["properties"]&.include?("HMCharacteristicPropertyWritable") || false,
          metadata: char["metadata"] || {}
        )

        if sensor.save
          created_sensors << sensor
        else
          Rails.logger.error("Failed to save sensor: #{sensor.errors.full_messages.join(', ')}")
        end
      end
    end

    created_sensors
  end

  private

  def sync_home(data)
    # Generate UUID from name if not provided by Prefab
    uuid = data["uuid"] || generate_uuid("home", data["name"])

    home = Home.find_by(uuid: uuid)
    if home.nil?
      # Preserve existing home (and floorplans) when Prefab UUID changes
      home = Home.find_by(name: data["name"])
      home&.uuid = uuid
    end

    home ||= Home.new(uuid: uuid)
    home.assign_attributes(
      name: data["name"],
      homekit_home_id: data["id"] || data["name"],
      raw_data: data
    )
    home.save!
    home
  end

  def sync_room(home, data)
    # Generate UUID from home+room name if not provided
    uuid = data["uuid"] || generate_uuid("room", home.name, data["name"])

    room = Room.find_or_initialize_by(uuid: uuid)
    room.assign_attributes(
      name: data["name"],
      home: home,
      raw_data: data
    )
    room.save!
    room
  end

  def sync_accessory(room, data)
    # Fetch detailed accessory info to get real HomeKit UUID
    details = PrefabClient.accessory_details(room.home.name, room.name, data["name"])

    # Extract UUID from first service's uniqueIdentifier if available
    uuid = nil
    if details && details["services"]&.any?
      uuid = details["services"].first["uniqueIdentifier"]
    end

    # Fall back to generated UUID if not available
    uuid ||= data["uuid"] || generate_uuid("accessory", room.home.name, room.name, data["name"])

    accessory = Accessory.find_or_initialize_by(uuid: uuid)
    accessory.assign_attributes(
      name: data["name"],
      room: room,
      characteristics: data["characteristics"] || {},
      raw_data: details || data
    )
    accessory.save!
    accessory
  end

  def sync_scene(home, data)
    # Use real HomeKit UUID from Prefab if available, otherwise generate
    uuid = data["uniqueIdentifier"] || data["uuid"] || generate_uuid("scene", home.name, data["name"])

    scene = Scene.find_or_initialize_by(uuid: uuid)
    scene.assign_attributes(
      name: data["name"],
      home: home,
      metadata: data["metadata"] || {},
      raw_data: data
    )
    scene.save!

    # Clear existing associations and rebuild
    scene.scene_accessories.destroy_all

    # Parse actions from the scene response to link accessories
    if data["actions"].present?
      data["actions"].each do |action|
        accessory = Accessory.joins(room: :home).find_by(
          homes: { id: home.id },
          accessories: { name: action["accessoryName"] }
        )

        if accessory
          scene.scene_accessories.create!(
            accessory: accessory,
            metadata: {
              service_name: action["serviceName"],
              characteristic_type: action["characteristicType"],
              target_value: action["targetValue"]
            }
          )
        end
      end
    # Fallback: Link accessories if provided (by name or UUID) for legacy support
    elsif data["accessories"].present?
      data["accessories"].each do |accessory_ref|
        accessory = Accessory.joins(room: :home).find_by(
          homes: { id: home.id },
          accessories: { uuid: accessory_ref }
        ) || Accessory.joins(room: :home).find_by(
          homes: { id: home.id },
          accessories: { name: accessory_ref }
        )

        scene.accessories << accessory if accessory
      end
    end

    scene
  end

  private

  # Generate deterministic UUID from components
  # This ensures the same name combination always generates the same UUID
  def generate_uuid(*components)
    require "digest/sha1"
    Digest::SHA1.hexdigest(components.join("::"))[0..35]
  end

  # Determine if service should be extracted as sensor(s)
  def should_extract_service?(service)
    service_type = service["typeName"].to_s

    # Include sensor services, battery service, and thermostat service
    return true if service_type.include?("Sensor")
    return true if service_type == "Battery Service"
    return true if service_type == "Thermostat"

    control_services = [
      "Lightbulb",
      "Switch",
      "Outlet",
      "Fan",
      "Fanv2",
      "GarageDoorOpener",
      "WindowCovering",
      "LockMechanism"
    ]

    return true if control_services.include?(service_type)

    false
  end

  # Determine if characteristic should be extracted
  def should_extract_characteristic?(char)
    # Skip Name characteristics
    return false if char["typeName"] == "Name"

    is_writable = char["properties"]&.include?("HMCharacteristicPropertyWritable")
    supports_events = char["properties"]&.include?("HMCharacteristicPropertySupportsEventNotification")

    # Must support events or be writable to be useful as a sensor/control
    return false unless supports_events || is_writable

    # Allowlist of sensor characteristics we want to track
    allowed_characteristics = [
      "Current Temperature",
      "Motion Detected",
      "Current Relative Humidity",
      "Current Ambient Light Level",
      "Contact Sensor State",
      "Occupancy Detected",
      "Battery Level",
      "Status Low Battery",
      "Sound Detected",
      "Light Detected",
      "Current Light Level",
      "Status Active",
      "Status Tampered",
      "Charging State",
      "On",
      "Brightness",
      "Hue",
      "Saturation",
      "Active",
      "Rotation Speed",
      "Rotation Direction",
      "Swing Mode",
      "Target Position",
      "Current Position",
      "Target Horizontal Tilt Angle",
      "Current Horizontal Tilt Angle",
      "Obstruction Detected",
      "Current Door State",
      "Target Door State",
      "Lock Current State",
      "Lock Target State",
      "Target Temperature",
      "Current Heating Cooling State",
      "Target Heating Cooling State",
      "Outlet In Use"
    ]

    allowed_characteristics.include?(char["typeName"]) || char["typeName"].blank? && char["description"] == "Custom"
  end
end
