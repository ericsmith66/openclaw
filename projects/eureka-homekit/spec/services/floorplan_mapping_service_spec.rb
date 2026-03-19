require 'rails_helper'

RSpec.describe FloorplanMappingService do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Living Room", uuid: "room-123", home: home) }
  let(:floorplan) { Floorplan.create!(home: home, name: "First Floor", level: 1) }
  let(:service) { FloorplanMappingService.new(floorplan) }

  describe "#resolve" do
    context "when mapping file is attached" do
      before do
        mapping = { "Graphic_1" => { "room_id" => room.id, "level" => 1 } }
        floorplan.mapping_file.attach(
          io: StringIO.new(mapping.to_json),
          filename: 'mapping.json',
          content_type: 'application/json'
        )
      end

      it "resolves the mapping to rooms" do
        result = service.resolve
        expect(result["Graphic_1"][:room]).to eq(room)
      end

      it "includes sensor states" do
        # Create a sensor for the room
        accessory = Accessory.create!(name: "Sensor Hub", uuid: "acc-1", room: room)
        Sensor.create!(
          accessory: accessory,
          characteristic_type: "Current Temperature",
          characteristic_uuid: "char-1",
          service_type: "TemperatureSensor",
          service_uuid: "svc-1",
          current_value: 22.5,
          value_format: "float"
        )

        result = service.resolve
        # 22.5C to F is 72.5F
        expect(result["Graphic_1"][:sensor_states][:temperature]).to be_within(0.1).of(72.5)
      end
    end

    context "when mapping file is missing" do
      it "returns an empty hash" do
        expect(service.resolve).to eq({})
      end
    end
  end
end
