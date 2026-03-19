require 'rails_helper'

RSpec.describe "Events", type: :request do
  let!(:home) { Home.create!(name: "Test Home", uuid: "home-1") }
  let!(:room) { Room.create!(name: "Living Room", uuid: "room-1", home: home) }
  let!(:accessory) { Accessory.create!(name: "UniqueMotionSensor", uuid: "acc-1", room: room) }
  let!(:event) {
    HomekitEvent.create!(
      event_type: "characteristic_updated",
      accessory_name: "UniqueMotionSensor",
      characteristic: "Motion Detected",
      value: "true",
      timestamp: Time.current,
      accessory: accessory
    )
  }

  describe "GET /events" do
    it "renders the events index" do
      get events_path
      expect(response).to have_http_status(200)
      expect(response.body).to include("HomeKit Activity")
      expect(response.body).to include("UniqueMotionSensor")
    end

    it "filters by search term" do
      get events_path(search: "UniqueMotion")
      expect(response.body).to include("UniqueMotionSensor")

      get events_path(search: "XYZZY")
      html = Nokogiri::HTML(response.body)
      events_table = html.at_css('[data-events-target="table"]')
      expect(events_table.text).not_to include("UniqueMotionSensor")
      expect(events_table.text).to include("No events found")
    end
  end

  describe "GET /events/:id" do
    it "renders the event show (XHR)" do
      get event_path(event), xhr: true
      expect(response).to have_http_status(200)
      expect(response.body).to include("Motion Detected")
    end
  end
end
