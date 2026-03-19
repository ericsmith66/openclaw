# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sensors", type: :request do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-123", home: home) }
  let(:accessory) { Accessory.create!(name: "Test Accessory", uuid: "acc-123", room: room) }
  let!(:sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_type: "Current Temperature",
      current_value: "22.5",
      service_uuid: "svc-123",
      characteristic_uuid: "char-123",
      service_type: "TemperatureSensor",
      last_updated_at: Time.current
    )
  end

  describe "GET /sensors" do
    it "renders the sensors index" do
      get sensors_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sensors Dashboard")
      expect(response.body).to include("Test Accessory")
    end

    it "filters by type" do
      get sensors_path(type: "Motion Detected")
      expect(response.body).not_to include("id=\"sensor-#{sensor.id}\"")
    end
  end

  describe "GET /sensors/:id" do
    it "renders the sensor show page" do
      get sensor_path(sensor)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Test Accessory")
      expect(response.body).to include("Current Temperature")
      expect(response.body).to include("Device Metadata")
    end
  end
end
