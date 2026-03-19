# frozen_string_literal: true

require "rails_helper"

RSpec.describe Shared::ControlFeedbackComponent, type: :component do
  describe "state helpers" do
    it "detects idle state" do
      component = described_class.new(state: "idle")
      expect(component).to be_idle
      expect(component).not_to be_loading
      expect(component).not_to be_success
      expect(component).not_to be_error
    end

    it "detects loading state" do
      component = described_class.new(state: "loading")
      expect(component).to be_loading
      expect(component).not_to be_idle
    end

    it "detects success state" do
      component = described_class.new(state: "success")
      expect(component).to be_success
    end

    it "detects error state" do
      component = described_class.new(state: "error")
      expect(component).to be_error
    end

    it "defaults to idle" do
      component = described_class.new
      expect(component).to be_idle
    end
  end

  describe "rendering" do
    context "when idle" do
      it "renders a hidden container" do
        render_inline(described_class.new(state: "idle"))
        expect(rendered_content).to include("hidden")
      end
    end

    context "when loading" do
      it "renders a spinner" do
        render_inline(described_class.new(state: "loading"))
        expect(rendered_content).to include("loading-spinner")
      end

      it "renders default loading message" do
        render_inline(described_class.new(state: "loading"))
        expect(rendered_content).to include("Processing...")
      end

      it "renders custom loading message" do
        render_inline(described_class.new(state: "loading", message: "Sending command..."))
        expect(rendered_content).to include("Sending command...")
      end

      it "has role=status for accessibility" do
        render_inline(described_class.new(state: "loading"))
        expect(rendered_content).to include('role="status"')
        expect(rendered_content).to include('aria-live="polite"')
      end
    end

    context "when success" do
      it "renders success icon (checkmark SVG)" do
        render_inline(described_class.new(state: "success"))
        expect(rendered_content).to include("<svg")
        expect(rendered_content).to include("fill-rule")
      end

      it "renders default success message" do
        render_inline(described_class.new(state: "success"))
        expect(rendered_content).to include("Success")
      end

      it "renders custom success message" do
        render_inline(described_class.new(state: "success", message: "Light turned on"))
        expect(rendered_content).to include("Light turned on")
      end

      it "applies green styling" do
        render_inline(described_class.new(state: "success"))
        expect(rendered_content).to include("bg-green-50")
        expect(rendered_content).to include("text-green-700")
      end
    end

    context "when error" do
      it "renders error icon (X SVG)" do
        render_inline(described_class.new(state: "error"))
        expect(rendered_content).to include("<svg")
      end

      it "renders default error message" do
        render_inline(described_class.new(state: "error"))
        expect(rendered_content).to include("An error occurred")
      end

      it "renders custom error message" do
        render_inline(described_class.new(state: "error", message: "Connection timeout"))
        expect(rendered_content).to include("Connection timeout")
      end

      it "applies red styling" do
        render_inline(described_class.new(state: "error"))
        expect(rendered_content).to include("bg-red-50")
        expect(rendered_content).to include("text-red-700")
      end
    end
  end
end
