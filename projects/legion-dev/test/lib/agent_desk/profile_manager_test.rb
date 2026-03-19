# frozen_string_literal: true

require "test_helper"

class ProfileManagerTest < ActiveSupport::TestCase
  LEGION_DIR = Rails.root.to_s

  EXPECTED_AGENTS = %w[
    ror-architect-legion
    ror-debug-legion
    ror-qa-legion
    ror-rails-legion
  ].freeze

  VALID_PROVIDERS = %w[anthropic deepseek openai smart_proxy custom].freeze

  setup do
    @pm = AgentDesk::Agent::ProfileManager.new
    @profiles = @pm.load_project_profiles(LEGION_DIR)
  end

  test "loads exactly 4 agent profiles" do
    assert_equal 4, @profiles.size
  end

  test "all expected agent IDs are present" do
    ids = @profiles.map(&:id).sort
    assert_equal EXPECTED_AGENTS, ids
  end

  test "all agent IDs use -legion suffix" do
    @profiles.each do |profile|
      assert_match(/-legion\z/, profile.id, "#{profile.id} does not end with -legion")
      refute_match(/agent-forge/, profile.id, "#{profile.id} still contains agent-forge")
    end
  end

  test "all profiles have valid provider" do
    @profiles.each do |profile|
      assert_includes VALID_PROVIDERS, profile.provider,
        "#{profile.id} has invalid provider: #{profile.provider}"
    end
  end

  test "all profiles have a model set" do
    @profiles.each do |profile|
      assert profile.model.present?, "#{profile.id} has no model"
    end
  end

  test "all profiles have positive maxIterations" do
    @profiles.each do |profile|
      assert profile.max_iterations.positive?,
        "#{profile.id} has non-positive max_iterations: #{profile.max_iterations}"
    end
  end

  test "all profiles have projectDir set to Legion" do
    @profiles.each do |profile|
      assert_equal LEGION_DIR, profile.project_dir,
        "#{profile.id} projectDir is #{profile.project_dir}, expected #{LEGION_DIR}"
    end
  end

  test "order.json contains all 4 agent IDs" do
    order_path = File.join(LEGION_DIR, ".aider-desk", "agents", "order.json")
    assert File.exist?(order_path), "order.json not found"

    order = JSON.parse(File.read(order_path))
    assert_equal 4, order.size

    EXPECTED_AGENTS.each do |agent_id|
      assert order.key?(agent_id), "order.json missing #{agent_id}"
    end
  end

  test "rails lead uses deepseek provider" do
    rails_lead = @profiles.find { |p| p.id == "ror-rails-legion" }
    assert_equal "deepseek", rails_lead.provider
    assert_equal "deepseek-reasoner", rails_lead.model
  end

  test "architect uses anthropic provider with opus model" do
    architect = @profiles.find { |p| p.id == "ror-architect-legion" }
    assert_equal "anthropic", architect.provider
    assert_match(/claude-opus/, architect.model)
  end

  test "qa agent uses anthropic provider with sonnet model" do
    qa = @profiles.find { |p| p.id == "ror-qa-legion" }
    assert_equal "anthropic", qa.provider
    assert_match(/claude-sonnet/, qa.model)
  end

  test "debug agent uses anthropic provider with sonnet model" do
    debug = @profiles.find { |p| p.id == "ror-debug-legion" }
    assert_equal "anthropic", debug.provider
    assert_match(/claude-sonnet/, debug.model)
  end
end
