# frozen_string_literal: true

require "yaml"

module Ai
  class ModelAllowlist
    CONFIG_PATH = Rails.root.join("config", "ai_models.yml").freeze

    def self.allowed_models
      @allowed_models ||= begin
        raw = YAML.safe_load(File.read(CONFIG_PATH)) || {}
        Array(raw["models"]).map(&:to_s).map(&:strip).reject(&:empty?)
      rescue Errno::ENOENT
        []
      end
    end

    def self.allowed?(model_id)
      return false if model_id.blank?
      allowed_models.include?(model_id.to_s)
    end
  end
end
