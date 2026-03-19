# frozen_string_literal: true

require "rails_helper"

RSpec.describe Controls::BatchControlComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-123", home: home) }

  let(:light) do
    acc = Accessory.create!(name: "Light 1", uuid: "light-1", room: room, last_seen_at: 5.minutes.ago)
    Sensor.create!(accessory: acc, characteristic_type: "On", is_writable: true,
                   service_uuid: "svc-1", characteristic_uuid: "char-on-1", service_type: "Lightbulb")
    Sensor.create!(accessory: acc, characteristic_type: "Brightness", is_writable: true,
                   service_uuid: "svc-1", characteristic_uuid: "char-bri-1", service_type: "Lightbulb")
    acc
  end

  let(:switch_acc) do
    acc = Accessory.create!(name: "Switch 1", uuid: "switch-1", room: room, last_seen_at: 5.minutes.ago)
    Sensor.create!(accessory: acc, characteristic_type: "On", is_writable: true,
                   service_uuid: "svc-2", characteristic_uuid: "char-on-2", service_type: "Switch")
    acc
  end

  let(:thermostat) do
    acc = Accessory.create!(name: "Thermostat 1", uuid: "therm-1", room: room, last_seen_at: 5.minutes.ago)
    Sensor.create!(accessory: acc, characteristic_type: "Target Temperature", is_writable: true,
                   service_uuid: "svc-3", characteristic_uuid: "char-temp-1", service_type: "Thermostat")
    acc
  end

  describe "rendering" do
    context "with multiple controllable accessories" do
      it "renders the batch control panel" do
        render_inline(described_class.new(accessories: [ light, switch_acc ]))

        expect(rendered_content).to include("Batch Controls")
        expect(rendered_content).to include("Select All")
        expect(rendered_content).to include("Deselect All")
        expect(rendered_content).to include("Turn On")
        expect(rendered_content).to include("Turn Off")
      end

      it "renders a checkbox for each controllable accessory" do
        render_inline(described_class.new(accessories: [ light, switch_acc ]))

        expect(rendered_content).to include("Light 1")
        expect(rendered_content).to include("Switch 1")
        expect(rendered_content).to include('value="light-1"')
        expect(rendered_content).to include('value="switch-1"')
      end

      it "includes Stimulus controller attributes" do
        render_inline(described_class.new(accessories: [ light, switch_acc ]))

        expect(rendered_content).to include('data-controller="batch-control"')
        expect(rendered_content).to include('data-batch-control-target="checkbox"')
        expect(rendered_content).to include('data-batch-control-target="toolbar"')
      end
    end

    context "with brightness-capable accessories" do
      it "renders brightness slider" do
        render_inline(described_class.new(accessories: [ light, switch_acc ]))

        expect(rendered_content).to include("Set Brightness")
        expect(rendered_content).to include('data-batch-control-target="brightnessSlider"')
      end
    end

    context "with temperature-capable accessories" do
      it "renders temperature input" do
        render_inline(described_class.new(accessories: [ light, thermostat ]))

        expect(rendered_content).to include("Set Temp")
        expect(rendered_content).to include('data-batch-control-target="temperatureInput"')
      end
    end

    context "with only one controllable accessory" do
      it "does not render the batch control panel" do
        render_inline(described_class.new(accessories: [ light ]))

        expect(rendered_content).to be_blank
      end
    end

    context "with no accessories" do
      it "does not render" do
        render_inline(described_class.new(accessories: []))

        expect(rendered_content).to be_blank
      end
    end

    context "with non-controllable accessories mixed in" do
      it "only shows checkboxes for controllable ones" do
        readonly = Accessory.create!(name: "Sensor Only", uuid: "readonly-1", room: room, last_seen_at: 5.minutes.ago)
        Sensor.create!(accessory: readonly, characteristic_type: "Current Temperature", is_writable: false,
                       service_uuid: "svc-r", characteristic_uuid: "char-r", service_type: "TemperatureSensor")

        render_inline(described_class.new(accessories: [ light, switch_acc, readonly ]))

        expect(rendered_content).to include("Light 1")
        expect(rendered_content).to include("Switch 1")
        expect(rendered_content).not_to include("Sensor Only")
      end
    end

    it "renders progress area (hidden by default)" do
      render_inline(described_class.new(accessories: [ light, switch_acc ]))

      expect(rendered_content).to include('data-batch-control-target="progressArea"')
      expect(rendered_content).to include("Processing...")
    end

    it "renders results area (hidden by default)" do
      render_inline(described_class.new(accessories: [ light, switch_acc ]))

      expect(rendered_content).to include('data-batch-control-target="resultsArea"')
    end
  end
end
