# frozen_string_literal: true

require "rails_helper"

RSpec.describe Shared::StatCardComponent, type: :component do
  it "renders the label and value" do
    html = render_inline(described_class.new(label: "Test Stat", value: "123")).to_html
    expect(html).to include("Test Stat")
    expect(html).to include("123")
  end

  it "renders the icon if provided" do
    html = render_inline(described_class.new(label: "Home", value: "1", icon: "home")).to_html
    expect(html).to include("<svg")
  end

  it "renders trend with correct color" do
    html = render_inline(described_class.new(label: "Trend", value: "10", trend: "+2")).to_html
    expect(html).to include("+2")
    expect(html).to include("text-success")
  end
end
