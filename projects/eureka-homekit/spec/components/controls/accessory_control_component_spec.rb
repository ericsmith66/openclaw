# frozen_string_literal: true

require "rails_helper"

RSpec.describe Controls::AccessoryControlComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-123", home: home) }

  describe "type detection" do
    it "detects switch type (On only)" do
      acc = Accessory.create!(name: "Switch", uuid: "sw-1", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "On", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "Switch")

      component = described_class.new(accessory: acc)
      expect(component.send(:accessory_type)).to eq(:switch)
    end

    it "detects light type (On + Brightness)" do
      acc = Accessory.create!(name: "Light", uuid: "lt-1", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "On", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "Lightbulb")
      Sensor.create!(accessory: acc, characteristic_type: "Brightness", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-2", service_type: "Lightbulb")

      component = described_class.new(accessory: acc)
      expect(component.send(:accessory_type)).to eq(:light)
    end

    it "detects thermostat type (Target Temperature)" do
      acc = Accessory.create!(name: "Therm", uuid: "th-1", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "Target Temperature", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "Thermostat")

      component = described_class.new(accessory: acc)
      expect(component.send(:accessory_type)).to eq(:thermostat)
    end

    it "detects lock type (Lock Current State)" do
      acc = Accessory.create!(name: "Lock", uuid: "lk-1", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "Lock Current State",
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "LockMechanism")

      component = described_class.new(accessory: acc)
      expect(component.send(:accessory_type)).to eq(:lock)
    end

    it "detects fan type (Rotation Speed + Active)" do
      acc = Accessory.create!(name: "Fan", uuid: "fn-1", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "Active", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "Fan")
      Sensor.create!(accessory: acc, characteristic_type: "Rotation Speed", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-2", service_type: "Fan")

      component = described_class.new(accessory: acc)
      expect(component.send(:accessory_type)).to eq(:fan)
    end

    it "detects outlet type (On + Outlet In Use)" do
      acc = Accessory.create!(name: "Outlet", uuid: "ol-1", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "On", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "Outlet")
      Sensor.create!(accessory: acc, characteristic_type: "Outlet In Use",
                     service_uuid: "svc-1", characteristic_uuid: "char-2", service_type: "Outlet")

      component = described_class.new(accessory: acc)
      expect(component.send(:accessory_type)).to eq(:outlet)
    end

    it "detects garage_door type (Current Door State)" do
      acc = Accessory.create!(name: "Garage", uuid: "gd-1", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "Current Door State",
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "GarageDoorOpener")

      component = described_class.new(accessory: acc)
      expect(component.send(:accessory_type)).to eq(:garage_door)
    end

    it "detects blind type (Target Position without Active)" do
      acc = Accessory.create!(name: "Blind", uuid: "bl-1", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "Target Position", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "WindowCovering")

      component = described_class.new(accessory: acc)
      expect(component.send(:accessory_type)).to eq(:blind)
    end

    it "returns nil for accessory with no sensors" do
      acc = Accessory.create!(name: "Empty", uuid: "em-1", room: room)

      component = described_class.new(accessory: acc)
      expect(component.send(:accessory_type)).to be_nil
    end
  end

  describe "rendering" do
    it "renders the star button by default" do
      acc = Accessory.create!(name: "Switch", uuid: "sw-2", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "On", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "Switch")

      render_inline(described_class.new(accessory: acc))

      expect(rendered_content).to include('data-favorites-target="star"')
      expect(rendered_content).to include("sw-2")
    end

    it "hides the star button when show_favorite is false" do
      acc = Accessory.create!(name: "Switch", uuid: "sw-3", room: room, last_seen_at: 5.minutes.ago)
      Sensor.create!(accessory: acc, characteristic_type: "On", is_writable: true,
                     service_uuid: "svc-1", characteristic_uuid: "char-1", service_type: "Switch")

      render_inline(described_class.new(accessory: acc, show_favorite: false))

      expect(rendered_content).not_to include('data-favorites-target="star"')
    end

    it "does not render for accessory with no detectable type" do
      acc = Accessory.create!(name: "Empty", uuid: "em-2", room: room)

      render_inline(described_class.new(accessory: acc))

      expect(rendered_content.strip).to be_empty
    end
  end
end
