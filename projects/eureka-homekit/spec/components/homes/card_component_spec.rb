require "rails_helper"

RSpec.describe Homes::CardComponent, type: :component do
  let(:home) { create(:home, name: "Test Home") }

  it "renders the home name" do
    render_inline(described_class.new(home: home))
    expect(rendered_content).to include("Test Home")
  end

  it "renders the dashboard link" do
    render_inline(described_class.new(home: home))
    expect(rendered_content).to include("Dashboard")
  end
end
