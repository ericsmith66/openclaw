# frozen_string_literal: true

require "liquid"

module AgentDesk
  module Prompts
    # Assembles system prompts from Liquid templates using profile-based
    # tool permissions, rules content, and custom instructions.
    #
    # Templates are resolved via an override chain:
    #   1. Project: +{project_dir}/.aider-desk/prompts/{name}.liquid+
    #   2. Global:  +~/.aider-desk/prompts/{name}.liquid+
    #   3. Bundled: +gems/agent_desk/templates/{name}.liquid+
    #
    # Compiled templates are cached for performance (< 50ms rendering).
    #
    # @example Basic usage
    #   manager = PromptsManager.new
    #   prompt = manager.system_prompt(
    #     profile: profile,
    #     project_dir: "/home/user/my-project",
    #     rules_content: "<File name=\"RULES.md\"><![CDATA[...]]></File>",
    #     custom_instructions: "Always prefer Minitest over RSpec"
    #   )
    #
    # @see AgentDesk::Prompts::ToolPermissions
    # @see AgentDesk::Prompts::PromptTemplateData
    class PromptsManager
      # Template name for the main system prompt.
      SYSTEM_PROMPT_TEMPLATE = "system-prompt"

      # Template name for the workflow sub-template.
      WORKFLOW_TEMPLATE = "workflow"

      # Subdirectory name for prompt overrides within .aider-desk.
      PROMPTS_DIR = "prompts"

      # File extension for Liquid templates.
      TEMPLATE_EXT = ".liquid"

      # Create an Environment with registered filters for this service
      def self.environment
        @environment ||= begin
          env = Liquid::Environment.new
          env.register_filter(Legion::LiquidFilters)
          env.error_mode = :strict
          env
        end
      end

      # @param templates_dir [String, nil] path to bundled templates directory;
      #   defaults to +gems/agent_desk/templates/+
      # @param global_prompts_dir [String, nil] path to global prompt overrides;
      #   defaults to +~/.aider-desk/prompts/+
      def initialize(templates_dir: nil, global_prompts_dir: nil)
        @bundled_dir = templates_dir || default_templates_dir
        @global_dir = global_prompts_dir || File.join(Dir.home, ".aider-desk", PROMPTS_DIR)
        @template_cache = {}
        @mutex = Mutex.new
      end

      # Render the complete system prompt for a given profile and context.
      #
      # @param profile [AgentDesk::Agent::Profile] agent profile
      # @param project_dir [String] absolute path to the project directory
      # @param rules_content [String] pre-formatted XML rules content from RulesLoader
      # @param custom_instructions [String] custom instructions text
      # @return [String] rendered system prompt
      # @raise [AgentDesk::TemplateNotFoundError] if a required template cannot be found
      # @raise [AgentDesk::TemplateSyntaxError] if a template contains Liquid syntax errors
      def system_prompt(profile:, project_dir:, rules_content: "", custom_instructions: "")
        permissions = ToolPermissions.from_profile(profile)
        data = PromptTemplateData.new(
          profile: profile,
          permissions: permissions,
          project_dir: project_dir,
          rules_content: rules_content,
          custom_instructions: custom_instructions
        )
        hash = data.to_liquid_hash

        # Render workflow sub-template first, then embed into system prompt
        hash["workflow"] = render_template(WORKFLOW_TEMPLATE, hash, project_dir)
        render_template(SYSTEM_PROMPT_TEMPLATE, hash, project_dir)
      end

      # Clear the template cache. Useful after template files change on disk.
      #
      # @return [void]
      def clear_cache!
        @mutex.synchronize { @template_cache.clear }
      end

      private

      # Render a named template with the given data hash.
      #
      # @param name [String] template name (without extension)
      # @param data [Hash{String => Object}] Liquid-compatible template context
      # @param project_dir [String, nil] project directory for override lookup
      # @return [String] rendered output
      def render_template(name, data, project_dir)
        template = resolve_template(name, project_dir)
        template.render!(data)
      rescue Liquid::Error => e
        raise AgentDesk::TemplateSyntaxError,
              "Liquid rendering error in '#{name}': #{e.message}"
      end

      # Resolve a template by name using the override chain.
      # Caches compiled templates per (name, project_dir) pair.
      #
      # @param name [String] template name (without extension)
      # @param project_dir [String, nil] project directory for override lookup
      # @return [Liquid::Template] compiled template
      # @raise [AgentDesk::TemplateNotFoundError] if not found in any location
      def resolve_template(name, project_dir)
        cache_key = "#{project_dir || "global"}:#{name}"

        @mutex.synchronize do
          return @template_cache[cache_key] if @template_cache.key?(cache_key)
        end

        source = find_template_source(name, project_dir)
        raise AgentDesk::TemplateNotFoundError,
              "Template '#{name}' not found in project, global, or bundled templates" unless source

        compiled = compile_template(source, name)

        @mutex.synchronize do
          @template_cache[cache_key] = compiled
        end

        compiled
      end

      # Search the override chain for a template source.
      #
      # @param name [String] template name
      # @param project_dir [String, nil] project directory
      # @return [String, nil] template source, or nil if not found
      def find_template_source(name, project_dir)
        filename = "#{name}#{TEMPLATE_EXT}"

        # 1. Project override
        if project_dir
          project_path = File.join(project_dir, ".aider-desk", PROMPTS_DIR, filename)
          return File.read(project_path, encoding: "UTF-8") if File.exist?(project_path)
        end

        # 2. Global override
        global_path = File.join(@global_dir, filename)
        return File.read(global_path, encoding: "UTF-8") if File.exist?(global_path)

        # 3. Bundled default
        bundled_path = File.join(@bundled_dir, filename)
        return File.read(bundled_path, encoding: "UTF-8") if File.exist?(bundled_path)

        nil
      end

      # Compile a Liquid template from source.
      #
      # @param source [String] template source
      # @param name [String] template name (for error messages)
      # @return [Liquid::Template]
      # @raise [AgentDesk::TemplateSyntaxError] on Liquid parse errors
      def compile_template(source, name)
        template = Liquid::Template.parse(source, environment: self.class.environment)
      rescue Liquid::SyntaxError => e
        raise AgentDesk::TemplateSyntaxError,
              "Liquid syntax error in '#{name}#{TEMPLATE_EXT}': #{e.message}"
      end

      # Default path to bundled templates directory.
      #
      # @return [String]
      def default_templates_dir
        File.expand_path("../../../templates", __dir__)
      end
    end
  end
end
