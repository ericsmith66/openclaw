#### PRD-WF-04: Update Agent System Prompts

**Log Requirements**
- Create/update a task log under `knowledge_base/prds-junie-log/` on completion.
- Include detailed manual verification steps and expected results.

---

### Overview

The agent system prompts in `ror-agent-config/agents/` need targeted updates to align with the workflow. The QA agent (`ror-qa`) doesn't mention Minitest explicitly. The Debug agent (`ror-debug`) has a thin prompt ("Troubleshooting Specialist") that doesn't match the workflow's expectation of reproduction steps, root-cause analysis, and minimal fix plans. The Coding agent (`ror-rails`) may contain HomeKit-specific references that need removal.

---

### Requirements

#### Functional

1. **Update `ror-qa/config.json` system prompt**
   - Add explicit Minitest mention (currently references RuboCop only).
   - Add reference to RULES.md Φ11 QA rubric: AC Compliance 30, Test Coverage 30, Code Quality 20, Plan Adherence 20.
   - Ensure the prompt states the ≥ 90 pass threshold.

2. **Update `ror-debug/config.json` system prompt**
   - Strengthen from generic "Troubleshooting Specialist" to include:
     - Reproduce the issue (steps + expected/actual).
     - Identify root cause with evidence.
     - Propose minimal fix plan.
     - List exact verification tests to run.
   - Align with `prompt-definitions.md` → `/debug-triage`.

3. **Verify `ror-rails/config.json` system prompt**
   - Confirm no HomeKit-specific references remain (should have been caught in WF-01, but verify here).
   - Confirm commit logic matches the agreed policy.
   - Confirm Minitest is referenced (not RSpec).

4. **Verify `ror-architect/config.json` system prompt**
   - Already generic enough per feedback-v1. Confirm no changes needed.
   - Verify it references plan review and feedback conventions.

#### Non-Functional

- System prompts are embedded in `config.json` as string values. Edits must preserve valid JSON.
- Changes target `ror-agent-config/agents/`, not `.aider-desk/agents/`.

---

### Error Scenarios & Fallbacks

- **Invalid JSON**: If the system prompt edit breaks JSON syntax, the agent won't load at runtime. Validate JSON after every edit (`jq . config.json`).
- **Prompt too long**: If the system prompt exceeds the model's system prompt token limit, it will be truncated. Keep prompts concise — under 500 words each.

---

### Architectural Context

Agent system prompts define the persona and constraints for each agent. They are the first thing the model sees and set the behavioral baseline. If the QA agent doesn't know about Minitest, it may suggest RSpec. If the Debug agent doesn't know to reproduce issues, it may jump to fixes without evidence.

**Blocked by**: WF-01 (HomeKit references and commit policy must be fixed in rules first).

---

### Acceptance Criteria

- [ ] `ror-qa/config.json` system prompt mentions Minitest.
- [ ] `ror-qa/config.json` system prompt references the QA rubric (AC, Test Coverage, Code Quality, Plan Adherence).
- [ ] `ror-qa/config.json` system prompt states ≥ 90 pass threshold.
- [ ] `ror-debug/config.json` system prompt requires reproduction steps.
- [ ] `ror-debug/config.json` system prompt requires root-cause analysis.
- [ ] `ror-debug/config.json` system prompt requires minimal fix plan.
- [ ] `ror-debug/config.json` system prompt requires verification test list.
- [ ] `ror-rails/config.json` system prompt has no HomeKit references.
- [ ] `ror-rails/config.json` system prompt commit logic matches agreed policy.
- [ ] `ror-architect/config.json` system prompt confirmed — no changes needed (or changes documented).
- [ ] All `config.json` files are valid JSON (`jq . config.json` succeeds for each).

---

### Test Cases

#### Validation

- `jq '.systemPrompt' ror-agent-config/agents/ror-qa/config.json | grep -i minitest`: expect match.
- `jq '.systemPrompt' ror-agent-config/agents/ror-debug/config.json | grep -i "root cause\|reproduction\|minimal fix"`: expect match.
- `jq '.systemPrompt' ror-agent-config/agents/ror-rails/config.json | grep -i "homekit\|eureka"`: expect zero results.
- `jq . ror-agent-config/agents/*/config.json > /dev/null`: expect success (valid JSON).

---

### Manual Verification

1. Open `ror-qa/config.json` — read system prompt, confirm Minitest and rubric are present.
2. Open `ror-debug/config.json` — read system prompt, confirm reproduction/root-cause/fix-plan/tests are required.
3. Open `ror-rails/config.json` — read system prompt, confirm no HomeKit references and correct commit policy.
4. Open `ror-architect/config.json` — read system prompt, confirm no changes needed.
5. Run `jq . config.json` on each file — confirm valid JSON.

**Expected**
- QA knows Minitest and the rubric. Debug knows the triage protocol. Rails is clean. All JSON is valid.
