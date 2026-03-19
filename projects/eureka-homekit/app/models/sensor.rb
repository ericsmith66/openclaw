class Sensor < ApplicationRecord
  belongs_to :accessory
  has_one :room, through: :accessory
  has_one :home, through: :room
  has_many :homekit_events, dependent: :destroy

  validates :service_uuid, presence: true
  validates :service_type, presence: true
  validates :characteristic_uuid, presence: true, uniqueness: { scope: :accessory_id }
  validates :characteristic_type, presence: true

  # Scopes for common sensor types
  scope :temperature, -> { where(characteristic_type: "Current Temperature") }
  scope :motion, -> { where(characteristic_type: "Motion Detected") }
  scope :humidity, -> { where(characteristic_type: "Current Relative Humidity") }
  scope :occupancy, -> { where(characteristic_type: "Occupancy Detected") }
  scope :light_level, -> { where(characteristic_type: "Current Ambient Light Level") }
  scope :battery_level, -> { where(characteristic_type: "Battery Level") }
  scope :battery_low, -> { where(characteristic_type: "Status Low Battery") }
  scope :contact, -> { where(characteristic_type: "Contact Sensor State") }
  scope :active_status, -> { where(characteristic_type: "Status Active") }
  scope :fault_status, -> { where(characteristic_type: "Status Fault") }

  has_many :sensor_value_definitions, dependent: :destroy

  scope :event_capable, -> { where(supports_events: true) }
  scope :controllable, -> { where(is_writable: true) }
  scope :recently_updated, ->(time = 1.hour.ago) { where("last_updated_at > ?", time) }
  scope :stale, ->(time = 1.hour.ago) {
    # A sensor is stale if its accessory is offline OR it hasn't been updated in a long time
    # (Though the user noted that lack of events is not an indicator of being offline,
    # we still need some fallback for sensors without Status Active)
    where("last_updated_at < ? OR last_updated_at IS NULL", time)
  }

  # Sensors that are explicitly reported as offline by HomeKit
  scope :offline_by_status, -> {
    joins(:accessory)
    .joins("INNER JOIN sensors status_sensors ON status_sensors.accessory_id = accessories.id")
    .where("status_sensors.characteristic_type = 'Status Active'")
    .where("status_sensors.current_value = '0'")
  }

  # Update sensor liveness and value definitions
  def update_liveness!(value, timestamp)
    update_columns(last_seen_at: timestamp)
    SensorValueDefinition.discover!(self, value, timestamp)

    accessory.update_liveness!(timestamp)
    room&.update_liveness!(timestamp, is_motion: motion_detected?(value))
  end

  # Update sensor value from event (called when value changes)
  def update_from_event!(value, timestamp)
    update!(
      current_value: value,
      last_updated_at: timestamp
    )
    update_liveness!(value, timestamp)
  end

  # Get typed value (cast from jsonb to appropriate Ruby type)
  def type_value(raw_value)
    return nil if raw_value.nil?

    val = case value_format
    when "float"
      raw_value.to_f
    when "int", "uint8"
      raw_value.to_i
    when "bool"
      raw_value.to_s == "1" || raw_value.to_s.downcase == "true"
    else
      # Try to infer if it's numeric
      if raw_value.is_a?(String) && raw_value.match?(/^-?\d+(\.\d+)?$/)
        raw_value.include?(".") ? raw_value.to_f : raw_value.to_i
      else
        raw_value
      end
    end

    # HomeKit temperatures are in Celsius, convert to Fahrenheit
    if characteristic_type == "Current Temperature" && val.is_a?(Numeric)
      val = (val * 9.0 / 5.0) + 32.0
    end

    val
  end

  def typed_value
    type_value(current_value)
  end

  # Compare two values for deduplication purposes WITHOUT unit conversion
  # This is separate from type_value which applies temperature conversion for display
  # NOTE: Both stored_value and incoming_value may be JSONB types from database,
  # so we need to handle String, Numeric, Boolean, and potentially Hash/Array
  def compare_values(stored_value, incoming_value)
    # Coerce both values using value_format, but WITHOUT unit conversions
    typed_stored = coerce_value_without_conversion(stored_value)
    typed_incoming = coerce_value_without_conversion(incoming_value)

    return true if typed_stored.nil? && typed_incoming.nil?
    return false if typed_stored.nil? || typed_incoming.nil?

    # Numeric comparison with epsilon for floats
    if typed_stored.is_a?(Numeric) && typed_incoming.is_a?(Numeric)
      return (typed_stored - typed_incoming).abs < 0.01
    end

    # Boolean comparison (handles "1", 1, true, "true")
    if [ true, false ].include?(typed_stored) && [ true, false ].include?(typed_incoming)
      return typed_stored == typed_incoming
    end

    # String comparison (case-insensitive)
    typed_stored.to_s.casecmp?(typed_incoming.to_s)
  rescue StandardError => e
    Rails.logger.warn("[Sensor#compare_values] Failed for sensor #{id}: #{e.message}")
    stored_value.to_s == incoming_value.to_s # Fallback to string comparison
  end

  # Check if the current value represents a boolean true state
  # Handles: true, 1, "1", "true", "on", "yes"
  def boolean_value?
    val = typed_value
    case val
    when true, 1, "1", "true", "on", "yes"
      true
    when false, 0, "0", "false", "off", "no"
      false
    else
      false
    end
  end

  # Human-readable value for any given raw value
  def format_value(raw_value)
    val = type_value(raw_value)
    return "N/A" if val.nil?

    case characteristic_type
    when "Current Temperature"
      "#{val.round(1)}#{value_unit}"
    when "Current Relative Humidity", "Battery Level"
      "#{val}#{value_unit}"
    when "Motion Detected", "Occupancy Detected"
      val ? "Detected" : "Clear"
    when "Contact Sensor State"
      val == 0 ? "Closed" : "Open"
    when "On"
      (raw_value.to_s == "1" || raw_value.to_s.downcase == "true") ? "ON" : "OFF"
    when "Lock Current State"
      case raw_value.to_s
      when "0" then "Unsecured"
      when "1" then "Secured"
      when "2" then "Jammed"
      when "3" then "Unknown"
      else raw_value.to_s
      end
    else
      "#{val} #{value_unit}".strip
    end
  end

  # Human-readable value with unit
  def formatted_value
    definition = sensor_value_definitions.find { |d| d.value == current_value.to_s }

    if definition
      label = definition.label.presence || format_value(current_value)
      units = definition.units

      # Display logic based on documentation
      if label.match?(/[a-zA-Z]/) || units.blank? || units.match?(/^[A-Z][a-z]+/)
        # Case 1 & 2: Non-numeric label OR blank units OR category units (Starts with capital letter)
        label
      else
        # Case 3: Symbolic units
        # If it's a percentage or degree, we don't want a space
        # Otherwise (like lux, W, %RH), we add a space for readability
        separator = units.match?(/[%°]/) ? "" : " "
        "#{label}#{separator}#{units}"
      end
    else
      format_value(current_value)
    end
  end

  # Human-readable unit for sensor type
  def value_unit
    case characteristic_type
    when "Current Temperature"
      "°F"
    when "Current Relative Humidity", "Battery Level", "Brightness", "Rotation Speed", "Current Position", "Target Position", "Saturation"
      "%"
    when "Current Ambient Light Level", "Current Light Level"
      "lux"
    else
      ""
    end
  end

  # Human-readable name
  def display_name
    "#{accessory.name} - #{characteristic_type}"
  end

  # Query events for this sensor (no has_many association needed)
  def events
    HomekitEvent.where(
      accessory_name: accessory.name,
      characteristic: characteristic_type
    ).order(timestamp: :desc)
  end

  # Check if sensor is offline (HomeKit reporting it as not responding)
  def offline?(threshold = 1.hour)
    # 1. Check if the accessory has an explicit 'Status Active' characteristic
    active_status_sensor = accessory.sensors.find_by(characteristic_type: "Status Active")
    if active_status_sensor
      # 0 means offline/not active
      return active_status_sensor.current_value.to_s == "0"
    end

    # 2. Check for 'Status Fault' if active status is missing
    fault_sensor = accessory.sensors.find_by(characteristic_type: "Status Fault")
    if fault_sensor
      # Non-zero usually means a fault
      return fault_sensor.current_value.to_s != "0" && fault_sensor.current_value.present?
    end

    # 3. Fallback: Only use heartbeat if no explicit status is available
    # The user said "fact that a sensor has not fired an event is not an indication that it's offline"
    # So we might want to be more lenient here or skip it entirely if we trust Status Active.
    # For now, keeping a much longer fallback or just returning false if unsure?
    # Let's keep a 24-hour safety net instead of 1 hour.
    last_updated_at.nil? || last_updated_at < 24.hours.ago
  end

  # Check if sensor is active (has recent updates)
  def active?(threshold = 1.hour)
    !offline?(threshold)
  end

  private

  def coerce_value_without_conversion(raw_value)
    return nil if raw_value.nil?

    case value_format
    when "float" then raw_value.to_f
    when "int", "uint8" then raw_value.to_i
    when "bool"
      case raw_value.to_s.downcase
      when "1", "true", "on", "yes" then true
      when "0", "false", "off", "no" then false
      else false
      end
    else
      # Try to infer if it's numeric
      if raw_value.is_a?(String) && raw_value.match?(/^-?\d+(\.\d+)?$/)
        raw_value.include?(".") ? raw_value.to_f : raw_value.to_i
      else
        raw_value
      end
    end
  end

  def motion_detected?(value)
    characteristic_type == "Motion Detected" && (value.to_s == "1" || value.to_s.downcase == "true")
  end
end
