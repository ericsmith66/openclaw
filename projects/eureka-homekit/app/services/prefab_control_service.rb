class PrefabControlService
  RETRY_DELAY = 0.5
  MAX_ATTEMPTS = ENV.fetch("PREFAB_RETRY_ATTEMPTS", "1").to_i + 1 # ENV is retry count; +1 for initial attempt
  DEDUPLICATION_WINDOW = 10.seconds

  # Set a characteristic value with retry and logging
  def self.set_characteristic(accessory:, characteristic:, value:, user_ip: nil, source: "web")
    request_id = SecureRandom.uuid
    home = accessory.room&.home&.name
    room = accessory.room&.name
    accessory_name = accessory.name
    sensor = accessory.sensors.find_by(characteristic_type: characteristic)
    old_value = sensor&.typed_value

    # Check for duplicate command within deduplication window
    recent_event = ControlEvent.where(
      accessory: accessory,
      characteristic_name: characteristic,
      new_value: value.to_s,
      success: true
    ).where("created_at > ?", DEDUPLICATION_WINDOW.ago).order(created_at: :desc).first

    if recent_event
      Rails.logger.info "[PrefabControlService] Deduplicated command: #{accessory_name}.#{characteristic} = #{value} (recent success: #{recent_event.created_at.iso8601})"
      return {
        success: true,
        deduplicated: true,
        message: "Identical command already sent",
        original_event_id: recent_event.id,
        original_timestamp: recent_event.created_at
      }
    end

    start_time = Time.now
    if sensor.nil?
      result = { success: false, error: "Characteristic not found" }
    elsif sensor.service_uuid.blank? || sensor.characteristic_uuid.blank?
      result = { success: false, error: "Missing service/characteristic identifiers" }
    else
      result = attempt_set_characteristic(
        home,
        room,
        accessory_name,
        sensor.service_uuid,
        sensor.characteristic_uuid,
        value,
        request_id: request_id
      )
    end

    # Retry on failure - exactly 3 attempts with 500ms fixed sleep
    (MAX_ATTEMPTS - 1).times do
      break if result[:success]
      sleep(RETRY_DELAY)
      break if result[:error] == "Characteristic not found" || result[:error] == "Missing service/characteristic identifiers"

      result = attempt_set_characteristic(
        home,
        room,
        accessory_name,
        sensor.service_uuid,
        sensor.characteristic_uuid,
        value,
        request_id: request_id
      )
    end

    latency = ((Time.now - start_time) * 1000).round(2)

    # Log control event
    create_control_event(
      accessory: accessory,
      action_type: "set_characteristic",
      characteristic_name: characteristic,
      old_value: old_value,
      new_value: value,
      success: result[:success],
      error_message: result[:error],
      latency_ms: latency,
      user_ip: user_ip,
      source: source,
      request_id: request_id
    )

    result
  end

  # Execute a scene with retry and logging
  def self.trigger_scene(scene:, user_ip: nil, source: "web")
    request_id = SecureRandom.uuid
    home = scene.home&.name
    scene_uuid = scene.uuid
    start_time = Time.now

    result = attempt_execute_scene(home, scene_uuid, request_id: request_id)

    # Retry on failure - exactly 3 attempts with 500ms fixed sleep
    (MAX_ATTEMPTS - 1).times do
      break if result[:success]
      sleep(RETRY_DELAY)
      result = attempt_execute_scene(home, scene_uuid, request_id: request_id)
    end

    latency = ((Time.now - start_time) * 1000).round(2)

    # Log control event
    create_control_event(
      scene: scene,
      action_type: "execute_scene",
      success: result[:success],
      error_message: result[:error],
      latency_ms: latency,
      user_ip: user_ip,
      source: source,
      request_id: request_id
    )

    result
  end

  private

  def self.attempt_set_characteristic(home, room, accessory_name, service_id, characteristic_id, value, request_id: nil)
    result = PrefabClient.update_characteristic(
      home,
      room,
      accessory_name,
      service_id,
      characteristic_id,
      value,
      request_id: request_id
    )
    { success: result[:success], error: result[:error], latency_ms: result[:latency_ms] }
  end

  def self.attempt_execute_scene(home, scene_uuid, request_id: nil)
    result = PrefabClient.execute_scene(home, scene_uuid, request_id: request_id)
    { success: result[:success], error: result[:error], latency_ms: result[:latency_ms] }
  end

  def self.create_control_event(accessory: nil, scene: nil, action_type:, characteristic_name: nil,
                                old_value: nil, new_value: nil, success:, error_message: nil,
                                latency_ms:, user_ip: nil, source:, request_id: nil)
    ControlEvent.create!(
      accessory: accessory,
      scene: scene,
      action_type: action_type,
      characteristic_name: characteristic_name,
      old_value: coerce_to_string(old_value),
      new_value: coerce_to_string(new_value),
      success: success,
      error_message: scrub_error_message(error_message),
      latency_ms: latency_ms,
      user_ip: user_ip,
      source: source,
      request_id: request_id || SecureRandom.uuid
    )
  end

  def self.coerce_to_string(value)
    return nil if value.nil?
    value.to_s
  end

  def self.scrub_error_message(message)
    return nil if message.nil?
    # Remove sensitive data like API keys from error messages
    message.gsub(/(Bearer |token=|api_key=|key=)\s*[^"'\s]+/, '\1[FILTERED]')
  end
end
