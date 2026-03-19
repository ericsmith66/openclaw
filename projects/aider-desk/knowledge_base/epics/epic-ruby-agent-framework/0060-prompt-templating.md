# PRD-0060: Prompt Templating & System Prompt Assembly

**PRD ID**: PRD-0060
**Status**: Draft
**Priority**: High
**Created**: 2026-02-26
**Milestone**: M4 (Prompt System)
**Depends On**: PRD-0010, PRD-0040

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/prompts/prompts-manager.ts` — Template compilation, rendering, global/project override chain
- `src/main/prompts/types.ts` — `PromptTemplateData`, `ToolPermissions`
- `resources/prompts/system-prompt.hbs` — Main system prompt template (XML structure)
- `resources/prompts/workflow.hbs` — Workflow steps sub-template
- `src/main/prompts/helpers/` — Handlebars helpers (formatting, conditionals, CDATA)

**Output Files** (Ruby):
- `lib/agent_desk/prompts/prompts_manager.rb`
- `lib/agent_desk/prompts/types.rb`
- `templates/system-prompt.hbs` (or `.liquid`)
- `templates/workflow.hbs`
- `spec/agent_desk/prompts/prompts_manager_spec.rb`

---

## 1. Problem Statement

The system prompt is the most critical piece of the agent framework — it tells the LLM:
- What persona to adopt
- Which tools are available and how to use them
- What workflow to follow
- What rules and custom instructions apply
- Project context (directory, OS, date)

AiderDesk assembles this from Handlebars templates with conditional sections based on the profile's enabled tool groups. The template system supports:
1. **Default templates** bundled with the gem
2. **Global overrides** in `~/.aider-desk/prompts/`
3. **Project overrides** in `{project}/.aider-desk/prompts/`
4. **Hot-reloading** when template files change on disk

---

## 2. Design

### 2.1 ToolPermissions (from profile)

A computed struct that the template uses to conditionally include sections:

```ruby
# lib/agent_desk/prompts/types.rb
module AgentDesk
  module Prompts
    ToolPermissions = Data.define(
      :aider_tools,
      :power_tools,      # Hash with :file_read, :file_write, :bash, :any_enabled, etc.
      :todo_tools,
      :subagents,
      :memory,           # Hash with :enabled, :retrieve_allowed, :store_allowed, etc.
      :skills,           # Hash with :allowed
      :auto_approve
    )

    PromptTemplateData = Data.define(
      :project_dir, :task_dir, :os_name, :current_date,
      :rules_files, :custom_instructions,
      :tool_permissions, :tool_constants,
      :workflow,    # Pre-rendered workflow sub-template
      :project_git_root_directory
    )
  end
end
```

### 2.2 PromptsManager

```ruby
# lib/agent_desk/prompts/prompts_manager.rb
module AgentDesk
  module Prompts
    class PromptsManager
      TEMPLATE_NAMES = %w[
        system-prompt workflow compact-conversation
        commit-message task-name
      ].freeze

      def initialize(
        default_templates_dir: File.join(__dir__, '..', '..', '..', 'templates'),
        global_prompts_dir: File.join(Dir.home, '.aider-desk', 'prompts')
      )
        @default_templates_dir = default_templates_dir
        @global_prompts_dir = global_prompts_dir
        @global_templates = {}
        @project_templates = {} # project_dir => { name => compiled_template }
      end

      def init
        compile_global_templates
      end

      def watch_project(project_dir)
        compile_project_templates(project_dir)
        # TODO: file watcher with `listen` gem for hot-reload
      end

      # Main entry point: render the system prompt for a given profile + task context
      def system_prompt(profile:, project_dir:, task_dir: nil, rules_content: '', custom_instructions: '')
        task_dir ||= project_dir
        tool_permissions = calculate_tool_permissions(profile)

        data = build_template_data(
          profile: profile,
          project_dir: project_dir,
          task_dir: task_dir,
          tool_permissions: tool_permissions,
          rules_content: rules_content,
          custom_instructions: custom_instructions
        )

        # Render workflow sub-template first
        data_hash = data_to_hash(data)
        data_hash['workflow'] = render('workflow', data_hash, project_dir)

        render('system-prompt', data_hash, project_dir)
      end

      private

      def compile_global_templates
        @global_templates.clear
        TEMPLATE_NAMES.each do |name|
          source = load_template_source(name)
          @global_templates[name] = compile(source) if source
        end
      end

      def compile_project_templates(project_dir)
        project = {}
        prompts_dir = File.join(project_dir, '.aider-desk', 'prompts')
        TEMPLATE_NAMES.each do |name|
          path = File.join(prompts_dir, "#{name}.hbs")
          next unless File.exist?(path)
          project[name] = compile(File.read(path))
        end
        @project_templates[project_dir] = project unless project.empty?
      end

      def load_template_source(name)
        # Check global override first
        global_path = File.join(@global_prompts_dir, "#{name}.hbs")
        return File.read(global_path) if File.exist?(global_path)

        # Fall back to bundled default
        default_path = File.join(@default_templates_dir, "#{name}.hbs")
        return File.read(default_path) if File.exist?(default_path)

        nil
      end

      def render(name, data, project_dir = nil)
        # Project override takes precedence
        if project_dir && @project_templates.dig(project_dir, name)
          return @project_templates[project_dir][name].call(data)
        end

        template = @global_templates[name]
        raise "Template '#{name}' not found" unless template
        template.call(data)
      end

      def compile(source)
        # Use Handlebars or Liquid — implementation detail
        # For now, simple ERB-style or Handlebars.rb
        # Handlebars.compile(source)
        raise NotImplementedError, 'Template engine integration needed'
      end

      def calculate_tool_permissions(profile)
        is_allowed = ->(tool_id) { profile.tool_approvals[tool_id] != ToolApprovalState::NEVER }

        power = {
          file_read: profile.use_power_tools && is_allowed.call(AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FILE_READ)),
          file_write: profile.use_power_tools && is_allowed.call(AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FILE_WRITE)),
          file_edit: profile.use_power_tools && is_allowed.call(AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FILE_EDIT)),
          glob: profile.use_power_tools && is_allowed.call(AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_GLOB)),
          grep: profile.use_power_tools && is_allowed.call(AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_GREP)),
          bash: profile.use_power_tools && is_allowed.call(AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_BASH)),
          semantic_search: profile.use_power_tools && is_allowed.call(AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_SEMANTIC_SEARCH)),
        }
        power[:any_enabled] = power.values.any?

        memory = {
          enabled: profile.use_memory_tools,
          retrieve_allowed: profile.use_memory_tools && is_allowed.call(AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_RETRIEVE)),
          store_allowed: profile.use_memory_tools && is_allowed.call(AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_STORE)),
        }

        ToolPermissions.new(
          aider_tools: profile.use_aider_tools,
          power_tools: power,
          todo_tools: profile.use_todo_tools,
          subagents: profile.use_subagents,
          memory: memory,
          skills: { allowed: profile.use_skills_tools },
          auto_approve: false
        )
      end

      def build_template_data(profile:, project_dir:, task_dir:, tool_permissions:, rules_content:, custom_instructions:)
        PromptTemplateData.new(
          project_dir: project_dir,
          task_dir: task_dir,
          os_name: RUBY_PLATFORM,
          current_date: Time.now.strftime('%a %b %d %Y'),
          rules_files: rules_content,
          custom_instructions: custom_instructions,
          tool_permissions: tool_permissions,
          tool_constants: AgentDesk.constants_hash,
          workflow: '', # filled after first render pass
          project_git_root_directory: task_dir != project_dir ? project_dir : nil
        )
      end

      def data_to_hash(data)
        # Convert Data.define to nested hash for template rendering
        # (implementation depends on template engine)
        {}
      end
    end
  end
