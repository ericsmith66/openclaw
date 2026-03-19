# frozen_string_literal: true

require "test_helper"

class AgentDeskInitializerTest < ActionDispatch::IntegrationTest
  test "agent_desk initializer file exists" do
    initializer_path = Rails.root.join("config", "initializers", "agent_desk.rb")
    assert File.exist?(initializer_path), "agent_desk.rb initializer not found"
  end

  test "AgentDesk module is loaded after initialization" do
    assert defined?(AgentDesk), "AgentDesk module not defined"
    assert defined?(AgentDesk::VERSION), "AgentDesk::VERSION not defined"
  end

  test "ProfileManager can load project profiles in initialized app" do
    pm = AgentDesk::Agent::ProfileManager.new
    profiles = pm.load_project_profiles(Rails.root.to_s)
    assert_equal 4, profiles.size
  end
end
