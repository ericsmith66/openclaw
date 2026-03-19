# frozen_string_literal: true

module AgentDesk
  module Prompts
    # Computed value object that describes which tool groups are enabled
    # for a given agent profile. Used by the template engine to conditionally
    # include/exclude sections in the system prompt.
    #
    # @example
    #   perms = ToolPermissions.from_profile(profile)
    #   perms.power_tools? # => true
    #   perms.todo_tools?  # => false
    #
    # @see AgentDesk::Agent::Profile
    class ToolPermissions
      # @!attribute [r] power_tools
      #   @return [Boolean] whether the power tool group is enabled
      # @!attribute [r] aider_tools
      #   @return [Boolean] whether the aider tool group is enabled
      # @!attribute [r] todo_tools
      #   @return [Boolean] whether the todo tool group is enabled
      # @!attribute [r] memory_tools
      #   @return [Boolean] whether the memory tool group is enabled
      # @!attribute [r] skills_tools
      #   @return [Boolean] whether the skills tool group is enabled
      # @!attribute [r] subagents
      #   @return [Boolean] whether the subagents tool group is enabled
      # @!attribute [r] task_tools
      #   @return [Boolean] whether the task tool group is enabled
      attr_reader :power_tools, :aider_tools, :todo_tools,
                  :memory_tools, :skills_tools, :subagents, :task_tools

      # Compute tool permissions from a Profile.
      #
      # @param profile [AgentDesk::Agent::Profile] agent profile
      # @return [ToolPermissions]
      def self.from_profile(profile)
        new(
          power_tools:  !!profile.use_power_tools,
          aider_tools:  !!profile.use_aider_tools,
          todo_tools:   !!profile.use_todo_tools,
          memory_tools: !!profile.use_memory_tools,
          skills_tools: !!profile.use_skills_tools,
          subagents:    !!profile.use_subagents,
          task_tools:   !!profile.use_task_tools
        )
      end

      # @param power_tools [Boolean]
      # @param aider_tools [Boolean]
      # @param todo_tools [Boolean]
      # @param memory_tools [Boolean]
      # @param skills_tools [Boolean]
      # @param subagents [Boolean]
      # @param task_tools [Boolean]
      def initialize(power_tools:, aider_tools:, todo_tools:,
                     memory_tools:, skills_tools:, subagents:, task_tools:)
        @power_tools  = power_tools
        @aider_tools  = aider_tools
        @todo_tools   = todo_tools
        @memory_tools = memory_tools
        @skills_tools = skills_tools
        @subagents    = subagents
        @task_tools   = task_tools
      end

      # @return [Boolean]
      def power_tools?
        @power_tools
      end

      # @return [Boolean]
      def aider_tools?
        @aider_tools
      end

      # @return [Boolean]
      def todo_tools?
        @todo_tools
      end

      # @return [Boolean]
      def memory_tools?
        @memory_tools
      end

      # @return [Boolean]
      def skills_tools?
        @skills_tools
      end

      # @return [Boolean]
      def subagents?
        @subagents
      end

      # @return [Boolean]
      def task_tools?
        @task_tools
      end

      # Convert to a hash suitable for Liquid template rendering.
      # All keys are strings (Liquid requirement).
      #
      # @return [Hash{String => Boolean}]
      def to_liquid_hash
        {
          "power_tools"  => @power_tools,
          "aider_tools"  => @aider_tools,
          "todo_tools"   => @todo_tools,
          "memory_tools" => @memory_tools,
          "skills_tools" => @skills_tools,
          "subagents"    => @subagents,
          "task_tools"   => @task_tools
        }
      end
    end
  end
end
