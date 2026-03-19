require "yaml"

module Personas
  class MissingConfigError < StandardError; end

  class << self
    def all
      @all ||= load_config
    end

    def ids
      all.map { |p| p.fetch("id") }
    end

    def find(id)
      all.find { |p| p.fetch("id") == id.to_s }
    end

    def reset!
      @all = nil
    end

    private

    def load_config
      path = Rails.root.join("config/personas.yml")
      raise MissingConfigError, "config/personas.yml not found" unless File.exist?(path)

      data = YAML.safe_load(File.read(path), permitted_classes: [ Symbol ], aliases: true) || {}
      personas = data.fetch("personas") { [] }
      personas.is_a?(Array) ? personas : []
    end
  end
end
