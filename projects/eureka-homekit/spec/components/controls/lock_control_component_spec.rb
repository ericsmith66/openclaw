# frozen_string_literal: true

require "rails_helper"

RSpec.describe Controls::LockControlComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-123", home: home) }
  let(:accessory) { Accessory.create!(name: "Test Lock", uuid: "lock-123", room: room, last_seen_at: 5.minutes.ago) }

  # Lock Current State mapping: 0=unsecured, 1=secured, 2=jammed, 3=unknown
  let!(:current_state_sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_type: "Lock Current State",
      current_value: "1",
      service_uuid: "svc-lock-1",
      characteristic_uuid: "char-lock-current",
      service_type: "LockMechanism",
      last_updated_at: Time.current
    )
  end

  # Lock Target State mapping: 0=unsecured, 1=secured
  let!(:target_state_sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_type: "Lock Target State",
      current_value: "1",
      service_uuid: "svc-lock-2",
      characteristic_uuid: "char-lock-target",
      service_type: "LockMechanism",
      is_writable: true,
      last_updated_at: Time.current
    )
  end

  describe "#current_state" do
    it "returns the lock current state" do
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to eq(1)
    end

    it "returns 0 for unsecured state" do
      current_state_sensor.update!(current_value: "0")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to eq(0)
    end

    it "returns 2 for jammed state" do
      current_state_sensor.update!(current_value: "2")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to eq(2)
    end

    it "returns 3 for unknown state" do
      current_state_sensor.update!(current_value: "3")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to eq(3)
    end

    it "returns 3 when sensor is missing" do
      current_state_sensor.delete
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to eq(3)
    end
  end

  describe "#target_state" do
    it "returns the lock target state" do
      component = described_class.new(accessory: accessory)
      expect(component.target_state).to eq(1)
    end

    it "returns 0 for unsecured target state" do
      target_state_sensor.update!(current_value: "0")
      component = described_class.new(accessory: accessory)
      expect(component.target_state).to eq(0)
    end

    it "returns 0 when sensor is missing" do
      target_state_sensor.delete
      component = described_class.new(accessory: accessory)
      expect(component.target_state).to eq(0)
    end
  end

  describe "#locked?" do
    it "returns true when current state is secured (1)" do
      component = described_class.new(accessory: accessory)
      expect(component.locked?).to be true
    end

    it "returns false when current state is unsecured (0)" do
      current_state_sensor.update!(current_value: "0")
      component = described_class.new(accessory: accessory)
      expect(component.locked?).to be false
    end

    it "returns false when current state is jammed (2)" do
      current_state_sensor.update!(current_value: "2")
      component = described_class.new(accessory: accessory)
      expect(component.locked?).to be false
    end
  end

  describe "#unlocked?" do
    it "returns true when current state is unsecured (0)" do
      current_state_sensor.update!(current_value: "0")
      component = described_class.new(accessory: accessory)
      expect(component.unlocked?).to be true
    end

    it "returns false when current state is secured (1)" do
      component = described_class.new(accessory: accessory)
      expect(component.unlocked?).to be false
    end

    it "returns false when current state is jammed (2)" do
      current_state_sensor.update!(current_value: "2")
      component = described_class.new(accessory: accessory)
      expect(component.unlocked?).to be false
    end
  end

  describe "#jammed?" do
    it "returns true when current state is jammed (2)" do
      current_state_sensor.update!(current_value: "2")
      component = described_class.new(accessory: accessory)
      expect(component.jammed?).to be true
    end

    it "returns false when current state is secured (1)" do
      component = described_class.new(accessory: accessory)
      expect(component.jammed?).to be false
    end

    it "returns false when current state is unsecured (0)" do
      current_state_sensor.update!(current_value: "0")
      component = described_class.new(accessory: accessory)
      expect(component.jammed?).to be false
    end
  end

  describe "#unknown?" do
    it "returns true when current state is unknown (3)" do
      current_state_sensor.update!(current_value: "3")
      component = described_class.new(accessory: accessory)
      expect(component.unknown?).to be true
    end

    it "returns false when current state is secured (1)" do
      component = described_class.new(accessory: accessory)
      expect(component.unknown?).to be false
    end
  end

  describe "#state_icon" do
    it "returns 🔓 for unsecured state (0)" do
      current_state_sensor.update!(current_value: "0")
      component = described_class.new(accessory: accessory)
      expect(component.state_icon).to eq('🔓')
    end

    it "returns 🔒 for secured state (1)" do
      component = described_class.new(accessory: accessory)
      expect(component.state_icon).to eq('🔒')
    end

    it "returns ⚠️ for jammed state (2)" do
      current_state_sensor.update!(current_value: "2")
      component = described_class.new(accessory: accessory)
      expect(component.state_icon).to eq('⚠️')
    end

    it "returns ❓ for unknown state (3)" do
      current_state_sensor.update!(current_value: "3")
      component = described_class.new(accessory: accessory)
      expect(component.state_icon).to eq('❓')
    end
  end

  describe "#state_text" do
    it "returns 'Unlocked' for state 0" do
      current_state_sensor.update!(current_value: "0")
      component = described_class.new(accessory: accessory)
      expect(component.state_text).to eq('Unlocked')
    end

    it "returns 'Locked' for state 1" do
      component = described_class.new(accessory: accessory)
      expect(component.state_text).to eq('Locked')
    end

    it "returns 'Jammed' for state 2" do
      current_state_sensor.update!(current_value: "2")
      component = described_class.new(accessory: accessory)
      expect(component.state_text).to eq('Jammed')
    end

    it "returns 'Unknown' for state 3" do
      current_state_sensor.update!(current_value: "3")
      component = described_class.new(accessory: accessory)
      expect(component.state_text).to eq('Unknown')
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

    it "returns true when accessory was seen more than 1 hour ago" do
      accessory.update!(last_seen_at: 2.hours.ago)
      component = described_class.new(accessory: accessory)
      expect(component.offline?).to be true
    end
  end
end
