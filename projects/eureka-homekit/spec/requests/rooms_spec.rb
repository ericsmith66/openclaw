require "rails_helper"

RSpec.describe "Rooms", type: :request do
  let!(:home) { create(:home) }
  let!(:room) { create(:room, home: home, name: "Studio") }

  describe "GET /rooms" do
    it "returns http success" do
      get rooms_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Studio")
    end
  end

  describe "GET /rooms/:id" do
    it "returns http success" do
      get room_path(room)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Studio")
    end
  end

  describe "GET /homes/:home_id/rooms" do
    it "returns http success" do
      get home_rooms_path(home)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Studio")
    end
  end
end
