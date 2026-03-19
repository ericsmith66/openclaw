# PRD-0040: Agent Profile System

**PRD ID**: PRD-0040
**Status**: Draft
**Priority**: High
**Created**: 2026-02-26
**Milestone**: M2 (Profiles)
**Depends On**: PRD-0010, PRD-0020

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/common/types.ts:425-451` — `AgentProfile` interface (full shape)
- `src/common/agent.ts` — `DEFAULT_AGENT_PROFILE`, `DEFAULT_AGENT_PROFILES[]`, provider defaults
- `src/main/agent/agent-profile-manager.ts` — Load/save/watch profiles from filesystem, rule file discovery
- `src/main/agent/agent.ts:350-447` — `buildToolSet` reads profile flags to decide which tool groups to include

**Output Files** (Ruby):
- `lib/agent_desk/agent/profile.rb` — Profile data structure + defaults
- `lib/agent_desk/agent/profile_manager.rb` — Load/save/watch from filesystem
- `spec/agent_desk/agent/profile_spec.rb`
- `spec/agent_desk/agent/profile_manager_spec.rb`

---

## 1. Problem Statement

Different tasks need different agent configurations:
- A "read-only analysis" agent should have file_read but not file_write
- A "full coding" agent needs bash, file_edit, and aider tools
- A "QA" subagent needs minimal tools and a focused system prompt

AiderDesk solves this with **Agent Profiles** — JSON config files stored on disk that define:
- Which LLM provider/model to use
- Which tool groups are enabled (power, aider, todo, memory, skills, subagents, tasks)
- Per-tool approval state (always/ask/never)
- Per-tool settings (e.g., bash allowed/denied command patterns)
- Custom instructions, max iterations, enabled MCP servers
- Subagent configuration (if this profile can be used as a subagent)
- Rule file paths (discovered from filesystem)

---

## 2. Design

### 2.1 Profile Data Structure

```ruby
# lib/agent_desk/agent/profile.rb
module AgentDesk
  module Agent
    class Profile
      attr_accessor :id, :name, :provider, :model,
                    :project_dir,                    # nil = global, set = project-level
                    :max_iterations, :max_tokens, :temperature,
                    :min_time_between_tool_calls,
                    :enabled_servers,                # Array<String> — MCP server names
                    :tool_approvals,                 # Hash<String, ToolApprovalState>
                    :tool_settings,                  # Hash<String, Hash>
                    :include_context_files, :include_repo_map,
                    :use_power_tools, :use_aider_tools, :use_todo_tools,
                    :use_subagents, :use_task_tools, :use_memory_tools,
                    :use_skills_tools,
                    :custom_instructions,
                    :subagent,                       # SubagentConfig
                    :is_subagent,                    # bool
                    :rule_files                      # Array<String> — absolute paths, populated at load time

      def initialize(**attrs)
        defaults = self.class.default_attributes
        defaults.merge(attrs).each { |k, v| send(:"#{k}=", v) }
      end

      def self.default_attributes
        {
          id: 'default',
          name: 'Default Agent',
          provider: 'anthropic',
          model: 'claude-sonnet-4-5-20250929',
          project_dir: nil,
          max_iterations: 250,
          max_tokens: nil,
          temperature: nil,
          min_time_between_tool_calls: 0,
          enabled_servers: [],
          tool_approvals: default_tool_approvals,
          tool_settings: default_tool_settings,
          include_context_files: false,
          include_repo_map: false,
          use_power_tools: true,
          use_aider_tools: false,
          use_todo_tools: true,
          use_subagents: true,
          use_task_tools: false,
          use_memory_tools: true,
          use_skills_tools: true,
          custom_instructions: '',
          subagent: SubagentConfig.new,
          is_subagent: false,
          rule_files: []
        }
      end

      def self.default_tool_approvals
        {
          # Power tools
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FILE_READ) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FILE_EDIT) => ToolApprovalState::ASK,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FILE_WRITE) => ToolApprovalState::ASK,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_GLOB) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_GREP) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_SEMANTIC_SEARCH) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_BASH) => ToolApprovalState::ASK,
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_FETCH) => ToolApprovalState::ALWAYS,
          # Skills
          AgentDesk.tool_id(SKILLS_TOOL_GROUP_NAME, SKILLS_TOOL_ACTIVATE_SKILL) => ToolApprovalState::ALWAYS,
          # Memory
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_STORE) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_RETRIEVE) => ToolApprovalState::ALWAYS,
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_DELETE) => ToolApprovalState::NEVER,
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_LIST) => ToolApprovalState::NEVER,
          AgentDesk.tool_id(MEMORY_TOOL_GROUP_NAME, MEMORY_TOOL_UPDATE) => ToolApprovalState::NEVER,
          # Todo
          # (todo tools use always by default — omitted for brevity, same pattern)
        }
      end

      def self.default_tool_settings
        {
          AgentDesk.tool_id(POWER_TOOL_GROUP_NAME, POWER_TOOL_BASH) => {
            'allowed_pattern' => 'ls .*;cat .*;git status;git show;git log',
            'denied_pattern'  => 'rm .*;del .*;chown .*;chgrp .*;chmod .*'
          }
        }
      end

      # Serialize to JSON (for saving to disk — excludes runtime-only fields)
      def to_json_hash
        attrs = instance_variables.each_with_object({}) do |var, h|
          key = var.to_s.delete_prefix('@')
          next if key == 'rule_files' # runtime-discovered, not persisted
          h[key] = instance_variable_get(var)
        end
        attrs['subagent'] = subagent.to_h if subagent.respond_to?(:to_h)
        attrs
      end
    end
  end
