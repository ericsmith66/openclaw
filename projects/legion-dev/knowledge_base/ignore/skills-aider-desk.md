### How Skills Are Activated and Invoked in AiderDesk

Yes — skills **are given to the LLM as tools**. Here's the complete flow:

---

#### Step 1: Discovery — Loading Skills from Filesystem

Skills are discovered from two directories (`src/main/agent/tools/skills.ts`, lines 56–94):

- **Global**: `~/.aider-desk/skills/*/SKILL.md`
- **Project**: `{projectDir}/.aider-desk/skills/*/SKILL.md`

Each `SKILL.md` file has **YAML frontmatter** with `name` and `description` fields, parsed via `yaml-front-matter`:

```yaml
---
name: pdf
description: Extract and analyze PDF documents
---
# Skill instructions in markdown...
```

---

#### Step 2: Registration — Skills Become an LLM Tool

When the agent profile has `useSkillsTools: true` (line 433 of `agent.ts`), the skills system creates a **single tool** called `skills---activate_skill` and adds it to the LLM's toolset:

```typescript
if (profile.useSkillsTools) {
  const skillsTools = await createSkillsToolset(task, profile, promptContext);
  Object.assign(toolSet, skillsTools);
}
```

This tool is registered using the Vercel AI SDK's `tool()` function with:
- **Input schema**: `{ skill: string }` — just the skill name
- **Description**: A detailed prompt that lists ALL available skills with their names, descriptions, and locations inside `<available_skills>` XML tags

The description given to the LLM looks like this (lines 97–107):

```
Execute a skill within the main conversation

<skills_instructions>
When users ask you to perform tasks, check if any of the available skills
below can help complete the task more effectively...

How to invoke:
- Use this tool with the skill name only (no arguments)
- Example: {"skill": "pdf"}

Important:
- When a skill is relevant, you must invoke this tool IMMEDIATELY as your first action
- NEVER just announce or mention a skill in your text response without actually calling this tool
</skills_instructions>

<available_skills>
<skill>
<name>pdf</name>
<description>Extract and analyze PDF documents</description>
<location>global</location>
</skill>
...
</available_skills>
```

---

#### Step 3: Activation — What Happens When the LLM Calls the Tool

When the LLM decides to use a skill and calls `skills---activate_skill` with `{"skill": "pdf"}`, the execute function (lines 126–161):

1. **Approval gate**: Checks with the `ApprovalManager` — if the tool approval is set to "ask", the user gets a prompt: *"Approve activating a skill? Skill: pdf"*. If denied, returns a denial message.

2. **Skill lookup**: Re-scans both global and project skill directories to find the matching skill by name.

3. **Content injection**: Reads the **full `SKILL.md` content** (including the markdown body with all instructions) and returns it as the tool result:

```typescript
return `${content}\n\nSkill '${requested.name}' activated.\nSkill directory is ${requested.dirPath} - use it as parent directory for relative paths mentioned in the skill description.`;
```

This means the **entire skill document gets injected into the conversation context** as a tool response. The LLM then follows the instructions in that markdown to complete the task.

---

#### Step 4: Filtering — Approval Controls

Before any tool is exposed to the LLM, it's filtered by the profile's `toolApprovals` setting (lines 168–175):

```typescript
if (profile.toolApprovals[toolId] !== ToolApprovalState.Never) {
  filteredTools[toolId] = toolInstance;
}
```

Three states: **Always** (auto-approve), **Ask** (prompt user), **Never** (tool hidden from LLM entirely).

---

### Summary Flow

```
Filesystem (SKILL.md files)
    ↓ loadSkillsFromDir()
Skill metadata (name, description)
    ↓ getActivateSkillDescription()
Single tool description with all skills listed
    ↓ registered as skills---activate_skill
LLM sees tool in its toolset
    ↓ LLM calls {"skill": "pdf"}
Approval check → Read full SKILL.md → Return content to LLM
    ↓
LLM follows skill instructions in its next response
```

### Key Design Points

- **Skills are NOT separate tools** — there's only ONE tool (`activate_skill`) that acts as a dispatcher
- **The LLM chooses which skill to activate** based on the descriptions in the tool's description field
- **Skill content is lazy-loaded** — only the activated skill's full markdown is read and injected
- **Skills are essentially prompt injection via tool results** — the skill's markdown becomes part of the conversation, guiding the LLM's subsequent behavior
- **No code execution** — skills are pure text/instructions, not executable code
