class AccessoriesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :control, :batch_control ]

  rate_limit to: 10, within: 1.second, only: [ :control, :batch_control ],
             with: -> { render json: { success: false, error: "Rate limit exceeded. Please try again." }, status: :too_many_requests }

  before_action :set_accessory, only: :control

  def batch_control
    unless params[:accessory_ids].is_a?(Array) && params[:accessory_ids].present?
      return render json: { success: false, error: "Missing required parameter: accessory_ids" }, status: :bad_request
    end

    unless params[:action_type].present?
      return render json: { success: false, error: "Missing required parameter: action_type" }, status: :bad_request
    end

    characteristic, value = resolve_batch_action(params[:action_type], params[:value])
    unless characteristic
      return render json: { success: false, error: "Unknown action_type: #{params[:action_type]}" }, status: :bad_request
    end

    accessories = Accessory.where(uuid: params[:accessory_ids]).includes(:sensors, room: :home)
    results = []

    accessories.each do |accessory|
      sensor = accessory.sensors.find_by(characteristic_type: characteristic, is_writable: true)
      unless sensor
        results << { accessory_id: accessory.uuid, name: accessory.name, success: false, error: "Characteristic not writable" }
        next
      end

      coerced = coerce_value(value, characteristic)
      result = PrefabControlService.set_characteristic(
        accessory: accessory,
        characteristic: characteristic,
        value: coerced,
        user_ip: request.remote_ip,
        source: "web-batch"
      )

      results << {
        accessory_id: accessory.uuid,
        name: accessory.name,
        success: result[:success],
        error: result[:error]
      }
    end

    render json: {
      success: true,
      total: results.size,
      succeeded: results.count { |r| r[:success] },
      failed: results.count { |r| !r[:success] },
      results: results
    }
  end

  def control
    # Validate required parameters
    # Note: Cannot use .present? for :value because it returns false for false/0/"0"/""
    # which are valid control values (e.g., turning off a switch, closing a shade)
    unless params[:characteristic].present? && !params[:value].nil?
      return render json: { success: false, error: "Missing required parameters: characteristic and value" }, status: :bad_request
    end

    # Validate accessory is controllable
    unless @accessory.sensors.where(is_writable: true).exists?
      return render json: { success: false, error: "Accessory is not controllable" }, status: :forbidden
    end

    # Validate characteristic is writable
    unless @accessory.sensors.where(characteristic_type: params[:characteristic], is_writable: true).exists?
      return render json: { success: false, error: "Characteristic #{params[:characteristic]} is not writable" }, status: :forbidden
    end

    # Parse and coerce value
    value = coerce_value(params[:value], params[:characteristic])

    # Execute control with retry and audit
    result = PrefabControlService.set_characteristic(
      accessory: @accessory,
      characteristic: params[:characteristic],
      value: value,
      user_ip: request.remote_ip,
      source: "web"
    )

    if result[:success]
      render json: { success: true, value: value }
    else
      render json: { success: false, error: result[:error] }, status: :internal_server_error
    end
  end

  private

  def set_accessory
    @accessory = Accessory.find_by!(uuid: params[:accessory_id])
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: "Accessory not found" }, status: :not_found
  end

  def resolve_batch_action(action_type, value)
    case action_type
    when "turn_on"
      [ "On", true ]
    when "turn_off"
      [ "On", false ]
    when "set_brightness"
      [ "Brightness", value ]
    when "set_temperature"
      [ "Target Temperature", value ]
    else
      [ nil, nil ]
    end
  end

  def coerce_value(value, characteristic)
    case characteristic
    when "On"
      # Boolean coercion for On/Off
      case value.to_s.downcase
      when "1", "true", "on", "yes"
        true
      when "0", "false", "off", "no"
        false
      else
        value
      end
    when "Active"
      # Fan active state (0=inactive, 1=active)
      value.to_i
    when "Brightness"
      # Coerce brightness to integer 0-100
      val = value.to_i
      [ 0, [ val, 100 ].min ].max
    when "Hue", "Saturation"
      # Coerce to integer
      value.to_i
    when "Rotation Speed"
      # Fan speed 0-100
      val = value.to_i
      [ 0, [ val, 100 ].min ].max
    when "Rotation Direction"
      # Fan direction (0=clockwise, 1=counterclockwise)
      value.to_i
    when "Swing Mode"
      # Fan oscillation (0=disabled, 1=enabled)
      value.to_i
    when "Target Position"
      # Blind position 0-100 (0=closed, 100=open)
      val = value.to_i
      [ 0, [ val, 100 ].min ].max
    when "Target Horizontal Tilt Angle", "Target Vertical Tilt Angle"
      # Blind tilt angle -90 to 90 degrees
      val = value.to_i
      [ -90, [ val, 90 ].min ].max
    when "Target Door State"
      # Garage door target state (0=open, 1=closed)
      value.to_i
    when "Target Temperature"
      # Coerce temperature to float (°C internally)
      # Handle both °C and °F input (displayed value)
      value.to_f
    when "Target Heating/Cooling State", "Temperature Display Units"
      # Coerce mode/unit to integer
      value.to_i
    when "Lock Target State"
      # Coerce lock target state to integer (0=unsecured, 1=secured)
      value.to_i
    else
      value
    end
  end
end
