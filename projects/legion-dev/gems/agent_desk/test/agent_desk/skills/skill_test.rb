# frozen_string_literal: true

require "test_helper"

class SkillTest < Minitest::Test
  def test_initialize_with_all_attributes
    skill = AgentDesk::Skills::Skill.new(
      name: "Test Skill",
      description: "A test skill",
      dir_path: "/tmp/skill",
      location: :global
    )
    assert_equal "Test Skill", skill.name
    assert_equal "A test skill", skill.description
    assert_equal "/tmp/skill", skill.dir_path
    assert_equal :global, skill.location
  end

  def test_initialize_with_empty_description
    skill = AgentDesk::Skills::Skill.new(
      name: "Empty Desc",
      description: "",
      dir_path: "/tmp/empty",
      location: :project
    )
    assert_equal "Empty Desc", skill.name
    assert_equal "", skill.description
    assert_equal :project, skill.location
  end

  def test_skill_file_path
    skill = AgentDesk::Skills::Skill.new(
      name: "Test",
      description: "",
      dir_path: "/path/to/skill",
      location: :global
    )
    assert_equal "/path/to/skill/SKILL.md", skill.skill_file_path
  end

  def test_immutability
    skill = AgentDesk::Skills::Skill.new(
      name: "Immutable",
      description: "Can't change",
      dir_path: "/tmp/immutable",
      location: :global
    )
    assert_raises(FrozenError) do
      skill.instance_variable_set(:@name, "Changed")
    end
  end

  def test_equality
    skill1 = AgentDesk::Skills::Skill.new(
      name: "Same",
      description: "Desc",
      dir_path: "/tmp/same",
      location: :global
    )
    skill2 = AgentDesk::Skills::Skill.new(
      name: "Same",
      description: "Desc",
      dir_path: "/tmp/same",
      location: :global
    )
    assert_equal skill1, skill2
  end

  def test_hash_key
    skill = AgentDesk::Skills::Skill.new(
      name: "Hash",
      description: "",
      dir_path: "/tmp/hash",
      location: :global
    )
    hash = { skill => "value" }
    assert_equal "value", hash[skill]
  end
end
