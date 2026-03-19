# Sensor Model Architecture Proposal

## Overview
Extract sensor characteristics from accessories into a dedicated `Sensor` model for better querying, real-time updates, and historical tracking.

## Proposed Schema

### Sensors Table

```ruby
create_table :sensors do |t|
  t.references :accessory, null: false, foreign_key: true

  # Service identification
  t.string :service_uuid, null: false  # HomeKit service UUID (e.g., "D6491F9F-91E0...")
  t.string :service_type, null: false  # "Temperature Sensor", "Motion Sensor", etc.

  # Characteristic identification
  t.string :characteristic_uuid, null: false  # HomeKit characteristic UUID
  t.string :characteristic_type, null: false  # "Current Temperature", "Motion Detected", etc.
  t.string :characteristic_homekit_type     # HomeKit type UUID (e.g., "00000011-0000...")

  # Current value and metadata
  t.jsonb :current_value      # Stores the current value (can be number, bool, string)
  t.string :value_format      # "float", "int", "bool", "string"
  t.string :units             # "celsius", "lux", "percentage", etc.
  t.float :min_value
  t.float :max_value
  t.float :step_value

  # Permissions and capabilities
  t.jsonb :properties         # ["HMCharacteristicPropertyReadable", ...]
  t.boolean :supports_events, default: false  # Can receive webhook events
  t.boolean :is_writable, default: false      # Can be controlled

  # Full metadata from Prefab
  t.jsonb :metadata           # Complete metadata object from Prefab

  # Timestamps
  t.datetime :last_updated_at # When value last changed (from event)
  t.timestamps
end

add_index :sensors, [:accessory_id, :characteristic_uuid], unique: true, name: 'index_sensors_on_accessory_and_characteristic'
add_index :sensors, :service_type
add_index :sensors, :characteristic_type
add_index :sensors, :last_updated_at
```

### Sensor Model

```ruby
class Sensor < ApplicationRecord
  belongs_to :accessory
  has_one :room, through: :accessory
  has_one :home, through: :room

  # Optional: for time-series data
  # has_many :sensor_readings, dependent: :destroy

  validates :service_uuid, presence: true
  validates :service_type, presence: true
  validates :characteristic_uuid, presence: true, uniqueness: { scope: :accessory_id }
  validates :characteristic_type, presence: true

  # Scopes for common queries
  scope :temperature, -> { where(characteristic_type: 'Current Temperature') }
  scope :motion, -> { where(characteristic_type: 'Motion Detected') }
  scope :humidity, -> { where(characteristic_type: 'Current Relative Humidity') }
  scope :light_level, -> { where(characteristic_type: 'Current Ambient Light Level') }
  scope :battery_level, -> { where(characteristic_type: 'Battery Level') }
  scope :contact, -> { where(characteristic_type: 'Contact Sensor State') }
  scope :occupancy, -> { where(characteristic_type: 'Occupancy Detected') }

  scope :event_capable, -> { where(supports_events: true) }
  scope :controllable, -> { where(is_writable: true) }
  scope :recently_updated, -> { where('last_updated_at > ?', 1.hour.ago) }

  # Update sensor value from event
  def update_from_event!(value, timestamp)
    update!(
      current_value: value,
      last_updated_at: timestamp
    )
  end

  # Get typed value (cast from jsonb)
  def typed_value
    return nil if current_value.nil?

    case value_format
    when 'float'
      current_value.to_f
    when 'int', 'uint8'
      current_value.to_i
    when 'bool'
      current_value.to_s == '1' || current_value.to_s.downcase == 'true'
    else
      current_value.to_s
    end
  end

  # Human-readable name
  def display_name
    "#{accessory.name} - #{characteristic_type}"
  end
end
```

## What to Do With Different Service Types

### 1. **Sensor Services** → Extract to `Sensor` model
These represent **measurable characteristics** that change over time and send events:

- ✅ **Temperature Sensor** - Current Temperature
- ✅ **Motion Sensor** - Motion Detected
- ✅ **Humidity Sensor** - Current Relative Humidity
- ✅ **Light Sensor** - Current Ambient Light Level
- ✅ **Contact Sensor** - Contact Sensor State
- ✅ **Occupancy Sensor** - Occupancy Detected
- ✅ **Battery Service** - Battery Level, Status Low Battery
- ✅ **Sound Detector** - Sound Detected (custom)

