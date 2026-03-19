# frozen_string_literal: true

require "rails_helper"

RSpec.describe Scenes::CardComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-sc-123") }
  let(:room) { Room.create!(name: "Test Room", uuid: "room-sc-123", home: home) }
  let(:accessory) { Accessory.create!(name: "Light 1", uuid: "acc-sc-123", room: room) }
  let(:scene) do
    scene = Scene.create!(name: "Good Morning", uuid: "scene-uuid-123", home: home)
    SceneAccessory.create!(scene: scene, accessory: accessory)
    scene
  end

  describe "#icon_emoji" do
    { "Morning Routine" => "🌅", "Wake Up" => "🌅",
      "Good Night" => "🌙", "Sleep Time" => "🌙", "Bedtime" => "🌙",
      "Movie Night" => "🌙", "TV Time" => "🎬", "Movie Marathon" => "🎬",
      "Dinner Party" => "🍽️", "Eating Time" => "🍽️",
      "Leave Home" => "🚪", "Away Mode" => "🚪",
      "Arrive Home" => "🏠",
      "Random Scene" => "⚡" }.each do |name, expected_emoji|
      it "returns #{expected_emoji} for '#{name}'" do
        scene.update!(name: name)
        component = described_class.new(scene: scene)
        expect(component.icon_emoji).to eq(expected_emoji)
      end
    end
  end

  describe "#accessories_count" do
    it "returns the number of accessories in the scene" do
      component = described_class.new(scene: scene)
      expect(component.accessories_count).to eq(1)
    end

    it "returns 0 when scene has no accessories" do
      empty_scene = Scene.create!(name: "Empty", uuid: "scene-empty", home: home)
      component = described_class.new(scene: empty_scene)
      expect(component.accessories_count).to eq(0)
    end
  end

  describe "#last_executed" do
    it "returns 'Never' when scene has no execution history" do
      component = described_class.new(scene: scene)
      expect(component.last_executed).to eq("Never")
    end

    it "returns time ago string when scene has been executed" do
      ControlEvent.create!(
        scene: scene,
        action_type: "execute_scene",
        success: true,
        latency_ms: 100.0,
        source: "web",
        request_id: SecureRandom.uuid,
        created_at: 2.hours.ago
      )
      component = described_class.new(scene: scene)
      expect(component.last_executed).to include("hour")
    end

    it "uses only successful execution events" do
      ControlEvent.create!(
        scene: scene,
        action_type: "execute_scene",
        success: false,
        latency_ms: 100.0,
        source: "web",
        request_id: SecureRandom.uuid,
        created_at: 1.minute.ago
      )
      component = described_class.new(scene: scene)
      expect(component.last_executed).to eq("Never")
    end
  end

  describe "rendering" do
    it "renders the scene name" do
      render_inline(described_class.new(scene: scene))
      expect(rendered_content).to include("Good Morning")
    end

    it "renders the icon emoji" do
      render_inline(described_class.new(scene: scene))
      expect(rendered_content).to include("🌅")
    end

    it "renders the accessories count" do
      render_inline(described_class.new(scene: scene))
      expect(rendered_content).to include("1")
      expect(rendered_content).to include("accessories")
    end

    it "renders the execute button" do
      render_inline(described_class.new(scene: scene))
      expect(rendered_content).to include("Execute")
      expect(rendered_content).to include('data-action="click->scene#execute"')
    end

    it "renders Stimulus controller data attributes" do
      render_inline(described_class.new(scene: scene))
      expect(rendered_content).to include('data-controller="scene"')
      expect(rendered_content).to include("data-scene-id-value=\"#{scene.id}\"")
    end

    context "when show_home is true" do
      it "renders the home name" do
        render_inline(described_class.new(scene: scene, show_home: true))
        expect(rendered_content).to include("Test Home")
      end
    end

    context "when show_home is false" do
      it "does not render the home name" do
        render_inline(described_class.new(scene: scene, show_home: false))
        expect(rendered_content).not_to include("Test Home")
      end
    end
  end
end
