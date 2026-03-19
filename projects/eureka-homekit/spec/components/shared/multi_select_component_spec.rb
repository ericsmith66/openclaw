# frozen_string_literal: true

require "rails_helper"

RSpec.describe Shared::MultiSelectComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-ms-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-ms-123", home: home) }
  let(:accessory1) { Accessory.create!(name: "Light 1", uuid: "acc-ms-1", room: room) }
  let(:accessory2) { Accessory.create!(name: "Light 2", uuid: "acc-ms-2", room: room) }
  let(:accessory3) { Accessory.create!(name: "Fan 1", uuid: "acc-ms-3", room: room) }

  let(:items) { [ accessory1, accessory2, accessory3 ] }

  describe "#item_id" do
    it "returns the uuid by default" do
      component = described_class.new(items: items)
      expect(component.item_id(accessory1)).to eq("acc-ms-1")
    end

    it "returns custom id method value" do
      component = described_class.new(items: items, id_method: :name)
      expect(component.item_id(accessory1)).to eq("Light 1")
    end
  end

  describe "#item_label" do
    it "returns the name by default" do
      component = described_class.new(items: items)
      expect(component.item_label(accessory1)).to eq("Light 1")
    end
  end

  describe "#selected?" do
    it "returns true when item is in selected list" do
      component = described_class.new(items: items, selected: [ "acc-ms-1" ])
      expect(component.selected?(accessory1)).to be true
    end

    it "returns false when item is not in selected list" do
      component = described_class.new(items: items, selected: [ "acc-ms-1" ])
      expect(component.selected?(accessory2)).to be false
    end
  end

  describe "#items_count" do
    it "returns total number of items" do
      component = described_class.new(items: items)
      expect(component.items_count).to eq(3)
    end
  end

  describe "#selected_count" do
    it "returns number of selected items" do
      component = described_class.new(items: items, selected: [ "acc-ms-1", "acc-ms-3" ])
      expect(component.selected_count).to eq(2)
    end
  end

  describe "rendering" do
    it "renders all items as checkboxes" do
      render_inline(described_class.new(items: items))
      expect(rendered_content).to include("Light 1")
      expect(rendered_content).to include("Light 2")
      expect(rendered_content).to include("Fan 1")
    end

    it "renders the Stimulus controller attribute" do
      render_inline(described_class.new(items: items))
      expect(rendered_content).to include('data-controller="multi-select"')
    end

    it "renders Select All and Deselect All buttons" do
      render_inline(described_class.new(items: items))
      expect(rendered_content).to include("Select All")
      expect(rendered_content).to include("Deselect All")
    end

    it "renders count badge" do
      render_inline(described_class.new(items: items, selected: [ "acc-ms-1" ]))
      expect(rendered_content).to include("/ 3 selected")
    end

    it "marks selected items as checked" do
      render_inline(described_class.new(items: items, selected: [ "acc-ms-1" ]))
      expect(rendered_content).to include('value="acc-ms-1"')
      expect(rendered_content).to include("checked")
    end

    it "renders aria-label on each checkbox" do
      render_inline(described_class.new(items: items))
      expect(rendered_content).to include('aria-label="Select Light 1"')
      expect(rendered_content).to include('aria-label="Select Fan 1"')
    end

    it "renders empty list when no items" do
      render_inline(described_class.new(items: []))
      expect(rendered_content).to include("/ 0 selected")
    end
  end
end
