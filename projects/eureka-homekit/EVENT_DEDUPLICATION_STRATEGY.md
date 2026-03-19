# Event Deduplication Strategy

## Problem
HomeKit events are very chatty - sending duplicate values frequently:
- 60%+ of consecutive events have same value
- 73 motion events/hour from sensors that barely change
- Humidity sensor reports same "34%" value multiple times in a row

## Data from Live System
```
15:58:11 - Humidity: 34  ← duplicate
15:58:36 - Humidity: 34  ← duplicate
15:58:38 - Humidity: 34  ← duplicate
16:00:33 - Humidity: 34  ← duplicate
16:18:32 - Humidity: 34  ← duplicate
17:02:20 - Humidity: 34  ← duplicate
17:09:22 - Humidity: 33  ← CHANGED!
```

## Solutions

### Option 1: Skip Duplicate Events (Recommended)
Only create HomekitEvent if value changed OR significant time passed

```ruby
class Api::HomekitEventsController < ApplicationController
  def create
    # Find existing sensor to check for duplicates
    accessory = Accessory.find_by(name: params[:accessory])
    sensor = accessory&.sensors&.find_by(characteristic_type: params[:characteristic])

    # Skip if duplicate value within last 5 minutes
    if sensor && should_skip_duplicate?(sensor, params[:value], params[:timestamp])
      head :ok # Acknowledge but don't store
      return
    end

    # Create event and update sensor
    event = HomekitEvent.create!(...)
    sensor&.update_from_event!(params[:value], params[:timestamp])

    head :ok
  end

  private

  def should_skip_duplicate?(sensor, new_value, timestamp)
    # Don't skip if no previous value
    return false if sensor.current_value.nil?

    # Don't skip if value changed
    return false if sensor.current_value.to_s != new_value.to_s

    # Skip if duplicate within 5 minutes
    sensor.last_updated_at && sensor.last_updated_at > 5.minutes.ago
  end
end
```

**Pros:**
- Reduces DB writes by 60%+
- Keeps DB smaller
- Still captures all meaningful changes

**Cons:**
- Loses exact timing of duplicate events
- Can't audit "Prefab sent 10 events"

### Option 2: Deduplicate + Heartbeat
Skip duplicates but allow periodic heartbeats

```ruby
def should_skip_duplicate?(sensor, new_value, timestamp)
  return false if sensor.current_value.nil?
  return false if sensor.current_value.to_s != new_value.to_s

  # Allow heartbeat every 15 minutes even if value unchanged
  return false if sensor.last_updated_at.nil? || sensor.last_updated_at < 15.minutes.ago

  true # Skip duplicate
end
```

**Pros:**
- Confirms sensor is still alive/responsive
- Reduces events by ~50% instead of 60%
- Good for monitoring offline sensors

**Cons:**
- Still stores some duplicates

### Option 3: Store All Events, Query Smart
Keep all events but add `value_changed` flag

```ruby
# Migration
add_column :homekit_events, :value_changed, :boolean, default: true

# Controller
def create
  previous_event = HomekitEvent.where(
    accessory_name: params[:accessory],
    characteristic: params[:characteristic]
  ).order(timestamp: :desc).first

  value_changed = previous_event.nil? || previous_event.value != params[:value]

  event = HomekitEvent.create!(
    ...,
    value_changed: value_changed
  )
end

# Query only meaningful events
HomekitEvent.where(value_changed: true)
```

**Pros:**
- Complete audit trail
- Can analyze chattiness later
- No data loss

**Cons:**
- Database grows fast
- More writes

### Option 4: Batch/Aggregate Events
Aggregate duplicate events into counts

```ruby
# New table
create_table :event_aggregates do |t|
  t.string :accessory_name
  t.string :characteristic
  t.jsonb :value
  t.integer :count, default: 1
  t.datetime :first_seen_at
  t.datetime :last_seen_at
  t.timestamps
end

# Store only unique (value, accessory, characteristic) combinations
# Increment count for duplicates
```

**Pros:**
- Extremely compact
- Shows "sensor reported 34% ten times in 5 minutes"

**Cons:**
- Complex to implement
- Loses individual timestamps

## Recommended Approach

**Hybrid: Option 1 + Option 2**

```ruby
class Api::HomekitEventsController < ApplicationController
  DEDUPE_WINDOW = 5.minutes
  HEARTBEAT_INTERVAL = 15.minutes

  def create
    # Always update sensor first (even if we skip event)
    sensor = find_or_create_sensor(params)

    # Decide whether to store event
    should_store = should_store_event?(sensor, params[:value], params[:timestamp])

    if should_store
      HomekitEvent.create!(
        event_type: params[:type],
        accessory_name: params[:accessory],
        characteristic: params[:characteristic],
        value: params[:value],
        timestamp: params[:timestamp] || Time.current,
        raw_payload: request.body.read
      )
    end

    # Always update sensor (keeps current state accurate)
    sensor.update_from_event!(params[:value], params[:timestamp]) if sensor

    head :ok
  end

  private

  def should_store_event?(sensor, new_value, timestamp)
    return true if sensor.nil? # Always store if no sensor yet
    return true if sensor.current_value.nil? # Always store first value
    return true if sensor.current_value.to_s != new_value.to_s # Value changed

    # Allow heartbeat every 15 minutes
    return true if sensor.last_updated_at.nil? || sensor.last_updated_at < HEARTBEAT_INTERVAL.ago

    # Skip duplicate within 5 minutes
    false
  end
end
```

**Result:**
- **60% fewer events** stored in database
- **Sensor always has current value** (updated regardless)
- **Heartbeat every 15 min** confirms sensor is alive
- **No data loss** on actual changes

## Alternative: Add Deduplication Flag

If you want to keep all events but mark them:

```ruby
# Migration
add_column :homekit_events, :is_duplicate, :boolean, default: false
add_index :homekit_events, :is_duplicate

# Controller marks duplicates
event = HomekitEvent.create!(
  ...,
  is_duplicate: is_duplicate_event?(params)
)

# Query only meaningful events
HomekitEvent.where(is_duplicate: false)
HomekitEvent.where(is_duplicate: true) # For debugging/analysis
```

## Impact Estimation

Based on your live data:
- **Current**: 73 motion events/hour = ~1,750/day = ~640K/year per sensor
- **With deduplication**: ~700 events/day = ~255K/year per sensor
- **With 50 sensors**: Saves ~19M events/year
- **Storage savings**: ~5-10GB/year (with JSON payloads)

## Recommendation

Start with **Option 1 + Option 2 (Hybrid)**:
1. Skip duplicate events within 5 minutes
2. Allow heartbeat every 15 minutes
3. Always update sensor.current_value
4. Add logging to track how many events are skipped

This gives you:
- ✅ Clean event log (only changes + heartbeats)
- ✅ Accurate sensor state (always updated)
- ✅ Offline detection (15-min heartbeat)
- ✅ 50-60% reduction in DB writes
- ✅ No loss of important data

You can always change strategy later since Sensor state is updated independently of event storage.
