# frozen_string_literal: true

require "test_helper"

class AgentTeamTest < ActiveSupport::TestCase
  test "factory creates valid record" do
    team = build(:agent_team)
    assert team.valid?
  end

  test "name validation" do
    team = build(:agent_team, name: nil)
    assert_not team.valid?
    assert_includes team.errors[:name], "can't be blank"
  end

  test "scoped uniqueness" do
    project = create(:project)
    create(:agent_team, project: project, name: "ROR")
    duplicate = build(:agent_team, project: project, name: "ROR")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "optional project" do
    team = build(:agent_team, project: nil)
    assert team.valid?
  end

  test "associations" do
    team = create(:agent_team)
    assert_difference("team.team_memberships.count", 1) do
      create(:team_membership, agent_team: team)
    end
  end
end
