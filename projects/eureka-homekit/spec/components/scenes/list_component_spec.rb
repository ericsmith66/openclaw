# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scenes::ListComponent, type: :component do
  let(:home1) { Home.create!(name: "Main House", uuid: "home-list-1") }
  let(:home2) { Home.create!(name: "Beach House", uuid: "home-list-2") }
  let(:scene1) { Scene.create!(name: "Good Morning", uuid: "scene-list-1", home: home1) }
  let(:scene2) { Scene.create!(name: "Good Night", uuid: "scene-list-2", home: home1) }
  let(:scene3) { Scene.create!(name: "Movie Time", uuid: "scene-list-3", home: home2) }

  describe "#empty?" do
    it "returns true when no scenes" do
      component = described_class.new(scenes: [])
      expect(component).to be_empty
    end

    it "returns false when scenes exist" do
      component = described_class.new(scenes: [ scene1 ])
      expect(component).not_to be_empty
    end
  end

  describe "#grouped_scenes" do
    it "groups scenes by home name" do
      component = described_class.new(scenes: [ scene1, scene2, scene3 ], show_home: true)
      groups = component.grouped_scenes
      expect(groups.keys).to match_array([ "Main House", "Beach House" ])
      expect(groups["Main House"]).to match_array([ scene1, scene2 ])
      expect(groups["Beach House"]).to eq([ scene3 ])
    end
  end

  describe "#should_group?" do
    it "returns true when show_home is true and multiple homes exist" do
      component = described_class.new(scenes: [ scene1, scene3 ], show_home: true)
      expect(component.should_group?).to be true
    end

    it "returns false when show_home is false" do
      component = described_class.new(scenes: [ scene1, scene3 ], show_home: false)
      expect(component.should_group?).to be false
    end

    it "returns false when all scenes belong to one home" do
      component = described_class.new(scenes: [ scene1, scene2 ], show_home: true)
      expect(component.should_group?).to be false
    end
  end

  describe "rendering" do
    context "when no scenes" do
      it "renders empty state" do
        render_inline(described_class.new(scenes: []))
        expect(rendered_content).to include("No scenes configured")
        expect(rendered_content).to include("⚡")
        expect(rendered_content).to include("Apple Home app")
      end
    end

    context "when scenes exist without grouping" do
      it "renders scene cards in a grid" do
        render_inline(described_class.new(scenes: [ scene1, scene2 ], show_home: false))
        expect(rendered_content).to include("Good Morning")
        expect(rendered_content).to include("Good Night")
        expect(rendered_content).to include("grid-cols-1")
      end
    end

    context "when scenes from multiple homes with show_home" do
      it "renders grouped by home with headings" do
        render_inline(described_class.new(scenes: [ scene1, scene3 ], show_home: true))
        expect(rendered_content).to include("Main House")
        expect(rendered_content).to include("Beach House")
        expect(rendered_content).to include("Good Morning")
        expect(rendered_content).to include("Movie Time")
      end
    end

    context "when scenes from one home with show_home" do
      it "renders flat grid (no grouping)" do
        render_inline(described_class.new(scenes: [ scene1, scene2 ], show_home: true))
        expect(rendered_content).to include("Good Morning")
        expect(rendered_content).to include("Good Night")
        # Should NOT have home heading since only one home
        expect(rendered_content).not_to include("<h2")
      end
    end
  end
end