end
```

### 2.3 Template Structure

The system prompt template mirrors AiderDesk's XML structure. The key sections, conditionally included:

```
<AiderDeskSystemPrompt>
  <Agent> ... persona/objective ...
  <CoreDirectives> ... always present ...
  <ToolUsageGuidelines> ... always present ...
  {{#if subagents}} <SubagentsProtocol> ... {{/if}}
  {{#if todoTools}} <TodoManagement> ... {{/if}}
  {{#if memory.enabled}} <MemoryTools> ... {{/if}}
  {{#if aiderTools}} <AiderTools> ... {{/if}}
  {{#if powerTools.anyEnabled}} <PowerTools> ... {{/if}}
  <ResponseStyle> ...
  <SystemInformation> date, OS, project dir ...
  <Knowledge>
    <Rules> ... rule file contents ... </Rules>
    <CustomInstructions> ... </CustomInstructions>
  </Knowledge>
  {{{workflow}}}
</AiderDeskSystemPrompt>
```

---

## 3. Acceptance Criteria

- ✅ `PromptsManager#system_prompt` renders a valid XML-structured system prompt
- ✅ Conditional sections included/excluded based on profile's enabled tool groups
- ✅ Rules content injected into `<Knowledge><Rules>` section
- ✅ Custom instructions injected into `<Knowledge><CustomInstructions>`
- ✅ Template override chain: project > global > default
- ✅ Workflow sub-template rendered and embedded
- ✅ All tool constants available in template context

---

## 4. Test Plan

```ruby
RSpec.describe AgentDesk::Prompts::PromptsManager do
  let(:profile) { AgentDesk::Agent::Profile.new(use_power_tools: true, use_todo_tools: false) }

  it 'includes power tools section when enabled' do
    # After template engine is wired up:
    prompt = manager.system_prompt(profile: profile, project_dir: '/tmp/test')
    expect(prompt).to include('<PowerTools')
    expect(prompt).not_to include('<TodoManagement')
  end

  it 'injects rules content' do
    prompt = manager.system_prompt(
      profile: profile, project_dir: '/tmp/test',
      rules_content: '<File name="RULES.md">Do not use eval</File>'
    )
    expect(prompt).to include('Do not use eval')
  end
end
```

---

## 5. Template Engine Decision

**Options**:
- `handlebars.rb` — Direct port, same syntax as AiderDesk's `.hbs` files
- `liquid` — More Ruby-native, widely used (Jekyll, Shopify), safe sandboxed
- `ERB` — Built-in Ruby, no gem needed, but less safe and different syntax

**Recommendation**: Start with `liquid` (more idiomatic Ruby, safer) and port the `.hbs` template syntax to Liquid equivalents. The conditional structure (`{{#if ...}}`) maps cleanly to Liquid's `{% if ... %}`.

If exact AiderDesk template compatibility is desired (sharing `.hbs` files), use `handlebars.rb` instead.

---

**Next**: PRD-0070 (Rules System) loads the rule file content that gets injected into the prompt.
