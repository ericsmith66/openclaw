# frozen_string_literal: true

require "bundler/setup"
require "simplecov"
SimpleCov.start do
  add_filter "/test/"
end

require "minitest/autorun"
require "minitest/pride"
require "minitest/mock"
require "agent_desk"

# Test support
require_relative "support/mock_model_manager"

module AgentDesk
  module TestHelpers
    FIXTURES_DIR = File.expand_path("fixtures", __dir__)

    def fixture_path(relative)
      File.join(FIXTURES_DIR, relative)
    end

    def fixture_content(relative)
      File.read(fixture_path(relative))
    end

    def default_profile_json
      fixture_content("profiles/default.json")
    end
  end
end

class Minitest::Test
  include AgentDesk::TestHelpers
end
