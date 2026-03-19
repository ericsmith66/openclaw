# frozen_string_literal: true

require "rails_helper"

RSpec.describe Shared::StatusBadgeComponent, type: :component do
  it "renders the badge with correct label" do
    html = render_inline(described_class.new(status: :success, label: "ONLINE")).to_html
    expect(html).to include("ONLINE")
    expect(html).to include("badge-success")
  end

  it "renders pulse animation when requested" do
    html = render_inline(described_class.new(status: :warning, pulse: true)).to_html
    expect(html).to include("animate-pulse")
  end

  it "handles different statuses" do
    html = render_inline(described_class.new(status: :error)).to_html
    expect(html).to include("badge-error")
  end
end
