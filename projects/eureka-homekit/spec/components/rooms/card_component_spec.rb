require "rails_helper"

RSpec.describe Rooms::CardComponent, type: :component do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home, name: "Living Room") }

  it "renders the room name" do
    render_inline(described_class.new(room: room))
    expect(rendered_content).to include("Living Room")
  end

  it "renders the accessory count" do
    create(:accessory, room: room)
    render_inline(described_class.new(room: room))
    expect(rendered_content).to include("1 Accessories")
  end
end
