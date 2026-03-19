require "rails_helper"

RSpec.describe FloorplanViewerComponent, type: :component do
  let(:home) { Home.create!(name: "Test Home", uuid: "home-123") }
  let!(:floorplan) { Floorplan.create!(home: home, name: "First Floor", level: 1) }

  it "renders the floorplan viewer container" do
    render_inline(described_class.new(home: home))

    expect(rendered_content).to include("floorplan-viewer")
    expect(rendered_content).to include("data-controller=\"floorplan-viewer\"")
  end

  it "renders the level switcher when multiple floorplans exist" do
    Floorplan.create!(home: home, name: "Second Floor", level: 2)

    render_inline(described_class.new(home: home))

    expect(rendered_content).to include("join")
    expect(rendered_content).to include("First Floor")
    expect(rendered_content).to include("Second Floor")
  end

  it "does not render the level switcher when only one floorplan exists" do
    render_inline(described_class.new(home: home))

    expect(rendered_content).not_to include("join-item")
  end

  it "renders zoom controls" do
    render_inline(described_class.new(home: home))

    expect(rendered_content).to include("click-&gt;floorplan-viewer#zoomIn").or include("click->floorplan-viewer#zoomIn")
    expect(rendered_content).to include("click-&gt;floorplan-viewer#zoomOut").or include("click->floorplan-viewer#zoomOut")
    expect(rendered_content).to include("click-&gt;floorplan-viewer#resetZoom").or include("click->floorplan-viewer#resetZoom")
  end

  it "renders the loading state" do
    render_inline(described_class.new(home: home))

    expect(rendered_content).to include("data-floorplan-viewer-target=\"loading\"")
  end

  it "renders the SVG container" do
    render_inline(described_class.new(home: home))

    expect(rendered_content).to include("data-floorplan-viewer-target=\"container\"")
  end

  it "renders the labels overlay" do
    render_inline(described_class.new(home: home))

    expect(rendered_content).to include("data-floorplan-viewer-target=\"overlay\"")
  end

  it "does not render if there are no floorplans" do
    empty_home = Home.create!(name: "Empty Home", uuid: "home-empty")
    render_inline(described_class.new(home: empty_home))

    expect(rendered_content).to be_blank
  end
end
