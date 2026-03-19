# frozen_string_literal: true

module AgentDesk
  module Rules
    class RulesLoader
      # Use the same constants defined in AgentDesk::Agent::ProfileManager
      AIDER_DESK_DIR  = AgentDesk::Agent::ProfileManager::AIDER_DESK_DIR
      AGENTS_DIR      = AgentDesk::Agent::ProfileManager::AGENTS_DIR
      RULES_DIR       = AgentDesk::Agent::ProfileManager::RULES_DIR

      # @!attribute [r] global_agents_dir
      #   @return [String] absolute path to the global agents directory
      attr_reader :global_agents_dir

      # Initialize a new RulesLoader.
      #
      # @param global_agents_dir [String, nil] custom global agents directory
      #   (defaults to ~/.aider-desk/agents)
      def initialize(global_agents_dir: nil)
        @global_agents_dir = global_agents_dir || File.join(Dir.home, AIDER_DESK_DIR, AGENTS_DIR)
      end

      # Returns array of absolute paths to rule files for a given profile + project
      # in precedence order: global agent → project‑wide → project agent.
      #
      # @param profile_dir_name [String] directory name of the agent profile (e.g., "default")
      # @param project_dir [String, nil] project directory (nil for global‑only profiles)
      # @raise [ArgumentError] if profile_dir_name is empty or contains path separators
      # @return [Array<String>] sorted absolute paths to .md files
      def rule_file_paths(profile_dir_name:, project_dir: nil)
        validate_profile_dir_name!(profile_dir_name)
        paths = []

        # 1. Global agent rules
        global_rules = File.join(@global_agents_dir, profile_dir_name, RULES_DIR)
        paths.concat(md_files_in(global_rules))

        if project_dir
          # 2. Project‑wide rules (shared for all agents)
          project_rules = File.join(project_dir, AIDER_DESK_DIR, RULES_DIR)
          paths.concat(md_files_in(project_rules))

          # 3. Project agent‑specific rules
          project_agent_rules = File.join(project_dir, AIDER_DESK_DIR, AGENTS_DIR, profile_dir_name, RULES_DIR)
          paths.concat(md_files_in(project_agent_rules))
        end

        paths
      end

      # Load and format rule files as XML fragments for system prompt injection.
      # Returns a string like:
      #   <File name="AGENTS.md"><![CDATA[...content...]]></File>
      #   <File name="CONVENTIONS.md"><![CDATA[...content...]]></File>
      #
      # @param profile_dir_name [String] directory name of the agent profile
      # @param project_dir [String, nil] project directory
      # @return [String] concatenated XML‑wrapped rule content, or empty string if no rules
      def load_rules_content(profile_dir_name:, project_dir: nil)
        paths = rule_file_paths(profile_dir_name: profile_dir_name, project_dir: project_dir)
        return "" if paths.empty?

        fragments = []
        paths.each do |path|
          begin
            content = File.read(path, encoding: "UTF-8").strip
            # Escape ]]› to avoid breaking CDATA section
            content = escape_cdata(content)
            # Use relative path from its containing rules directory as the "name"
            name = rule_name_from_path(path, profile_dir_name, project_dir)
            fragments << "<File name=\"#{name}\"><![CDATA[#{content}]]></File>"
          rescue StandardError => e
            warn "Failed to read rule file #{path}: #{e.message}"
          end
        end

        fragments.join("\n")
      end

      private

      # Validate that profile_dir_name is safe to use in a filesystem path.
      #
      # @param profile_dir_name [String]
      # @raise [ArgumentError] if validation fails
      def validate_profile_dir_name!(profile_dir_name)
        if profile_dir_name.nil? || profile_dir_name.empty?
          raise ArgumentError, "profile_dir_name cannot be empty"
        end
        if profile_dir_name.include?(File::SEPARATOR) || profile_dir_name.include?("..")
          raise ArgumentError, "profile_dir_name cannot contain path separators or '..'"
        end
      end

      # Return sorted .md files in a directory.
      #
      # @param dir [String] directory path
      # @return [Array<String>] absolute paths, empty if directory does not exist
      def md_files_in(dir)
        return [] unless File.directory?(dir)
        Dir.glob(File.join(dir, "*.md")).sort
      end

      # Compute a display‑friendly name for a rule file.
      # Strip the containing rules directory and keep the relative path.
      # For global agent rules: "global/AGENTS.md"
      # For project‑wide rules: "project/CONVENTIONS.md"
      # For project agent rules: "project‑agent/SPECIAL.md"
      #
      # @param path [String] absolute path to rule file
      # @param profile_dir_name [String] profile directory name
      # @param project_dir [String, nil] project directory
      # @return [String] display name with tier prefix
      def rule_name_from_path(path, profile_dir_name, project_dir)
        # Determine which tier this path belongs to
        global_base = File.join(@global_agents_dir, profile_dir_name, RULES_DIR) + "/"
        if path.start_with?(global_base)
          base = global_base.chomp("/")
          prefix = "global"
        elsif project_dir
          project_base = File.join(project_dir, AIDER_DESK_DIR, RULES_DIR) + "/"
          if path.start_with?(project_base)
            base = project_base.chomp("/")
            prefix = "project"
          else
            project_agent_base = File.join(project_dir, AIDER_DESK_DIR, AGENTS_DIR, profile_dir_name, RULES_DIR) + "/"
            if path.start_with?(project_agent_base)
              base = project_agent_base.chomp("/")
              prefix = "project-agent"
            else
              # Fallback: just the basename
              return File.basename(path)
            end
          end
        else
          # Fallback: just the basename
          return File.basename(path)
        end

        relative = path.sub(base + "/", "")
        "#{prefix}/#{relative}"
      end

      # Escape ]]› inside CDATA sections by splitting the CDATA block.
      # Standard XML escaping: replace ]]› with ]]]]›<![CDATA[›
      #
      # @param content [String] raw rule content
      # @return [String] escaped content safe for CDATA
      def escape_cdata(content)
        content.gsub("]]>", "]]]]><![CDATA[>")
      end
    end
  end
end
