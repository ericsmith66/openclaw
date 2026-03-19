# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dashboards::FavoritesComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-fav-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-fav-123", home: home) }

  let(:accessory1) do
    acc = Accessory.create!(name: "Light 1", uuid: "fav-acc-1", room: room, last_seen_at: 5.minutes.ago)
    Sensor.create!(
      accessory: acc,
      characteristic_type: "On",
      current_value: "1",
      service_uuid: "svc-fav-1",
      characteristic_uuid: "char-fav-1",
      service_type: "Lightbulb",
      is_writable: true,
      last_updated_at: Time.current
    )
    acc
  end

  let(:accessory2) do
    acc = Accessory.create!(name: "Fan 1", uuid: "fav-acc-2", room: room, last_seen_at: 5.minutes.ago)
    Sensor.create!(
      accessory: acc,
      characteristic_type: "Active",
      current_value: "0",
      service_uuid: "svc-fav-2",
      characteristic_uuid: "char-fav-2",
      service_type: "Fan",
      is_writable: true,
      last_updated_at: Time.current
    )
    acc
  end

  let(:accessories) { [ accessory1, accessory2 ] }

  describe "#empty?" do
    it "returns true when no favorites" do
      component = described_class.new(accessories: accessories, favorites: [])
      expect(component).to be_empty
    end

    it "returns false when favorites exist" do
      component = described_class.new(accessories: accessories, favorites: [ "fav-acc-1" ])
      expect(component).not_to be_empty
    end
  end

  describe "#favorite_accessories" do
    it "returns accessories in favorites order" do
      component = described_class.new(accessories: accessories, favorites: [ "fav-acc-2", "fav-acc-1" ])
      expect(component.favorite_accessories.map(&:uuid)).to eq([ "fav-acc-2", "fav-acc-1" ])
    end

    it "returns empty array when no favorites" do
      component = described_class.new(accessories: accessories, favorites: [])
      expect(component.favorite_accessories).to eq([])
    end

    it "skips UUIDs not found in accessories" do
      component = described_class.new(accessories: accessories, favorites: [ "fav-acc-1", "nonexistent" ])
      expect(component.favorite_accessories.map(&:uuid)).to eq([ "fav-acc-1" ])
    end
  end

  describe "#favorited?" do
    it "returns true for favorited accessory" do
      component = described_class.new(accessories: accessories, favorites: [ "fav-acc-1" ])
      expect(component.favorited?(accessory1)).to be true
    end

    it "returns false for non-favorited accessory" do
      component = described_class.new(accessories: accessories, favorites: [ "fav-acc-1" ])
      expect(component.favorited?(accessory2)).to be false
    end
  end

  describe "rendering" do
    context "when no favorites" do
      it "renders empty state" do
        render_inline(described_class.new(accessories: accessories, favorites: []))
        expect(rendered_content).to include("No favorites yet")
        expect(rendered_content).to include("⭐")
        expect(rendered_content).to include("Browse Rooms")
      end
    end

    context "when favorites exist" do
      it "renders favorite accessories" do
        render_inline(described_class.new(accessories: accessories, favorites: [ "fav-acc-1" ]))
        expect(rendered_content).to include("Light 1")
      end

      it "renders star buttons with filled star for favorites" do
        render_inline(described_class.new(accessories: accessories, favorites: [ "fav-acc-1" ]))
        expect(rendered_content).to include("★")
      end

      it "renders Stimulus controller" do
        render_inline(described_class.new(accessories: accessories, favorites: [ "fav-acc-1" ]))
        expect(rendered_content).to include('data-controller="favorites"')
      end

      it "renders room and home info" do
        render_inline(described_class.new(accessories: accessories, favorites: [ "fav-acc-1" ]))
        expect(rendered_content).to include("Test Room")
        expect(rendered_content).to include("Test Home")
      end

      it "renders accessory UUID data attribute" do
        render_inline(described_class.new(accessories: accessories, favorites: [ "fav-acc-1" ]))
        expect(rendered_content).to include('data-favorite-uuid="fav-acc-1"')
      end
    end
  end
end