end
```

### 2.2 ProfileManager

Loads profiles from filesystem (matching AiderDesk's directory structure), watches for changes.

```ruby
# lib/agent_desk/agent/profile_manager.rb
module AgentDesk
  module Agent
    class ProfileManager
      AIDER_DESK_DIR = '.aider-desk'
      AGENTS_DIR = 'agents'
      CONFIG_FILE = 'config.json'
      RULES_DIR = 'rules'

      attr_reader :global_profiles, :project_profiles

      def initialize(global_dir: nil)
        @global_dir = global_dir || File.join(Dir.home, AIDER_DESK_DIR, AGENTS_DIR)
        @global_profiles = []
        @project_profiles = {} # project_dir => [Profile]
      end

      def load_global_profiles
        @global_profiles = load_profiles_from(@global_dir)
      end

      def load_project_profiles(project_dir)
        agents_dir = File.join(project_dir, AIDER_DESK_DIR, AGENTS_DIR)
        profiles = load_profiles_from(agents_dir, project_dir: project_dir)
        @project_profiles[project_dir] = profiles
        profiles
      end

      # Returns all profiles for a project (project + global)
      def profiles_for(project_dir)
        project = @project_profiles.fetch(project_dir, [])
        project + @global_profiles
      end

      # Find by ID
      def find(id, project_dir: nil)
        if project_dir
          profiles_for(project_dir).find { |p| p.id == id }
        else
          @global_profiles.find { |p| p.id == id }
        end
      end

      # Find by name (case-insensitive)
      def find_by_name(name, project_dir: nil)
        profiles = project_dir ? profiles_for(project_dir) : @global_profiles
        profiles.find { |p| p.name.downcase == name.downcase }
      end

      private

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

      def load_profile(config_path, dir_name, project_dir: nil)
        json = JSON.parse(File.read(config_path), symbolize_names: false)
        profile = Profile.new(**symbolize_keys(json))
        profile.project_dir = project_dir

        # Discover rule files
        profile.rule_files = discover_rule_files(dir_name, project_dir)
        profile
      rescue JSON::ParserError, StandardError => e
        warn "Failed to load profile from #{config_path}: #{e.message}"
        nil
      end

      def discover_rule_files(dir_name, project_dir)
        paths = []

        # Global agent rules
        global_rules_dir = File.join(@global_dir, dir_name, RULES_DIR)
        paths.concat(md_files_in(global_rules_dir))

        if project_dir
          # Project-level rules (shared for all agents)
          project_rules_dir = File.join(project_dir, AIDER_DESK_DIR, 'rules')
          paths.concat(md_files_in(project_rules_dir))

          # Project agent-specific rules
          project_agent_rules = File.join(project_dir, AIDER_DESK_DIR, AGENTS_DIR, dir_name, RULES_DIR)
          paths.concat(md_files_in(project_agent_rules))
        end

        paths
      end

      def md_files_in(dir)
        return [] unless File.directory?(dir)
        Dir.glob(File.join(dir, '*.md')).sort
      end

      def symbolize_keys(hash)
        hash.transform_keys { |k| k.to_s.gsub(/([A-Z])/, '_\1').downcase.delete_prefix('_').to_sym }
      end
    end
  end
