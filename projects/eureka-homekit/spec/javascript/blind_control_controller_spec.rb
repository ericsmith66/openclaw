# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Blind control controller" do
  let(:controller_path) { Rails.root.join("app/javascript/controllers/blind_control_controller.js") }
  let(:source) { File.read(controller_path) }

  it "maps open/close actions to correct Target Position values" do
    expect(source).to match(/openFully\(\)[\s\S]*sendControl\('Target Position', 100\)/)
    expect(source).to match(/closeFully\(\)[\s\S]*sendControl\('Target Position', 0\)/)
  end

  it "reports open/close success messages based on the correct values" do
    expect(source).to include("if (value === 100)")
    expect(source).to include("message = 'Blind opened'")
    expect(source).to include("} else if (value === 0) {")
    expect(source).to include("message = 'Blind closed'")
  end
end
