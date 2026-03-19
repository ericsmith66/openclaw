require 'net/http'
require 'json'
require 'uri'

# Ensure we have a room and home for the accessory
home = Home.find_or_create_by!(name: "Default Home", uuid: "default-home")
room = Room.find_or_create_by!(name: "Default Room", uuid: "default-room", home: home)

# Create a mock accessory if it doesn't exist
Accessory.find_or_create_by!(name: "iHome SmartMonitor-A28C90", uuid: "test-uuid-A28C90") do |acc|
  acc.raw_data = {
    'services' => [
      {
        'typeName' => "Sensor",
        'uniqueIdentifier' => "svc-uuid",
        'characteristics' => [
          {
            'typeName' => "Custom",
            'uniqueIdentifier' => "EF439D79-D005-53B7-81B8-1A4BB2CFD434",
            'description' => "Custom",
            'properties' => [ "HMCharacteristicPropertySupportsEventNotification" ]
          }
        ]
      }
    ]
  }
  acc.room = room
end

payload = {
  type: "characteristic_updated",
  accessory: "iHome SmartMonitor-A28C90",
  value: true,
  timestamp: Time.current.iso8601,
  characteristic: "Custom"
}

# We use the internal controller logic to test without running a full server
controller = Api::HomekitEventsController.new

# Mock request and related methods
class MockRequest
  def headers
    { 'Authorization' => 'Bearer ' + Rails.application.credentials.prefab_webhook_token }
  end
  def body
    StringIO.new({}.to_json)
  end
  def read
    ""
  end
end

controller.instance_variable_set(:@_request, MockRequest.new)
controller.params = ActionController::Parameters.new(payload)

# Mock create_event to avoid errors with request.body.read
def controller.create_event(timestamp, sensor = nil)
  HomekitEvent.create!(
    event_type: params[:type],
    accessory_name: params[:accessory],
    characteristic: params[:characteristic],
    value: params[:value],
    timestamp: timestamp,
    sensor: sensor,
    accessory: sensor&.accessory || Accessory.find_by(name: params[:accessory])
  )
end

begin
  # handle_sensor_event is private
  controller.send(:handle_sensor_event, Time.current)
  puts "SUCCESS: handle_sensor_event executed without error"
rescue => e
  puts "FAILED: #{e.message}"
  puts e.backtrace.first(10)
end
