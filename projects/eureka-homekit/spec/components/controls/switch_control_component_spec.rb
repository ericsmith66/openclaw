# frozen_string_literal: true

require "rails_helper"

RSpec.describe Controls::SwitchControlComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-123", home: home) }
  let(:accessory) { Accessory.create!(name: "Test Switch", uuid: "acc-123", room: room, last_seen_at: 5.minutes.ago) }

  let(:on_sensor) do
    Sensor.create!(
      accessory: accessory,
      characteristic_type: "On",
      current_value: "0",
      service_uuid: "svc-123",
      characteristic_uuid: "char-123",
      service_type: "Switch",
      is_writable: true,
      last_updated_at: Time.current
    )
  end

  describe "#current_state" do
    it "returns true when sensor value is '1'" do
      on_sensor.update!(current_value: "1")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to be true
    end

    it "returns true when sensor value is 'true'" do
      on_sensor.update!(current_value: "true")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to be true
    end

    it "returns true when sensor value is 'on'" do
      on_sensor.update!(current_value: "on")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to be true
    end

    it "returns true when sensor value is 'yes'" do
      on_sensor.update!(current_value: "yes")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to be true
    end

    it "returns false when sensor value is '0'" do
      on_sensor.update!(current_value: "0")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to be false
    end

    it "returns false when sensor value is 'false'" do
      on_sensor.update!(current_value: "false")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to be false
    end

    it "returns false when sensor value is 'off'" do
      on_sensor.update!(current_value: "off")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to be false
    end

    it "returns false when sensor value is 'no'" do
      on_sensor.update!(current_value: "no")
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to be false
    end

    it "returns false when no On sensor exists" do
      on_sensor.destroy
      component = described_class.new(accessory: accessory)
      expect(component.current_state).to be false
    end
  end

  describe "#offline?" do
    it "returns false when accessory was seen recently" do
      accessory.update!(last_seen_at: 5.minutes.ago)
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

  describe "#size_class" do
    it "returns 'toggle-lg' for lg size" do
      component = described_class.new(accessory: accessory, size: 'lg')
      expect(component.size_class).to eq('toggle-lg')
    end

    it "returns 'toggle-sm' for sm size" do
      component = described_class.new(accessory: accessory, size: 'sm')
      expect(component.size_class).to eq('toggle-sm')
    end

    it "returns 'toggle' for default size" do
      component = described_class.new(accessory: accessory)
      expect(component.size_class).to eq('toggle')
    end
  end

  describe "rendering" do
    it "renders the accessory name" do
      render_inline(described_class.new(accessory: accessory))
      expect(rendered_content).to include("Test Switch")
    end

    it "renders a checkbox input with correct classes" do
      render_inline(described_class.new(accessory: accessory))
      expect(rendered_content).to include('type="checkbox"')
      expect(rendered_content).to include('class="toggle')
    end

    it "renders checked when state is true" do
      on_sensor.update!(current_value: "1")
      render_inline(described_class.new(accessory: accessory))
      expect(rendered_content).to include('checked')
    end

    it "renders disabled when accessory is offline" do
      accessory.update!(last_seen_at: 2.hours.ago)
      render_inline(described_class.new(accessory: accessory))
      expect(rendered_content).to include('disabled')
    end

    it "includes data attributes for Stimulus controller" do
      render_inline(described_class.new(accessory: accessory))
      expect(rendered_content).to include('data-controller="switch-control"')
      expect(rendered_content).to include("data-switch-control-accessory-id-value=\"#{accessory.uuid}\"")
      expect(rendered_content).to include('data-switch-control-characteristic-value="On"')
      expect(rendered_content).to include('data-action="change->switch-control#toggle"')
    end
  end

  describe "No-Op state handling" do
    it "renders correctly when state is already true (toggle remains checked)" do
      on_sensor.update!(current_value: "1")
      render_inline(described_class.new(accessory: accessory))
      expect(rendered_content).to include('checked')
    end

    it "renders correctly when state is already false (toggle remains unchecked)" do
      on_sensor.update!(current_value: "0")
      render_inline(described_class.new(accessory: accessory))
      expect(rendered_content).to include('class="toggle "')
      expect(rendered_content).not_to include('checked')
    end

    it "handles both 'true' and '1' values equivalently" do
      on_sensor.update!(current_value: "true")
      component1 = described_class.new(accessory: accessory)
      on_sensor.update!(current_value: "1")
      component2 = described_class.new(accessory: accessory)
      expect(component1.current_state).to be true
      expect(component2.current_state).to be true
    end

    it "handles both 'false' and '0' values equivalently" do
      on_sensor.update!(current_value: "false")
      component1 = described_class.new(accessory: accessory)
      on_sensor.update!(current_value: "0")
      component2 = described_class.new(accessory: accessory)
      expect(component1.current_state).to be false
      expect(component2.current_state).to be false
    end
  end
end
