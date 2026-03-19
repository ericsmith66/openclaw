# frozen_string_literal: true

require "rails_helper"

RSpec.describe Events::RecentEventsItemComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-123", home: home) }
  let(:accessory) { Accessory.create!(name: "Test Accessory", uuid: "acc-123", room: room) }
  let(:event) do
    HomekitEvent.create!(
      accessory: accessory,
      characteristic: "Current Temperature",
      value: "20.0",
      event_type: "characteristic_updated",
      timestamp: Time.current
    )
  end

  it "renders the summary and accessory name" do
    render_inline(described_class.new(event: event))

    expect(rendered_content).to include("Temperature: 68.0°F")
    expect(rendered_content).to include("Test Accessory")
    expect(rendered_content).to include("Test Room")
  end

  it "renders the count badge when count > 1" do
    render_inline(described_class.new(event: event, count: 5))
    expect(rendered_content).to include("×5")
  end

  it "renders the correct icon for temperature" do
    render_inline(described_class.new(event: event))
    # lucide_icon renders the SVG directly. We can check for a path characteristic of thermometer.
    # From the diff: <path d="M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z"></path>
    expect(rendered_content).to include("M14 4v10.54a4 4 0 1 1-4 0V4a2 2 0 0 1 4 0Z")
  end

  it "renders the correct summary for humidity" do
    event.update!(characteristic: "Current Relative Humidity", value: "45.0")
    render_inline(described_class.new(event: event))
    expect(rendered_content).to include("Humidity: 45%")
  end
end
