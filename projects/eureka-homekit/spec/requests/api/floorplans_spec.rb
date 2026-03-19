require 'rails_helper'

RSpec.describe "Api::Floorplans", type: :request do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Living Room", uuid: "room-123", home: home) }
  let(:floorplan) { Floorplan.create!(home: home, name: "First Floor", level: 1) }

  describe "GET /api/floorplans/:id" do
    context "when floorplan exists" do
      before do
        floorplan.svg_file.attach(
          io: StringIO.new('<svg id="floorplan"></svg>'),
          filename: 'floorplan.svg',
          content_type: 'image/svg+xml'
        )

        mapping = { "Graphic_1" => { "room_id" => room.id, "level" => 1 } }
        floorplan.mapping_file.attach(
          io: StringIO.new(mapping.to_json),
          filename: 'mapping.json',
          content_type: 'application/json'
        )
      end

      it "returns 200 OK" do
        get api_floorplan_path(floorplan)
        expect(response).to have_http_status(:ok)
      end

      it "returns the floorplan data" do
        get api_floorplan_path(floorplan)
        json = JSON.parse(response.body)

        expect(json["id"]).to eq(floorplan.id)
        expect(json["name"]).to eq("First Floor")
        expect(json["svg_content"]).to eq('<svg id="floorplan"></svg>')
        expect(json["mapping"]["Graphic_1"]["room_id"]).to eq(room.id)
        expect(json["mapping"]["Graphic_1"]["room_name"]).to eq("Living Room")
      end
    end

    context "when floorplan does not exist" do
      it "returns 404 Not Found" do
        get "/api/floorplans/999999"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
