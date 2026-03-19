# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Favorites", type: :request do
  let(:home) { create(:home, name: "Test Home") }
  let(:room) { create(:room, home: home, name: "Living Room") }

  describe "GET /favorites" do
    it "returns a successful response" do
      get favorites_path
      expect(response).to have_http_status(:ok)
    end

    it "renders the favorites page" do
      get favorites_path
      expect(response.body).to include("Favorites")
    end

    context "with controllable accessories" do
      before do
        acc = create(:accessory, room: room, name: "Light 1", uuid: "light-1")
        create(:sensor, accessory: acc, characteristic_type: "On", is_writable: true,
               characteristic_uuid: "char-1", service_uuid: "svc-1", service_type: "Lightbulb")
      end

      it "includes controllable accessories in the response" do
        get favorites_path
        expect(response.body).to include("Light 1")
      end
    end

    context "with no controllable accessories" do
      before do
        acc = create(:accessory, room: room, name: "Sensor Only", uuid: "sensor-1")
        create(:sensor, accessory: acc, characteristic_type: "Current Temperature", is_writable: false,
               characteristic_uuid: "char-1", service_uuid: "svc-1", service_type: "TemperatureSensor")
      end

      it "shows the empty state message" do
        get favorites_path
        expect(response.body).to include("No controllable accessories")
      end
    end
  end
end
