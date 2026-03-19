# Sensors vs HomeKit Events - Relationship Explained

## The Relationship

```
HomekitEvent (webhook log) ──updates──> Sensor (current state)
       │
       └──optionally creates──> SensorReading (historical record)
```

### HomekitEvent
**Purpose**: **Audit log** of all events received from Prefab
- Stores **every event** that comes through the webhook
- **Immutable** - events are never updated, only created
- Used for: debugging, audit trail, event history

### Sensor
**Purpose**: **Current state** of each sensor characteristic
- Stores the **latest value** for each sensor
- **Mutable** - updated when new events arrive
- Used for: querying current readings, monitoring, dashboards

## Data Flow Example

### Event Arrives:
```json
POST /api/homekit/events
{
  "type": "characteristic_updated",
  "accessory": "master bath sensor",
  "characteristic": "Current Temperature",
  "value": 23.5,
  "timestamp": "2026-01-26T16:00:00Z"
}
```

### What Happens:

**1. Create HomekitEvent (audit log)**
```ruby
HomekitEvent.create!(
  event_type: "characteristic_updated",
  accessory_name: "master bath sensor",
  characteristic: "Current Temperature",
  value: 23.5,
  timestamp: "2026-01-26T16:00:00Z",
  raw_payload: {full_json}
)
# HomekitEvent #3777 created
```

**2. Update Sensor (current state)**
```ruby
accessory = Accessory.find_by(name: "master bath sensor")
sensor = accessory.sensors.find_by(characteristic_type: "Current Temperature")

sensor.update!(
  current_value: 23.5,
  last_updated_at: "2026-01-26T16:00:00Z"
)
# Sensor #123 updated (was 22.1, now 23.5)
```

**3. (Optional) Create SensorReading (time-series history)**
```ruby
SensorReading.create!(
  sensor_id: sensor.id,
  value: 23.5,
  recorded_at: "2026-01-26T16:00:00Z"
)
# SensorReading #5432 created
```

## Comparison Table

| Aspect | HomekitEvent | Sensor | SensorReading (optional) |
|--------|-------------|--------|--------------------------|
| **Purpose** | Audit log of ALL events | Current sensor state | Historical sensor values |
| **Scope** | Every event from Prefab | One per sensor characteristic | Multiple per sensor |
| **Mutability** | Immutable (append-only) | Mutable (updated) | Immutable (append-only) |
| **Relationships** | None (standalone log) | belongs_to :accessory | belongs_to :sensor |
| **Data Stored** | All event types | Only sensor characteristics | Only sensor values |
| **Retention** | Keep all (or prune old) | Always just 1 record | Time-series data |
| **Use Cases** | Debugging, audit | "What is temp now?" | "Temp at 3pm?" "Average today?" |

## Example Queries

### HomekitEvent (Audit Trail)
```ruby
# All events from Master Bath sensor in last hour
HomekitEvent.where(
  accessory_name: 'master bath sensor',
  timestamp: 1.hour.ago..Time.now
)
# => [Event#3777, Event#3778, Event#3779...] (could be 100+ events)

# How many motion events today?
HomekitEvent.where(
  event_type: 'characteristic_updated',
  characteristic: 'Motion Detected',
  timestamp: Date.today.beginning_of_day..Time.now
).count
# => 347

# What was the last event received for any accessory?
HomekitEvent.order(timestamp: :desc).first
# => Shows most recent webhook event
```

### Sensor (Current State)
```ruby
# What is the temperature NOW?
room = Room.find_by(name: 'Master Bath')
sensor = room.sensors.temperature.first
sensor.typed_value
# => 23.5

# Which motion sensors are detecting motion RIGHT NOW?
Sensor.motion.where(current_value: '1')
# => [Sensor#45, Sensor#67, ...]

# When was Master Bath temperature last updated?
sensor.last_updated_at
# => 2026-01-26 16:00:00 UTC

# All sensors that haven't reported in 2 hours (offline?)
Sensor.event_capable.where('last_updated_at < ?', 2.hours.ago)
```

