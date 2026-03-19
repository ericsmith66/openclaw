# frozen_string_literal: true

module AgentDesk
  module Skills
    # Immutable data structure representing a discovered skill.
    #
    # @!attribute [r] name
    #   @return [String] canonical name of the skill (from frontmatter or directory name)
    # @!attribute [r] description
    #   @return [String] short description (from frontmatter; empty string if none)
    # @!attribute [r] dir_path
    #   @return [String] absolute path to the skill's directory
    # @!attribute [r] location
    #   @return [:global, :project] where the skill was discovered
    Skill = Data.define(:name, :description, :dir_path, :location) do
      # @param name [String]
      # @param description [String]
      # @param dir_path [String]
      # @param location [:global, :project]
      def initialize(name:, description:, dir_path:, location:)
        super
      end

      # Returns the absolute path to the skill's SKILL.md file.
      #
      # @return [String]
      def skill_file_path
        File.join(dir_path, "SKILL.md")
      end
    end
  end
end
