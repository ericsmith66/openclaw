# frozen_string_literal: true

require "test_helper"

class TeamImportIntegrationTest < ActiveSupport::TestCase
  # Disable parallelisation: tests share filesystem fixture state.
  parallelize(workers: 1)

  setup do
    @fixture_path = Rails.root.join("test/fixtures/aider_desk/valid_team")
    config_path = @fixture_path.join("agents/agent-a/config.json")
    File.write(
      config_path,
      '{"id": "agent-a-id","name": "Agent A","provider": "anthropic","model": "claude-sonnet",' \
      '"maxIterations": 100,"usePowerTools": true,"customInstructions": "Be helpful"}'
    )
  end

  # Helper: returns a unique project path so DB rows from each test are isolated.
  def unique_project_path
    "/tmp/test_project_integ_#{SecureRandom.hex(6)}"
  end

  # ---------------------------------------------------------------------------
  # Integration Test 1 (Plan #24) — Import and verify to_profile
  # ---------------------------------------------------------------------------
  test "import from fixture and verify to_profile works" do
    result = Legion::TeamImportService.call(
      aider_desk_path: @fixture_path.to_s,
      project_path: unique_project_path,
      team_name: "TestTeam"
    )

    membership = result.memberships.first[:membership]
    profile = membership.to_profile

    assert_instance_of AgentDesk::Agent::Profile, profile
    assert_equal "agent-a-id", profile.id
    assert_equal "Agent A", profile.name
    assert_equal "anthropic", profile.provider
    assert_equal "claude-sonnet", profile.model
    assert_equal 100, profile.max_iterations
    assert profile.use_power_tools
    assert_equal "Be helpful", profile.custom_instructions
  end

  # ---------------------------------------------------------------------------
  # Integration Test 2 (Plan #25) — Re-import preserves IDs and updates config
  # ---------------------------------------------------------------------------
  test "re-import preserves IDs and updates config" do
    project_path = unique_project_path

    # First import
    result1 = Legion::TeamImportService.call(
      aider_desk_path: @fixture_path.to_s,
      project_path: project_path,
      team_name: "TestTeam"
    )
    ids = result1.memberships.map { |m| m[:membership].id }

    # Modify config
    config_path = @fixture_path.join("agents/agent-a/config.json")
    config = JSON.parse(File.read(config_path))
    config["maxIterations"] = 999
    File.write(config_path, JSON.generate(config))

    # Re-import
    result2 = Legion::TeamImportService.call(
      aider_desk_path: @fixture_path.to_s,
      project_path: project_path,
      team_name: "TestTeam"
    )

    assert_equal ids.sort, result2.memberships.map { |m| m[:membership].id }.sort
    updated_membership = result2.memberships.find { |m| m[:membership].config["id"] == "agent-a-id" }[:membership]
    assert_equal 999, updated_membership.config["maxIterations"]
  ensure
    # Restore config.json to original state for setup's benefit
    File.write(
      @fixture_path.join("agents/agent-a/config.json"),
      '{"id": "agent-a-id","name": "Agent A","provider": "anthropic","model": "claude-sonnet",' \
      '"maxIterations": 100,"usePowerTools": true,"customInstructions": "Be helpful"}'
    )
  end

  # ---------------------------------------------------------------------------
  # Integration Test 3 (Plan #26) — Transaction rollback on DB error (AC11)
  # ---------------------------------------------------------------------------
  test "transaction rollback on DB error leaves no partial records" do
    project_path = unique_project_path
    team_name = "RollbackTeam"

    # Inject a failure by monkey-patching TeamMembership.create! on the
    # singleton class so the 2nd call raises, simulating a mid-transaction
    # DB failure after 1 membership has been inserted.
    call_count = 0
    original_create = TeamMembership.singleton_class.instance_method(:create!)

    TeamMembership.define_singleton_method(:create!) do |**attrs|
      call_count += 1
      if call_count == 2
        m = new
        m.errors.add(:base, "injected failure")
        raise ActiveRecord::RecordInvalid.new(m)
      end
      original_create.bind_call(self, **attrs)
    end

    begin
      assert_raises(ActiveRecord::RecordInvalid) do
        Legion::TeamImportService.call(
          aider_desk_path: @fixture_path.to_s,
          project_path: project_path,
          team_name: team_name
        )
      end
    ensure
      # Restore original create! so subsequent tests are not affected
      TeamMembership.singleton_class.remove_method(:create!)
    end

    # The transaction must have rolled back: no memberships for RollbackTeam
    assert_equal 0,
                 TeamMembership.joins(:agent_team).where(agent_teams: { name: team_name }).count,
                 "Transaction rollback should leave zero TeamMembership records"
  end
end
