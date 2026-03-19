# frozen_string_literal: true

module Shared
  class ControlFeedbackComponent < ViewComponent::Base
    STATES = %w[idle loading success error].freeze

    def initialize(state: "idle", message: nil)
      @state = state.to_s
      @message = message
    end

    def idle?
      @state == "idle"
    end

    def loading?
      @state == "loading"
    end

    def success?
      @state == "success"
    end

    def error?
      @state == "error"
    end

    def container_classes
      base = "flex items-center gap-2 p-3 rounded-lg text-sm transition-all"
      case @state
      when "loading"
        "#{base} bg-blue-50 text-blue-700 border border-blue-200"
      when "success"
        "#{base} bg-green-50 text-green-700 border border-green-200"
      when "error"
        "#{base} bg-red-50 text-red-700 border border-red-200"
      else
        "#{base} hidden"
      end
    end
  end
end
