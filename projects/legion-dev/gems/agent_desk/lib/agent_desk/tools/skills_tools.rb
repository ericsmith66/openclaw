# frozen_string_literal: true

require_relative "../skills/skill_loader"

module AgentDesk
  module Tools
    module SkillsTools
      # Factory that creates a ToolSet containing the activate_skill tool.
      #
      # @param project_dir [String] absolute path to the project directory
      # @param skill_loader [AgentDesk::Skills::SkillLoader] optional loader instance
      # @return [ToolSet] tool set with the activate_skill tool
      def self.create(project_dir:, skill_loader: AgentDesk::Skills::SkillLoader.new)
        tool_set = ToolSet.new
        tool = skill_loader.activate_skill_tool(project_dir: project_dir)
        tool_set.add(tool)
        tool_set
      end
    end
  end
end
