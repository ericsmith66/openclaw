# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sensors::CardComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-123", home: home) }
  let(:accessory) { Accessory.create!(name: "Test Accessory", uuid: "acc-123", room: room) }
  let(:sensor) do
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

  it "renders the accessory name and characteristic type" do
    render_inline(described_class.new(sensor: sensor))

    expect(rendered_content).to include("Test Accessory")
    expect(rendered_content).to include("Current Temperature")
  end

  it "renders the current value in Fahrenheit" do
    render_inline(described_class.new(sensor: sensor))

    # 22.5C converted to F is 72.5
    expect(rendered_content).to include("72.5")
    expect(rendered_content).to include("°F")
  end

  it "renders the correct status badge" do
    render_inline(described_class.new(sensor: sensor))
    expect(rendered_content).to include("Online") # online

    sensor.update!(last_updated_at: 25.hours.ago)
    render_inline(described_class.new(sensor: sensor))
    expect(rendered_content).to include("Offline")
  end
end
