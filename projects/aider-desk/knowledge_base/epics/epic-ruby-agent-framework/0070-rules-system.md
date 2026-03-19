# PRD-0070: Rules System

**PRD ID**: PRD-0070
**Status**: Draft
**Priority**: Medium
**Created**: 2026-02-26
**Milestone**: M4 (Prompt System)
**Depends On**: PRD-0060

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/agent/agent-profile-manager.ts:23-60` — `getRuleFilesForAgent`, `getAllRuleFilesForProfile`
- `src/main/prompts/prompts-manager.ts` — `getRulesContent` (reads rule files, wraps in CDATA XML)
- `docs-site/docs/configuration/project-specific-rules.md` — Full documentation of rule precedence

**Output Files** (Ruby):
- `lib/agent_desk/rules/rules_loader.rb`
- `spec/agent_desk/rules/rules_loader_spec.rb`

---

## 1. Problem Statement

The agent needs project-specific instructions beyond the system prompt template. Rules are markdown files that contain:
- Coding conventions, architectural guidelines
- Do's and don'ts for the project
- Agent-specific behavioral instructions

AiderDesk loads rules from three locations in precedence order:
1. **Global agent rules**: `~/.aider-desk/agents/{profile_dir}/rules/*.md`
2. **Project rules**: `{project}/.aider-desk/rules/*.md` (shared by all agents)
3. **Project agent rules**: `{project}/.aider-desk/agents/{profile_dir}/rules/*.md`

All are concatenated and injected into the `<Knowledge><Rules>` section of the system prompt.

---

## 2. Design

```ruby
# lib/agent_desk/rules/rules_loader.rb
module AgentDesk
  module Rules
    class RulesLoader
      AIDER_DESK_DIR = '.aider-desk'
      RULES_DIR = 'rules'
      AGENTS_DIR = 'agents'

      def initialize(global_agents_dir: nil)
        @global_agents_dir = global_agents_dir || File.join(Dir.home, AIDER_DESK_DIR, AGENTS_DIR)
      end

      # Returns array of absolute paths to rule files for a given profile + project
      def rule_file_paths(profile_dir_name:, project_dir: nil)
        paths = []

        # 1. Global agent rules
        global_rules = File.join(@global_agents_dir, profile_dir_name, RULES_DIR)
        paths.concat(md_files_in(global_rules))

        if project_dir
          # 2. Project-wide rules (shared by all agents)
          project_rules = File.join(project_dir, AIDER_DESK_DIR, RULES_DIR)
          paths.concat(md_files_in(project_rules))

          # 3. Project agent-specific rules
          project_agent_rules = File.join(project_dir, AIDER_DESK_DIR, AGENTS_DIR, profile_dir_name, RULES_DIR)
          paths.concat(md_files_in(project_agent_rules))
        end

        paths
      end

      # Load and format rule files as XML fragments for system prompt injection
      # Returns a string like:
      #   <File name="AGENTS.md"><![CDATA[...content...]]></File>
      #   <File name="CONVENTIONS.md"><![CDATA[...content...]]></File>
      def load_rules_content(profile_dir_name:, project_dir: nil)
        paths = rule_file_paths(profile_dir_name: profile_dir_name, project_dir: project_dir)

        fragments = paths.filter_map do |path|
          content = File.read(path)
          filename = File.basename(path)
          "      <File name=\"#{filename}\"><![CDATA[\n#{content}\n]]></File>"
        rescue StandardError => e
          warn "Failed to read rule file #{path}: #{e.message}"
          nil
        end

        fragments.join("\n")
      end

      private

      def md_files_in(dir)
        return [] unless File.directory?(dir)
        Dir.glob(File.join(dir, '*.md')).sort
      end
    end
  end
end
```

---

## 3. Acceptance Criteria

- ✅ Discovers rule files from all three locations in correct precedence
- ✅ Returns empty when no rule directories exist
- ✅ Formats content as CDATA-wrapped XML fragments matching AiderDesk's format
- ✅ Gracefully handles unreadable files (logs warning, skips)
- ✅ Works with both global-only and project-level profiles

---

## 4. Test Plan

```ruby
RSpec.describe AgentDesk::Rules::RulesLoader do
  let(:tmpdir) { Dir.mktmpdir }
  let(:loader) { described_class.new(global_agents_dir: File.join(tmpdir, 'global-agents')) }

  after { FileUtils.remove_entry(tmpdir) }

  it 'discovers project rules' do
    rules_dir = File.join(tmpdir, 'project', '.aider-desk', 'rules')
    FileUtils.mkdir_p(rules_dir)
    File.write(File.join(rules_dir, 'conventions.md'), '# Conventions')

    paths = loader.rule_file_paths(profile_dir_name: 'default', project_dir: File.join(tmpdir, 'project'))
    expect(paths.size).to eq(1)
    expect(paths.first).to end_with('conventions.md')
  end

  it 'formats rules as CDATA XML' do
    rules_dir = File.join(tmpdir, 'project', '.aider-desk', 'rules')
    FileUtils.mkdir_p(rules_dir)
    File.write(File.join(rules_dir, 'rules.md'), 'Use snake_case')

    content = loader.load_rules_content(profile_dir_name: 'default', project_dir: File.join(tmpdir, 'project'))
    expect(content).to include('<![CDATA[')
    expect(content).to include('Use snake_case')
  end

  it 'returns empty string when no rules exist' do
    content = loader.load_rules_content(profile_dir_name: 'nonexistent', project_dir: '/nonexistent')
    expect(content).to eq('')
  end
end
```

---

**Next**: PRD-0080 (Skills System) adds dynamic capability discovery from markdown files.
