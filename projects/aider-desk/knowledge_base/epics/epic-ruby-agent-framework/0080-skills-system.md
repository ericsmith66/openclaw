# PRD-0080: Skills System

**PRD ID**: PRD-0080
**Status**: Draft
**Priority**: Medium
**Created**: 2026-02-26
**Milestone**: M5 (Skills & Memory)
**Depends On**: PRD-0020, PRD-0060

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/agent/tools/skills.ts` — `loadSkillsFromDir`, `getActivateSkillDescription`, `createSkillsToolset`
- `docs-site/docs/features/skills.md` — User-facing documentation
- `.aider-desk/skills/*/SKILL.md` — Skill definition format (YAML frontmatter + markdown body)

**Output Files** (Ruby):
- `lib/agent_desk/skills/skill.rb` — Skill data structure
- `lib/agent_desk/skills/skill_loader.rb` — Filesystem discovery
- `lib/agent_desk/tools/skills_tools.rb` — The `activate_skill` tool
- `spec/agent_desk/skills/skill_loader_spec.rb`
- `spec/agent_desk/tools/skills_tools_spec.rb`

---

## 1. Problem Statement

Skills are modular capability packages that the agent discovers and activates at runtime. Each skill is a directory containing a `SKILL.md` file with:
- **YAML frontmatter**: `name` and `description`
- **Markdown body**: Detailed instructions the LLM follows when the skill is activated

Skills are loaded from:
1. **Global**: `~/.aider-desk/skills/*/SKILL.md`
2. **Project**: `{project}/.aider-desk/skills/*/SKILL.md`

The `activate_skill` tool:
1. Lists all discovered skills in its description (so the LLM knows what's available)
2. When called, reads the SKILL.md content and returns it as the tool result
3. This injects the skill's instructions into the conversation context

---

## 2. Design

### 2.1 Skill Data Structure

```ruby
# lib/agent_desk/skills/skill.rb
module AgentDesk
  module Skills
    Skill = Data.define(:name, :description, :dir_path, :location) do
      # location is :global or :project
    end
  end
end
```

### 2.2 SkillLoader

```ruby
# lib/agent_desk/skills/skill_loader.rb
module AgentDesk
  module Skills
    class SkillLoader
      SKILL_FILE = 'SKILL.md'
      SKILLS_DIR = 'skills'
      AIDER_DESK_DIR = '.aider-desk'

      def initialize(global_dir: nil)
        @global_dir = global_dir || File.join(Dir.home, AIDER_DESK_DIR, SKILLS_DIR)
      end

      def load_all(project_dir: nil)
        skills = []
        skills.concat(load_from_dir(@global_dir, :global))
        if project_dir
          project_skills_dir = File.join(project_dir, AIDER_DESK_DIR, SKILLS_DIR)
          skills.concat(load_from_dir(project_skills_dir, :project))
        end
        skills
      end

      def read_skill_content(skill)
        skill_md_path = File.join(skill.dir_path, SKILL_FILE)
        File.read(skill_md_path)
      end

      private

      def load_from_dir(dir, location)
        return [] unless File.directory?(dir)

        Dir.children(dir).filter_map do |entry|
          entry_path = File.join(dir, entry)
          next unless File.directory?(entry_path)

          skill_file = File.join(entry_path, SKILL_FILE)
          next unless File.exist?(skill_file)

          parse_skill(skill_file, entry_path, location)
        end
      end

      def parse_skill(skill_file, dir_path, location)
        content = File.read(skill_file)

        # Parse YAML frontmatter (between --- delimiters)
        if content.match?(/\A---\s*\n/)
          parts = content.split(/^---\s*$/, 3)
          if parts.length >= 3
            frontmatter = YAML.safe_load(parts[1]) || {}
            return Skill.new(
              name: frontmatter['name'] || File.basename(dir_path),
              description: frontmatter['description'] || '',
              dir_path: dir_path,
              location: location
            )
          end
        end

        # Fallback: use directory name as skill name
        Skill.new(name: File.basename(dir_path), description: '', dir_path: dir_path, location: location)
      rescue StandardError => e
        warn "Failed to parse skill at #{skill_file}: #{e.message}"
        nil
      end
    end
  end
end
```

### 2.3 Skills Tool (activate_skill)

```ruby
# lib/agent_desk/tools/skills_tools.rb
module AgentDesk
  module Tools
    module SkillsTools
      def self.create(project_dir:, skill_loader: Skills::SkillLoader.new)
        all_skills = skill_loader.load_all(project_dir: project_dir)
        description = build_description(all_skills)

        Tools.build_group(SKILLS_TOOL_GROUP_NAME) do
          tool SKILLS_TOOL_ACTIVATE_SKILL,
               description: description,
               input_schema: {
                 properties: {
                   skill: { type: 'string', description: 'The skill name to activate.' }
                 },
                 required: ['skill']
               } do |args, _ctx|
            requested_name = args['skill']
            skill = all_skills.find { |s| s.name == requested_name }

            unless skill
              available = all_skills.map(&:name).join(', ')
              next "Skill '#{requested_name}' not found. Available skills: #{available.empty? ? '(none)' : available}."
            end

            content = skill_loader.read_skill_content(skill)
            "#{content}\n\nSkill '#{skill.name}' activated.\nSkill directory is #{skill.dir_path}"
          end
        end
      end

      def self.build_description(skills)
        instructions = <<~TEXT
          Execute a skill within the main conversation

          <skills_instructions>
          When users ask you to perform tasks, check if any of the available skills below can help.
          Use this tool with the skill name only (no arguments).

          Important:
          - When a skill is relevant, invoke this tool IMMEDIATELY as your first action
          - Only use skills listed in <available_skills> below
          </skills_instructions>
        TEXT

        available = skills.map do |s|
          "<skill>\n<name>\n#{s.name}\n</name>\n<description>\n#{s.description}\n</description>\n<location>\n#{s.location}\n</location>\n</skill>"
        end.join("\n")

        "#{instructions}\n<available_skills>\n#{available}\n</available_skills>"
      end
    end
  end
end
```

---

## 3. Acceptance Criteria

- ✅ `SkillLoader#load_all` discovers skills from both global and project directories
- ✅ YAML frontmatter parsed for name and description
- ✅ Falls back to directory name when frontmatter is missing
- ✅ `activate_skill` tool's description lists all available skills
- ✅ Executing `activate_skill` returns the SKILL.md content
- ✅ Non-existent skill returns helpful error with available skills listed

---

## 4. Test Plan

```ruby
RSpec.describe AgentDesk::Skills::SkillLoader do
  let(:tmpdir) { Dir.mktmpdir }
  let(:loader) { described_class.new(global_dir: File.join(tmpdir, 'global-skills')) }

  after { FileUtils.remove_entry(tmpdir) }

  it 'loads skills with frontmatter' do
    skill_dir = File.join(tmpdir, 'project', '.aider-desk', 'skills', 'test-skill')
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), "---\nname: test-skill\ndescription: A test\n---\n# Instructions")

    skills = loader.load_all(project_dir: File.join(tmpdir, 'project'))
    expect(skills.size).to eq(1)
    expect(skills.first.name).to eq('test-skill')
    expect(skills.first.description).to eq('A test')
  end
end

RSpec.describe AgentDesk::Tools::SkillsTools do
  it 'creates activate_skill tool that returns skill content' do
    # Setup skill on disk, create tool set, execute
  end
end
```

---

## 5. AiderDesk Mapping

| Ruby | AiderDesk |
|------|-----------|
| `SkillLoader#load_all` | `loadSkillsFromDir(globalSkillsDir)` + `loadSkillsFromDir(projectSkillsDir)` |
| `SkillLoader#parse_skill` | YAML frontmatter parsing in `skills.ts` |
| `SkillsTools.build_description` | `getActivateSkillDescription(skills)` |
| `activate_skill` execute | `activateSkillTool.execute` (reads SKILL.md, returns content) |
| `Skill` data class | `{ name, description, dirPath, location }` object |

---

**Next**: PRD-0090 (Agent Runner Loop) ties everything together into the LLM execution loop.
