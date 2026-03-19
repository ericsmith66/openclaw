# frozen_string_literal: true

require "yaml"
require_relative "../constants"

module AgentDesk
  module Skills
    # Discovers skills from global and project directories.
    # Follows the same pattern as `RulesLoader`.
    #
    # @see PRD‑4c‑0080
    class SkillLoader
      # Directory name where skills are stored (relative to `.aider‑desk`).
      SKILLS_DIR = "skills"

      # File name that defines a skill.
      SKILL_FILE = "SKILL.md"

      # @!attribute [r] global_skills_dir
      #   @return [String] absolute path to the global skills directory
      attr_reader :global_skills_dir

      # Initialize a new SkillLoader.
      #
      # @param global_skills_dir [String, nil] custom global skills directory
      #   (defaults to `~/.aider‑desk/skills`)
      def initialize(global_skills_dir: nil)
        @global_skills_dir = global_skills_dir || default_global_skills_dir
      end

      # Discover all available skills for a given project.
      #
      # @param project_dir [String, nil] absolute path to the project root
      #   (nil for global‑only discovery)
      # @return [Array<Skill>] skills sorted by name, with project skills
      #   taking precedence over global skills of the same name.
      def discover(project_dir: nil)
        validate_project_dir!(project_dir) if project_dir

        skills = []
        skills.concat(load_from_dir(global_skills_dir, "global"))
        skills.concat(load_from_dir(project_skills_dir(project_dir), "project")) if project_dir

        deduplicate_skills(skills)
      end

      # Read the raw content of a skill's SKILL.md file.
      #
      # @param skill [Skill] the skill whose content should be read
      # @return [String] file content, UTF‑8 encoded
      # @raise [Errno::ENOENT] if the file does not exist
      def read_skill_content(skill)
        File.read(skill.skill_file_path, encoding: "UTF-8")
      end

      # Build a `BaseTool` instance that lists discovered skills and can activate
      # a selected skill by returning its SKILL.md content.
      #
      # @param project_dir [String, nil] project directory passed to `#discover`
      # @return [AgentDesk::Tools::BaseTool] a tool ready to be added to a toolset
      def activate_skill_tool(project_dir: nil)
        skills = discover(project_dir: project_dir)

        AgentDesk::Tools::BaseTool.new(
          name: AgentDesk::SKILLS_TOOL_ACTIVATE_SKILL,
          group_name: AgentDesk::SKILLS_TOOL_GROUP_NAME,
          description: build_description(skills),
          input_schema: {
            properties: {
              skill: { type: "string" }
            },
            required: [ "skill" ]
          }
        ) do |args, context:|
          skill_name = args["skill"]
          skill = skills.find { |s| s.name == skill_name }
          raise ArgumentError, "Unknown skill: #{skill_name.inspect}" unless skill

          read_skill_content(skill)
        end
      end

      private

      def default_global_skills_dir
        File.join(Dir.home, ".aider-desk", SKILLS_DIR)
      end

      def project_skills_dir(project_dir)
        File.join(project_dir, ".aider-desk", SKILLS_DIR)
      end

      # Validate that `project_dir` is safe to use in a filesystem path.
      #
      # @param project_dir [String]
      # @raise [ArgumentError] if validation fails
      def validate_project_dir!(project_dir)
        if project_dir.nil? || project_dir.empty?
          raise ArgumentError, "project_dir cannot be empty"
        end
        unless File.absolute_path?(project_dir)
          raise ArgumentError, "project_dir must be an absolute path"
        end
        if project_dir.include?("..")
          raise ArgumentError, "project_dir cannot contain '..'"
        end
      end

      # Load skills from a single directory.
      #
      # @param dir_path [String] absolute path to a skills directory
      # @param source [String] label for debugging ("global" or "project")
      # @return [Array<Skill>] skills found in that directory (unsorted)
      def load_from_dir(dir_path, source)
        return [] unless File.directory?(dir_path)

        Dir.children(dir_path).filter_map do |entry|
          skill_dir = File.join(dir_path, entry)
          next unless File.directory?(skill_dir)

          parse_skill(skill_dir, source)
        end
      end

      # Parse a skill directory into a Skill object.
      #
      # @param dir_path [String] absolute path to a skill directory
      # @return [Skill, nil] the parsed skill, or nil if the directory
      #   does not contain a SKILL.md file. If SKILL.md exists but has no
      #   YAML frontmatter delimiters, returns a Skill with name from directory
      #   basename and empty description.
      def parse_skill(dir_path, source)
        skill_file = File.join(dir_path, SKILL_FILE)
        return nil unless File.file?(skill_file)

        content = File.read(skill_file, encoding: "UTF-8")
        parts = content.split(/^---\s*$/, 3)
        if parts.length < 3
          # SKILL.md exists but lacks frontmatter delimiters → fallback to directory name
          return Skill.new(name: File.basename(dir_path), description: "", dir_path: dir_path, location: source.to_sym)
        end

        frontmatter = parts[1]
        metadata = YAML.safe_load(frontmatter, permitted_classes: [ Date, Time ], permitted_symbols: [], aliases: true) || {}
        name = metadata["name"]&.strip
        description = metadata["description"]&.strip || ""

        if name.nil? || name.empty?
          name = File.basename(dir_path)
        end

        Skill.new(name: name, description: description, dir_path: dir_path, location: source.to_sym)
      rescue StandardError => e
        # Malformed YAML frontmatter → fallback to directory name as skill name
        warn "Failed to parse skill #{dir_path}: #{e.message}" if $VERBOSE
        Skill.new(name: File.basename(dir_path), description: "", dir_path: dir_path, location: source.to_sym)
      end

      # Deduplicate skills: project skills override global skills with the same name.
      #
      # @param skills [Array<Skill>] raw list of skills (global first, then project)
      # @return [Array<Skill>] deduplicated list sorted by name
      def deduplicate_skills(skills)
        seen = {}
        skills.each do |skill|
          seen[skill.name] = skill
        end
        seen.values.sort_by(&:name)
      end

      # Build the LLM‑facing tool description listing available skills.
      #
      # @param skills [Array<Skill>]
      # @return [String] description with bullet list
      def build_description(skills)
        return "No skills available." if skills.empty?

        lines = skills.map { |s| "  - #{s.name}: #{s.description}" }
        <<~TEXT
          Activate a skill by providing its name. Available skills:

          #{lines.join("\n")}
        TEXT
      end
    end
  end
end