**Why extract**: These are the core sensor readings you want to query, monitor, and track.

### 2. **Accessory Information** → Keep in `accessories.raw_data`
These are **static metadata** about the device:

- ❌ Model
- ❌ Manufacturer
- ❌ Serial Number
- ❌ Firmware Revision
- ❌ Name

**Why keep in raw_data**: This info rarely changes and is already available via `accessory.raw_data['services']`. Could optionally denormalize to accessory columns (manufacturer, model, etc.) but not necessary.

### 3. **Configuration Services** → Keep in `accessories.raw_data`
These are **writable settings** for the device:

- ❌ **Sensor Configuration Service** - Temperature Display Units, Motion Detector Silence Duration, etc.
- ❌ **Cloud Credentials Service** - API keys, Thing IDs

**Why keep in raw_data**: These are configuration parameters, not sensor readings. They're writable but rarely change. If you need to control devices later, you can add a separate `DeviceControl` concern.

### 4. **Automation/Logic Services** → Consider extracting OR keep in raw_data
These are **derived/computed characteristics**:

- ⚠️ **Inactivity Detector Service** - "Motion Detector Silent for Configured Duration"
- ⚠️ **Light Detected** (bool derived from light level)

**Options:**
- **Option A**: Extract as sensors if you want to query them easily
- **Option B**: Keep in raw_data if they're just for HomeKit automation
- **Recommendation**: Extract if you plan to use them in your app logic

### 5. **System Services** → Keep in `accessories.raw_data`
These are **internal/maintenance** characteristics:

- ❌ **Firmware Upgrade Service** - Upgrade status, URLs
- ❌ **Identify** - Makes device identify itself (blink LED, etc.)

**Why keep in raw_data**: System-level operations, not sensor data.

## Extraction Logic

Only extract characteristics that meet **ALL** criteria:

1. ✅ Has `HMCharacteristicPropertySupportsEventNotification` (can send events)
2. ✅ Is NOT a "Name" characteristic
3. ✅ Service type ends with "Sensor" OR Service type is "Battery Service"
4. ✅ Characteristic type is in allowlist:
   - Current Temperature
   - Motion Detected
   - Current Relative Humidity
   - Current Ambient Light Level
   - Contact Sensor State
   - Occupancy Detected
   - Battery Level
   - Status Low Battery
   - Sound Detected
   - Light Detected

## Example Queries After Implementation

```ruby
# Find all temperature sensors
Sensor.temperature

# Get current temperature in Master Bath
room = Room.find_by(name: 'Master Bath')
room.sensors.temperature.first.typed_value
# => 22.1

# Find all motion sensors that detected motion recently
Sensor.motion.where(current_value: '1').recently_updated

# Get battery levels for all sensors
Sensor.battery_level.pluck(:accessory_id, :current_value)

# Find sensors that haven't reported in over 1 hour (offline?)
Sensor.event_capable.where('last_updated_at < ?', 1.hour.ago)

# All sensors in Master Bedroom
room = Room.find_by(name: 'Master Bedroom')
room.sensors.includes(:accessory)
```

## Event Processing Flow

When webhook event arrives:
```
POST /api/homekit/events
{
  "type": "characteristic_updated",
  "accessory": "master bath sensor",
  "characteristic": "Current Temperature",
  "value": 23.5,
  "timestamp": "2026-01-26T16:00:00Z"
}

1. Find accessory by name
2. Find sensor by accessory + characteristic_type
3. sensor.update_from_event!(23.5, timestamp)
4. (Optional) Create SensorReading for history
```

## Migration Plan

1. Create `sensors` table migration
2. Create `Sensor` model with associations and scopes
3. Create `HomekitSync#extract_sensors` method
4. Run sync to populate sensors from existing accessories
5. Update `Api::HomekitEventsController` to update sensors
6. (Optional) Create `sensor_readings` table for time-series

## Summary

**Extract to Sensor model:**
- All sensor characteristics that support events
- Battery status
- Any characteristic you want to query/monitor

**Keep in accessories.raw_data:**
- Accessory Information (metadata)
- Configuration settings
- Firmware/system services
- Everything else

This gives you a clean separation: **Sensors** for real-time monitoring and **raw_data** for complete device information.
