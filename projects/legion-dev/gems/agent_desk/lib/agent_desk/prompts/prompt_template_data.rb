# frozen_string_literal: true

module AgentDesk
  module Prompts
    # Builds the full Liquid template context hash from profile, permissions,
    # rules content, custom instructions, and system information.
    #
    # @example
    #   data = PromptTemplateData.new(
    #     profile: profile,
    #     permissions: ToolPermissions.from_profile(profile),
    #     project_dir: "/home/user/project",
    #     rules_content: "<File name=\"RULES.md\">...</File>",
    #     custom_instructions: "Always use Minitest"
    #   )
    #   hash = data.to_liquid_hash
    #
    # @see AgentDesk::Prompts::PromptsManager
    class PromptTemplateData
      # @param profile [AgentDesk::Agent::Profile] agent profile
      # @param permissions [AgentDesk::Prompts::ToolPermissions] computed permissions
      # @param project_dir [String] absolute path to the project directory
      # @param rules_content [String] pre-formatted XML rules content
      # @param custom_instructions [String] custom instructions text
      def initialize(profile:, permissions:, project_dir:, rules_content:, custom_instructions:)
        @profile = profile
        @permissions = permissions
        @project_dir = project_dir
        @rules_content = rules_content
        @custom_instructions = custom_instructions
      end

      # Build a nested hash with string keys for Liquid template rendering.
      #
      # @return [Hash{String => Object}]
      def to_liquid_hash
        {
          "agent" => agent_hash,
          "permissions" => @permissions.to_liquid_hash,
          "system" => system_hash,
          "rules_content" => @rules_content.to_s,
          "custom_instructions" => @custom_instructions.to_s,
          "constants" => constants_hash
        }
      end

      private

      # @return [Hash{String => Object}]
      def agent_hash
        {
          "name" => @profile.name.to_s,
          "provider" => @profile.provider.to_s,
          "model" => @profile.model.to_s,
          "max_iterations" => @profile.max_iterations
        }
      end

      # @return [Hash{String => String}]
      def system_hash
        {
          "date" => Time.now.strftime("%a %b %d %Y"),
          "os" => detect_os,
          "project_dir" => @project_dir.to_s
        }
      end

      # @return [Hash{String => String}]
      def constants_hash
        {
          "tool_group_name_separator" => AgentDesk::TOOL_GROUP_NAME_SEPARATOR,
          "power_tool_group_name" => AgentDesk::POWER_TOOL_GROUP_NAME,
          "aider_tool_group_name" => AgentDesk::AIDER_TOOL_GROUP_NAME,
          "todo_tool_group_name" => AgentDesk::TODO_TOOL_GROUP_NAME,
          "memory_tool_group_name" => AgentDesk::MEMORY_TOOL_GROUP_NAME,
          "skills_tool_group_name" => AgentDesk::SKILLS_TOOL_GROUP_NAME,
          "subagents_tool_group_name" => AgentDesk::SUBAGENTS_TOOL_GROUP_NAME,
          "tasks_tool_group_name" => AgentDesk::TASKS_TOOL_GROUP_NAME,
          "helpers_tool_group_name" => AgentDesk::HELPERS_TOOL_GROUP_NAME
        }
      end

      # Detect the operating system name.
      #
      # @return [String]
      def detect_os
        case RUBY_PLATFORM
        when /darwin/i then "macOS"
        when /linux/i  then "Linux"
        when /win|mingw|mswin/i then "Windows"
        else RUBY_PLATFORM
        end
      end
    end
  end
end
