require "rails_helper"

RSpec.describe "Homes", type: :request do
  let!(:home) { create(:home, name: "Waverly") }

  describe "GET /homes" do
    it "returns http success" do
      get homes_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Waverly")
    end
  end

  describe "GET /homes/:id" do
    it "returns http success" do
      get home_path(home)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Waverly")
    end
  end
end
