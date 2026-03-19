module Api
  class HomekitEventsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_webhook

    # Deduplication settings
    DEDUPE_WINDOW = 5.minutes
    HEARTBEAT_INTERVAL = 15.minutes
    RAPID_DEDUPE_WINDOW = 1.second

    # Instrumentation for metrics
    def instrument_deduplication(reason, sensor, new_value, extra = {})
      payload = {
        sensor_id: sensor&.id,
        reason: reason,
        value: new_value
      }.merge(extra)
      ActiveSupport::Notifications.instrument("homekit_events.deduplicated", payload)
    end

    def instrument_stored(sensor, new_value, old_value, reason)
      ActiveSupport::Notifications.instrument("homekit_events.stored", {
        sensor_id: sensor&.id,
        reason: reason,
        old_value: old_value,
        new_value: new_value
      })
    end

    def create
      timestamp = params[:timestamp] ? Time.parse(params[:timestamp]) : Time.current

      ActiveSupport::Notifications.instrument("homekit_events.received", { type: params[:type], accessory: params[:accessory], characteristic: params[:characteristic] }) do
        # Handle sensor events (characteristic_updated)
        if params[:type] == "characteristic_updated" && params[:accessory].present?
          handle_sensor_event(timestamp)
        else
          # Non-sensor events (homes_updated, etc.) - always store
          create_event(timestamp)
          Rails.logger.info("HomeKit event received: #{params[:type]}")
        end
      end

      head :ok
    rescue StandardError => e
      Rails.logger.error("Failed to process HomeKit event: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: "Bad request" }, status: :bad_request
    end

    private

    def handle_sensor_event(timestamp)
      sensor = find_sensor || create_sensor_from_params(timestamp)

      if sensor
        sensor.with_lock do
          process_sensor_event_with_lock(sensor, timestamp)
        end
      else
        # No sensor could be created; store event without sensor association
        event = create_event(timestamp)
        Rails.logger.info("HomeKit event received: #{params[:type]} - #{params[:accessory]}")
        Rails.logger.info("HomeKit event stored (no sensor): #{params[:accessory]} - #{params[:characteristic]} = #{params[:value]}")
        broadcast_event(event)
      end
    end

    def process_sensor_event_with_lock(sensor, timestamp)
      should_store = should_store_event?(sensor, params[:value], timestamp)

      if should_store
        event = create_event(timestamp, sensor)
        broadcast_event(event)
        Rails.logger.info("HomeKit event received: #{params[:type]} - #{params[:accessory]}")
        Rails.logger.info("HomeKit event stored: #{params[:accessory]} - #{params[:characteristic]} = #{params[:value]}")

        # Update sensor state (value changed) including last_event_stored_at
        sensor.update_columns(
          current_value: params[:value],
          last_updated_at: timestamp,
          last_event_stored_at: timestamp
        )
        sensor.update_liveness!(params[:value], timestamp)
      else
        # Always update liveness (even if value is duplicate)
        sensor.update_liveness!(params[:value], timestamp)

        # Broadcast liveness update even if no event is created (throttled)
        broadcast_room_update(sensor.room, timestamp) if sensor.room
      end
    end

    def find_sensor
      accessory = Accessory.find_by(name: params[:accessory])
      return nil unless accessory

      # Try exact match first (characteristic_type)
      sensor = accessory.sensors.find_by(characteristic_type: params[:characteristic])
      return sensor if sensor

      # Fall back to checking if characteristic matches description in raw_data
      accessory.raw_data["services"]&.each do |service|
        service["characteristics"]&.each do |char|
          if char["description"] == params[:characteristic] || char["localizedDescription"] == params[:characteristic]
            # Find sensor by the characteristic's actual uniqueIdentifier
            return accessory.sensors.find_by(characteristic_uuid: char["uniqueIdentifier"])
          end
        end
      end

      nil
    end

    def create_sensor_from_params(timestamp)
      accessory = Accessory.find_by(name: params[:accessory])
      return nil unless accessory
      return nil unless accessory.raw_data["services"]

      sensor_types = [
        "Current Temperature", "Motion Detected", "Current Relative Humidity",
        "Battery Level", "Current Ambient Light Level", "Contact Sensor State",
        "Occupancy Detected", "Status Low Battery", "Lock Current State",
        "On", "Brightness", "Hue", "Saturation", "Active", "Rotation Speed",
        "Rotation Direction", "Swing Mode", "Target Position", "Current Position",
        "Target Horizontal Tilt Angle", "Current Horizontal Tilt Angle",
        "Obstruction Detected", "Current Door State", "Target Door State",
        "Lock Target State", "Target Temperature", "Current Heating Cooling State",
        "Target Heating Cooling State", "Outlet In Use"
      ]

      accessory.raw_data["services"].each do |svc|
        svc["characteristics"]&.each do |char|
          if char["typeName"] == params[:characteristic] ||
             char["description"] == params[:characteristic] ||
             char["localizedDescription"] == params[:characteristic]

            next unless sensor_types.include?(char["typeName"])

            # Use find_or_create_by! to prevent race conditions
            begin
              return Sensor.find_or_create_by!(
                accessory: accessory,
                characteristic_uuid: char["uniqueIdentifier"]
              ) do |sensor|
                sensor.service_uuid = svc["uniqueIdentifier"]
                sensor.service_type = svc["typeName"]
                sensor.characteristic_type = char["typeName"]
                sensor.current_value = params[:value]
                sensor.last_updated_at = timestamp
                sensor.last_event_stored_at = timestamp
                sensor.value_format = char.dig("metadata", "format")
                sensor.supports_events = char["properties"]&.include?("HMCharacteristicPropertySupportsEventNotification")
                sensor.is_writable = char["properties"]&.include?("HMCharacteristicPropertyWritable")
              end
            rescue ActiveRecord::RecordNotUnique
              # Race condition - sensor was created by another concurrent request
              # Retry the find operation once
              Rails.logger.info("[SensorCreation] Race condition detected for #{char['uniqueIdentifier']}, retrying find")
              return accessory.sensors.find_by(characteristic_uuid: char["uniqueIdentifier"])
            end
          end
        end
      end
      nil
    end

    def should_store_event?(sensor, new_value, timestamp)
      if sensor.nil?
        instrument_stored(sensor, new_value, nil, "no_sensor")
        return true
      end

      if sensor.current_value.nil?
        instrument_stored(sensor, new_value, nil, "first_value")
        return true
      end

      # Check 1: Heartbeat storage - always store if heartbeat interval has passed
      if sensor.last_event_stored_at && sensor.last_event_stored_at < timestamp - HEARTBEAT_INTERVAL
        Rails.logger.info("[EventDedup] Heartbeat due: sensor_id=#{sensor.id}, last_stored=#{sensor.last_event_stored_at}, reason=heartbeat_due")
        instrument_stored(sensor, new_value, sensor.current_value, "heartbeat_due")
        return true
      end

      # If no last_event_stored_at (legacy data or new sensor), treat as first event
      if sensor.last_event_stored_at.nil?
        Rails.logger.info("[EventDedup] First event for sensor_id=#{sensor.id}, reason=no_history")
        instrument_stored(sensor, new_value, sensor.current_value, "no_history")
        return true
      end

      # Check 2: Typed value comparison using compare_values
      values_match = sensor.compare_values(sensor.current_value, new_value)

      if values_match
        # Check 3: Time-based deduplication window
        if sensor.last_event_stored_at > timestamp - RAPID_DEDUPE_WINDOW
          time_since_last = timestamp - sensor.last_event_stored_at
          Rails.logger.info("[EventDedup] Event skipped: sensor_id=#{sensor.id}, value=#{new_value}, reason=time_window, time_since_last=#{(time_since_last * 1000).round}ms")
          instrument_deduplication("time_window", sensor, new_value, time_since_last: time_since_last)
          return false
        end

        # Values match and we're outside the rapid dedupe window, but it's still a duplicate.
        # We only store it if heartbeat is due (already checked above) or if it's NOT a duplicate.
        # So for a duplicate outside the rapid window, we return false.

        Rails.logger.info("[EventDedup] Duplicate value skipped: sensor_id=#{sensor.id}, value=#{new_value}, reason=duplicate")
        instrument_deduplication("duplicate", sensor, new_value)
        return false
      end

      # Check 4: Value changed - store the event
      unless values_match
        # Check 5: ECHO PREVENTION - Check for recent outbound control within 5 seconds
        accessory = sensor.accessory
        if accessory
          recent_control = ControlEvent.where(
            accessory_id: accessory.id,
            characteristic_name: sensor.characteristic_type,
            new_value: new_value.to_s,
            success: true
          ).where("created_at >= ?", timestamp - 5.seconds).exists?

          if recent_control
            Rails.logger.info("[EventDedup] Event skipped: sensor_id=#{sensor.id}, value=#{new_value}, reason=echo_prevention")
            instrument_deduplication("echo_prevention", sensor, new_value)
            return false
          end
        end

        Rails.logger.info("[EventDedup] Event stored: sensor_id=#{sensor.id}, old_value=#{sensor.current_value}, new_value=#{new_value}, reason=value_changed")
        instrument_stored(sensor, new_value, sensor.current_value, "value_changed")
        return true
      end

      # Fallback - should not be reached
      false
    end

    def create_event(timestamp, sensor = nil)
      HomekitEvent.create!(
        event_type: params[:type],
        accessory_name: params[:accessory],
        characteristic: params[:characteristic],
        value: params[:value],
        raw_payload: request.body.read,
        timestamp: timestamp,
        sensor: sensor,
        accessory: sensor&.accessory || Accessory.find_by(name: params[:accessory])
      )
    end

    def broadcast_event(event)
      return unless event

      begin
        table_html = ApplicationController.render(
          Events::RowComponent.new(event: event),
          layout: false
        )

        sidebar_html = ApplicationController.render(
          Events::RecentEventsItemComponent.new(event: event),
          layout: false
        )

        ::ActionCable.server.broadcast("events", {
          id: event.id,
          table_html: table_html,
          sidebar_html: sidebar_html,
          event_type: event.event_type,
          accessory_name: event.accessory_name,
          room_id: event.room&.id,
          home_id: event.home&.id,
          sensor_id: event.sensor&.id
        })

        # Also broadcast room activity update if applicable
        if event.room
          broadcast_room_update(event.room, event.timestamp)
        end
      rescue StandardError => e
        Rails.logger.error("Failed to broadcast event: #{e.message}")
      end
    end

    def broadcast_room_update(room, timestamp)
      # Throttle broadcasts per room using atomic cache operations
      cache_key = "room_broadcast_throttle:#{room.id}"

      # Check if cache already exists (throttled)
      if Rails.cache.exist?(cache_key)
        ActiveSupport::Notifications.instrument("room_broadcasts.throttled", { room_id: room.id })
        return
      end

      # fetch with race_condition_ttl ensures only one broadcast per time window
      # The block executes only when cache is missing (first event in window)
      Rails.cache.fetch(cache_key, expires_in: 0.5.seconds, race_condition_ttl: 0.1.seconds) do
        begin
          # Existing sidebar/list update
          ::ActionCable.server.broadcast("room_activity", {
            room_id: room.id,
            last_event_at: timestamp,
            color_class: helpers.room_activity_color(room),
            text_color_class: helpers.room_activity_text_color(room)
          })

          # Floorplan specific update
          ::ActionCable.server.broadcast("floorplan_updates", {
            room_id: room.id,
            room_name: room.name,
            heatmap_class: helpers.room_heatmap_class(room),
            sensor_states: FloorplanMappingService.new(nil).send(:extract_sensor_states, room)
          })

          ActiveSupport::Notifications.instrument("room_broadcasts.broadcasted", { room_id: room.id })
        rescue StandardError => e
          Rails.logger.warn("[BroadcastThrottle] Failed for room_id=#{room.id}: #{e.message}")
          Rails.logger.warn(e.backtrace.join("\n"))
          # Fail-open: don't re-raise, allow webhook to succeed
        end

        # Return value to store in cache (any non-nil value)
        true
      end
    end

    def authenticate_webhook
      token = request.headers["Authorization"]&.remove("Bearer ")
      expected_token = Rails.application.credentials.prefab_webhook_token

      unless token == expected_token
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
