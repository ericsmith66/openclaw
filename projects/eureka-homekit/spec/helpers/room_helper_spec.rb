require 'rails_helper'

RSpec.describe "Room Heatmap Logic", type: :helper do
  include RoomHelper

  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-123", home: home) }

  describe "#room_heatmap_class" do
    context "when no events have occurred" do
      it "returns heatmap-cold" do
        expect(room_heatmap_class(room)).to eq("heatmap-cold")
      end
    end

    context "when motion occurred within last 5 minutes" do
      it "returns heatmap-active with animate-pulse-slow" do
        room.update!(last_motion_at: 2.minutes.ago, last_event_at: 2.minutes.ago)
        expect(room_heatmap_class(room)).to eq("heatmap-active animate-pulse-slow")
      end
    end

    context "when motion occurred 10 minutes ago" do
      it "returns heatmap-warm" do
        room.update!(last_motion_at: 10.minutes.ago, last_event_at: 10.minutes.ago)
        expect(room_heatmap_class(room)).to eq("heatmap-warm")
      end
    end

    context "when motion occurred 20 minutes ago but other event occurred 10 minutes ago" do
      it "returns heatmap-warm" do
        room.update!(last_motion_at: 20.minutes.ago, last_event_at: 10.minutes.ago)
        expect(room_heatmap_class(room)).to eq("heatmap-warm")
      end
    end

    context "when all activity is older than 15 minutes" do
      it "returns heatmap-cold" do
        room.update!(last_motion_at: 20.minutes.ago, last_event_at: 20.minutes.ago)
        expect(room_heatmap_class(room)).to eq("heatmap-cold")
      end
    end
  end
end