end
```

---

## 3. Acceptance Criteria

- ✅ `Profile.new` creates a profile with all defaults matching AiderDesk's `DEFAULT_AGENT_PROFILE`
- ✅ `Profile.new(use_power_tools: false)` overrides only that field
- ✅ `ProfileManager#load_global_profiles` reads from `~/.aider-desk/agents/*/config.json`
- ✅ `ProfileManager#load_project_profiles` reads from `{project}/.aider-desk/agents/*/config.json`
- ✅ Rule files discovered from global/project/agent rule directories
- ✅ `find_by_name` is case-insensitive (matches AiderDesk's profile name lookup)
- ✅ `to_json_hash` excludes `rule_files` (they're runtime-discovered)

---

## 4. Test Plan

```ruby
RSpec.describe AgentDesk::Agent::Profile do
  it 'creates with sensible defaults' do
    profile = described_class.new
    expect(profile.use_power_tools).to be true
    expect(profile.use_aider_tools).to be false
    expect(profile.max_iterations).to eq(250)
    expect(profile.tool_approvals[AgentDesk.tool_id('power', 'bash')]).to eq('ask')
  end

  it 'allows attribute overrides' do
    profile = described_class.new(name: 'QA Agent', use_power_tools: false)
    expect(profile.name).to eq('QA Agent')
    expect(profile.use_power_tools).to be false
  end
end

RSpec.describe AgentDesk::Agent::ProfileManager do
  it 'loads profiles from a directory', :tmpdir do
    # Create a profile directory structure in tmp
    agents_dir = File.join(tmpdir, '.aider-desk', 'agents', 'test-agent')
    FileUtils.mkdir_p(agents_dir)
    File.write(File.join(agents_dir, 'config.json'), '{"id":"test","name":"Test"}')

    mgr = described_class.new(global_dir: File.join(tmpdir, '.aider-desk', 'agents'))
    mgr.load_global_profiles
    expect(mgr.global_profiles.size).to eq(1)
    expect(mgr.global_profiles.first.name).to eq('Test')
  end

  it 'discovers rule files' do
    # Setup rule files in tmp dirs and verify they're found
  end
end
```

---

## 5. AiderDesk Mapping

| Ruby | AiderDesk |
|------|-----------|
| `Profile` | `AgentProfile` (interface in `types.ts`) |
| `Profile.default_attributes` | `DEFAULT_AGENT_PROFILE` in `agent.ts` |
| `Profile#tool_approvals` | `agentProfile.toolApprovals` |
| `ProfileManager` | `AgentProfileManager` class |
| `ProfileManager#discover_rule_files` | `getAllRuleFilesForProfile()` + `getRuleFilesForAgent()` |
| `ProfileManager#find_by_name` | Profile lookup by name (case-insensitive) |
| Directory: `~/.aider-desk/agents/{name}/config.json` | Same filesystem layout |

---

**Next**: PRD-0050 (Power Tools) implements the actual tool group that uses profiles to determine availability.