### SensorReading (Historical)
```ruby
# Temperature readings for last 24 hours
sensor = Sensor.find_by(accessory_id: 482, characteristic_type: 'Current Temperature')
sensor.sensor_readings.where(recorded_at: 24.hours.ago..Time.now)
# => [Reading#1, Reading#2, ...] (one per temp change)

# Average temperature today
sensor.sensor_readings
  .where(recorded_at: Date.today.beginning_of_day..Time.now)
  .average(:value)
# => 22.3

# Motion events per hour chart
sensor = Sensor.motion.first
sensor.sensor_readings
  .where(recorded_at: 24.hours.ago..Time.now, value: 1)
  .group_by_hour(:recorded_at)
  .count
# => {2026-01-26 14:00 => 5, 2026-01-26 15:00 => 8, ...}
```

## Should We Add a Foreign Key?

### Option A: No Direct Relationship (Recommended)
```ruby
class HomekitEvent < ApplicationRecord
  # No associations - it's a pure audit log
end

class Sensor < ApplicationRecord
  belongs_to :accessory
  # No link to HomekitEvent
end
```
**Pros:**
- Clean separation of concerns
- HomekitEvents can store ALL events (not just sensor updates)
- No referential integrity constraints
- Events can arrive before sensors exist

**Cons:**
- Can't directly query "which event updated this sensor?"

### Option B: Add Optional Reference
```ruby
class HomekitEvent < ApplicationRecord
  belongs_to :sensor, optional: true
  # sensor_id only populated for sensor events
end

class Sensor < ApplicationRecord
  has_many :homekit_events
end
```
**Pros:**
- Can query sensor.homekit_events for audit trail
- Direct link for debugging

**Cons:**
- More complex - need to find/create sensor before saving event
- Events like "homes_updated" won't have a sensor
- Adds coupling between models

## Recommended Architecture

```
HomekitEvent                    Sensor
├─ event_type                   ├─ current_value
├─ accessory_name               ├─ last_updated_at
├─ characteristic               └─ accessory_id
├─ value                               │
├─ timestamp                           │
└─ raw_payload                         ▼
                                   Accessory
                                   ├─ name
                                   ├─ room_id
                                   └─ raw_data

(No direct foreign key between HomekitEvent and Sensor)
```

**Link them via logic:**
```ruby
# Find all events for a sensor
sensor = Sensor.find(123)
accessory = sensor.accessory

HomekitEvent.where(
  accessory_name: accessory.name,
  characteristic: sensor.characteristic_type
)
```

## Updated Controller Logic

```ruby
class Api::HomekitEventsController < ApplicationController
  def create
    # 1. Always create event (audit log)
    event = HomekitEvent.create!(
      event_type: params[:type],
      accessory_name: params[:accessory],
      characteristic: params[:characteristic],
      value: params[:value],
      timestamp: params[:timestamp] || Time.current,
      raw_payload: request.body.read
    )

    # 2. If sensor event, update sensor
    if params[:type] == 'characteristic_updated' && params[:accessory].present?
      update_sensor(event)
    end

    head :ok
  end

  private

  def update_sensor(event)
    accessory = Accessory.find_by(name: event.accessory_name)
    return unless accessory

    sensor = accessory.sensors.find_by(characteristic_type: event.characteristic)
    return unless sensor

    sensor.update_from_event!(event.value, event.timestamp)

    # Optional: Create historical reading
    # SensorReading.create!(sensor: sensor, value: event.value, recorded_at: event.timestamp)
  end
end
```

## Summary

**HomekitEvent = What happened?** (audit log, debugging)
- "At 4:15pm, master bath sensor reported temp 23.5°C"
- "At 4:16pm, master bath sensor reported temp 23.6°C"
- "At 4:17pm, master bath sensor reported temp 23.5°C"

**Sensor = What is the current state?** (real-time monitoring)
- "Master bath temperature is currently 23.5°C (as of 4:17pm)"

**SensorReading = What was the state over time?** (analytics)
- "Master bath temperature was 23.5°C at 4:15pm, 23.6°C at 4:16pm, 23.5°C at 4:17pm"

They work together but serve different purposes!
