require "rails_helper"

RSpec.describe Layouts::LeftSidebarComponent, type: :component do
  let(:homes) { [] }
  let(:component) { described_class.new(homes: homes) }

  it "renders the Floorplan link" do
    with_request_url("/") do
      render_inline(component)
    end

    expect(rendered_content).to include("Floorplan")
    expect(rendered_content).to include(Rails.application.routes.url_helpers.root_path(view: :floorplan))
    # It renders the map icon paths
    expect(rendered_content).to include("M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z")
  end

  it "renders common navigation links" do
    with_request_url("/") do
      render_inline(component)
    end

    expect(rendered_content).to include("Dashboard")
    expect(rendered_content).to include(Rails.application.routes.url_helpers.root_path)
    expect(rendered_content).to include("All Homes")
    expect(rendered_content).to include(Rails.application.routes.url_helpers.homes_path)
  end
end
