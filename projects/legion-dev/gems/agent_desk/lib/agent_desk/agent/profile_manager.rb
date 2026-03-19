# frozen_string_literal: true

require "json"

# Loads and manages agent profiles from the filesystem.
# Reads JSON config files from `~/.aider-desk/agents/*/config.json` (global)
# and `{project}/.aider-desk/agents/*/config.json` (project‑level).
#
# @see AgentDesk::Agent::Profile
module AgentDesk
  module Agent
    class ProfileManager
      AIDER_DESK_DIR = ".aider-desk"
      AGENTS_DIR = "agents"
      CONFIG_FILE = "config.json"
      RULES_DIR = "rules"

      # @!attribute [r] global_profiles
      #   @return [Array<Profile>] profiles loaded from the global directory
      # @!attribute [r] project_profiles
      #   @return [Hash{String => Array<Profile>}] map project_dir → profiles
      attr_reader :global_profiles, :project_profiles

      # Initialize a new ProfileManager.
      #
      # @example
      #   ProfileManager.new
      #   ProfileManager.new(global_dir: "/custom/path/.aider-desk/agents")
      #
      # @param global_dir [String, nil] custom global agents directory
      def initialize(global_dir: nil)
        @global_dir = global_dir || File.join(Dir.home, AIDER_DESK_DIR, AGENTS_DIR)
        @global_profiles = []
        @project_profiles = {} # project_dir => [Profile]
      end

      # Load global profiles from `~/.aider-desk/agents/*/config.json`.
      #
      # @return [Array<Profile>] loaded profiles (empty if none)
      def load_global_profiles
        @global_profiles = load_profiles_from(@global_dir)
      end

      # Load project‑specific profiles from `{project}/.aider-desk/agents/*/config.json`.
      #
      # @param project_dir [String] absolute path to the project root
      # @return [Array<Profile>] loaded profiles (empty if none)
      def load_project_profiles(project_dir)
        agents_dir = File.join(project_dir, AIDER_DESK_DIR, AGENTS_DIR)
        profiles = load_profiles_from(agents_dir, project_dir: project_dir)
        @project_profiles[project_dir] = profiles
        profiles
      end

      # Return all profiles available for a project (project + global).
      #
      # @param project_dir [String] absolute path to the project root
      # @return [Array<Profile>]
      def profiles_for(project_dir)
        project = @project_profiles.fetch(project_dir, [])
        project + @global_profiles
      end

      # Find a profile by its ID.
      #
      # @param id [String] profile ID
      # @param project_dir [String, nil] optional project scope
      # @return [Profile, nil]
      def find(id, project_dir: nil)
        if project_dir
          profiles_for(project_dir).find { |p| p.id == id }
        else
          @global_profiles.find { |p| p.id == id }
        end
      end

      # Find a profile by name (case‑insensitive).
      #
      # @param name [String] profile name
      # @param project_dir [String, nil] optional project scope
      # @return [Profile, nil]
      def find_by_name(name, project_dir: nil)
        profiles = project_dir ? profiles_for(project_dir) : @global_profiles
        profiles.find { |p| p.name.downcase == name.downcase }
      end

      private

      # Load profiles from a given agents directory.
      #
      # @param agents_dir [String] absolute path to agents directory
      # @param project_dir [String, nil] associated project directory
      # @return [Array<Profile>]
      def load_profiles_from(agents_dir, project_dir: nil)
        return [] unless File.directory?(agents_dir)

        profiles = []
        Dir.each_child(agents_dir) do |dir_name|
          dir_path = File.join(agents_dir, dir_name)
          next unless File.directory?(dir_path)

          config_path = File.join(dir_path, CONFIG_FILE)
          next unless File.exist?(config_path)

          profile = load_profile(config_path, dir_name, project_dir: project_dir)
          profiles << profile if profile
        end
        profiles
      end

      # Load a single profile from a config file.
      #
      # @param config_path [String] absolute path to config.json
      # @param dir_name [String] agent directory name (used for rule discovery)
      # @param project_dir [String, nil] associated project directory
      # @return [Profile, nil] loaded profile or nil on error
      def load_profile(config_path, dir_name, project_dir: nil)
        json = JSON.parse(File.read(config_path), symbolize_names: false)
        attrs = deep_symbolize_keys(json)
        normalize_loaded_attributes(attrs)
        # Convert subagent_config hash to SubagentConfig instance
        if attrs.key?(:subagent_config) && attrs[:subagent_config].is_a?(Hash)
          attrs[:subagent_config] = SubagentConfig.new(**attrs[:subagent_config])
        end
        profile = Profile.new(**attrs)
        profile.project_dir = project_dir
        profile.rule_files = discover_rule_files(dir_name, project_dir)
        profile
      rescue JSON::ParserError, Errno::ENOENT, Errno::EACCES, ArgumentError => e
        warn "Failed to load profile from #{config_path}: #{e.message}"
        nil
      end

      # Discover rule files from the three‑tier hierarchy.
      #
      # 1. `~/.aider-desk/agents/{dir_name}/rules/*.md` (global agent)
      # 2. `{project}/.aider-desk/rules/*.md` (project‑wide)
      # 3. `{project}/.aider-desk/agents/{dir_name}/rules/*.md` (project agent)
      #
      # @param dir_name [String] agent directory name
      # @param project_dir [String, nil] project directory
      # @return [Array<String>] absolute paths to rule files (sorted)
      def discover_rule_files(dir_name, project_dir)
        paths = []

        # 1. Global agent rules
        global_rules_dir = File.join(@global_dir, dir_name, RULES_DIR)
        paths.concat(md_files_in(global_rules_dir))

        if project_dir
          # 2. Project‑level rules (shared for all agents)
          project_rules_dir = File.join(project_dir, AIDER_DESK_DIR, "rules")
          paths.concat(md_files_in(project_rules_dir))

          # 3. Project agent‑specific rules
          project_agent_rules = File.join(project_dir, AIDER_DESK_DIR, AGENTS_DIR, dir_name, RULES_DIR)
          paths.concat(md_files_in(project_agent_rules))
        end

        paths
      end

      # Return sorted .md files in a directory.
      #
      # @param dir [String] directory path
      # @return [Array<String>] absolute paths
      def md_files_in(dir)
        return [] unless File.directory?(dir)
        Dir.glob(File.join(dir, "*.md")).sort
      end

      # Convert hash keys from symbols to strings, recursively.
      #
      # @param hash [Hash] hash with symbol keys
      # @return [Hash{String => Object}] transformed hash
      def stringify_hash_keys(hash)
        hash.transform_keys(&:to_s)
          .transform_values do |v|
            case v
            when Hash
              stringify_hash_keys(v)
            when Array
              v.map { |item| item.is_a?(Hash) ? stringify_hash_keys(item) : item }
            else
              v
            end
          end
      end

      # Normalize attribute values after deep_symbolize_keys.
      #
      # - tool_approvals and tool_settings keys must remain strings (tool IDs)
      # - compaction_strategy should be a Symbol
      #
      # @param attrs [Hash] attributes from deep_symbolize_keys
      # @return [Hash] normalized attributes
      def normalize_loaded_attributes(attrs)
        # Convert tool_approvals and tool_settings hash keys to strings
        %i[tool_approvals tool_settings].each do |key|
          next unless attrs[key].is_a?(Hash)
          attrs[key] = stringify_hash_keys(attrs[key])
        end

        # Convert compaction_strategy string to symbol if needed
        if attrs[:compaction_strategy].is_a?(String)
          attrs[:compaction_strategy] = attrs[:compaction_strategy].to_sym
        end

        attrs
      end

      # Convert hash keys from camelCase to snake_case symbols, recursively.
      #
      # @param hash [Hash] original hash with string keys
      # @return [Hash{Symbol => Object}] transformed hash
      def deep_symbolize_keys(hash)
        hash.transform_keys { |k| k.to_s.gsub(/([A-Z])/, '_\1').downcase.delete_prefix("_").to_sym }
          .transform_values do |v|
            case v
            when Hash
              deep_symbolize_keys(v)
            when Array
              v.map { |item| item.is_a?(Hash) ? deep_symbolize_keys(item) : item }
            else
              v
            end
          end
      end
    end
  end
end
