# frozen_string_literal: true

require "rails_helper"

RSpec.describe Controls::ThermostatControlComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-123", home: home) }
  let(:accessory) { Accessory.create!(name: "Test Thermostat", uuid: "acc-123", room: room, last_seen_at: 5.minutes.ago) }

  let!(:current_temp_sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_type: "Current Temperature",
      current_value: "22.0",
      service_uuid: "svc-123",
      characteristic_uuid: "char-123",
      service_type: "TemperatureSensor",
      value_format: "float",
      units: "°C",
      last_updated_at: Time.current
    )
  end

  let!(:target_temp_sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_type: "Target Temperature",
      current_value: "23.5",
      service_uuid: "svc-456",
      characteristic_uuid: "char-456",
      service_type: "Thermostat",
      is_writable: true,
      value_format: "float",
      units: "°C",
      last_updated_at: Time.current
    )
  end

  let!(:target_mode_sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_type: "Target Heating/Cooling State",
      current_value: "1",
      service_uuid: "svc-789",
      characteristic_uuid: "char-789",
      service_type: "Thermostat",
      is_writable: true,
      last_updated_at: Time.current
    )
  end

  let!(:current_mode_sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_type: "Current Heating/Cooling State",
      current_value: "1",
      service_uuid: "svc-999",
      characteristic_uuid: "char-999",
      service_type: "Thermostat",
      last_updated_at: Time.current
    )
  end

  let!(:unit_sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_type: "Temperature Display Units",
      current_value: "0",
      service_uuid: "svc-101",
      characteristic_uuid: "char-101",
      service_type: "Thermostat",
      is_writable: true,
      last_updated_at: Time.current
    )
  end

  describe "#current_temp_celsius" do
    it "returns the current temperature in Celsius" do
      component = described_class.new(accessory: accessory)
      expect(component.current_temp_celsius).to eq(22.0)
    end
  end

  describe "#current_temp_fahrenheit" do
    it "converts Celsius to Fahrenheit" do
      component = described_class.new(accessory: accessory)
      expect(component.current_temp_fahrenheit).to eq(71.6)
    end
  end

  describe "#target_temp_celsius" do
    it "returns the target temperature in Celsius" do
      component = described_class.new(accessory: accessory)
      expect(component.target_temp_celsius).to eq(23.5)
    end
  end

  describe "#target_temp_fahrenheit" do
    it "converts Celsius to Fahrenheit" do
      component = described_class.new(accessory: accessory)
      expect(component.target_temp_fahrenheit).to eq(74.3)
    end
  end

  describe "#target_mode" do
    it "returns the target heating/cooling mode" do
      component = described_class.new(accessory: accessory)
      expect(component.target_mode).to eq(1) # Heat
    end
  end

  describe "#current_mode" do
    it "returns the current heating/cooling mode" do
      component = described_class.new(accessory: accessory)
      expect(component.current_mode).to eq(1) # Heat
    end
  end

  describe "#display_unit" do
    it "returns 'C' when unit sensor is 0" do
      component = described_class.new(accessory: accessory)
      expect(component.display_unit).to eq('C')
    end

    it "returns 'F' when unit sensor is 1" do
      unit_sensor.update!(current_value: "1")
      component = described_class.new(accessory: accessory)
      expect(component.display_unit).to eq('F')
    end
  end

  describe "#heating?" do
    it "returns true when current mode is Heat (1)" do
      component = described_class.new(accessory: accessory)
      expect(component.heating?).to be true
    end

    it "returns false when current mode is Cool (2)" do
      current_mode_sensor.update!(current_value: "2")
      component = described_class.new(accessory: accessory)
      expect(component.heating?).to be false
    end

    it "returns false when current mode is Off (0)" do
      current_mode_sensor.update!(current_value: "0")
      component = described_class.new(accessory: accessory)
      expect(component.heating?).to be false
    end
  end

  describe "#cooling?" do
    it "returns true when current mode is Cool (2)" do
      current_mode_sensor.update!(current_value: "2")
      component = described_class.new(accessory: accessory)
      expect(component.cooling?).to be true
    end

    it "returns false when current mode is Heat (1)" do
      component = described_class.new(accessory: accessory)
      expect(component.cooling?).to be false
    end
  end

  describe "#offline?" do
    it "returns false when accessory was seen recently" do
      component = described_class.new(accessory: accessory)
      expect(component.offline?).to be false
    end

    it "returns true when accessory has never been seen" do
      accessory.update!(last_seen_at: nil)
      component = described_class.new(accessory: accessory)
      expect(component.offline?).to be true
    end
  end

  describe "#min_temp" do
    it "returns 10 for Celsius mode" do
      component = described_class.new(accessory: accessory)
      expect(component.min_temp).to eq(10)
    end

    it "returns 50 for Fahrenheit mode" do
      unit_sensor.update!(current_value: "1")
      component = described_class.new(accessory: accessory)
      expect(component.min_temp).to eq(50)
    end
  end

  describe "#max_temp" do
    it "returns 30 for Celsius mode" do
      component = described_class.new(accessory: accessory)
      expect(component.max_temp).to eq(30)
    end

    it "returns 86 for Fahrenheit mode" do
      unit_sensor.update!(current_value: "1")
      component = described_class.new(accessory: accessory)
      expect(component.max_temp).to eq(86)
    end
  end

  describe "#displayed_current_temp" do
    it "returns Celsius when unit is C" do
      component = described_class.new(accessory: accessory)
      expect(component.displayed_current_temp).to eq(22.0)
    end

    it "returns Fahrenheit when unit is F" do
      unit_sensor.update!(current_value: "1")
      component = described_class.new(accessory: accessory)
      expect(component.displayed_current_temp).to eq(71.6)
    end
  end

  describe "#displayed_target_temp" do
    it "returns Celsius when unit is C" do
      component = described_class.new(accessory: accessory)
      expect(component.displayed_target_temp).to eq(23.5)
    end

    it "returns Fahrenheit when unit is F" do
      unit_sensor.update!(current_value: "1")
      component = described_class.new(accessory: accessory)
      expect(component.displayed_target_temp).to eq(74.3)
    end
  end
end
