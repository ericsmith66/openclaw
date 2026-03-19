# Atomic Implementation Plan — Epic WF: Implement the Agent-Forge Workflow Framework

**Created**: 2026-02-22
**Epic**: WF — Implement the Agent-Forge Workflow Framework
**Status**: Ready for Implementation

---

## Executive Summary

This plan breaks down the workflow framework epic into **41 atomic tasks** organized across **5 PRDs**. Each task is designed to be independently executable, testable, and committable. The plan respects all blocking dependencies and provides clear validation criteria for each atomic change.

**Key Principles:**
- Each atomic task modifies one file or a tightly coupled set of files
- Each task has clear acceptance criteria and verification steps
- Tasks are ordered by dependency (blocking tasks first)
- All changes target source files in `ror-agent-config/`, not runtime `.aider-desk/` files
- Commit policy: commit plans always; commit code when tests pass (green)

---

## Dependency Graph

```
WF-01 (Foundation)
  ├─> WF-02 (Human Commands)
  ├─> WF-03 (Legacy Commands)
  ├─> WF-04 (Agent Prompts)
  └─> WF-05 (Validation)
```

**Critical Path**: WF-01 → WF-02/03/04 (parallel) → WF-05

---

## PRD WF-01: Generalize Base Rules & Fix Commit Policy (BLOCKING)

**Total Tasks**: 8 atomic tasks
**Est. Duration**: 2-3 hours
**Blocking**: All other PRDs

### Task 1.1: Update rails-base-rules.md Title
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/rules/rails-base-rules.md`

**Change**:
- Replace title "Rails 8 Base Rules for Eureka HomeKit" with "Rails 8 Base Rules"

**Acceptance Criteria**:
- [ ] File title is exactly "Rails 8 Base Rules"
- [ ] No "Eureka" or "HomeKit" in title

**Verification**:
```bash
grep -n "^# Rails 8 Base Rules$" ror-agent-config/rules/rails-base-rules.md
grep -i "eureka\|homekit" ror-agent-config/rules/rails-base-rules.md | head -1
```

**Expected**: First grep returns line number; second grep returns no matches in title.

---

### Task 1.2: Remove HomeKit-Specific References from rails-base-rules.md
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/rules/rails-base-rules.md`

**Change**:
- Remove all references to: `Eureka HomeKit`, `characteristic_uuid`, `LockControlComponent`, HomeKit webhooks, and any other domain-specific terms
- Keep all generic Rails 8 conventions intact

**Acceptance Criteria**:
- [ ] Zero occurrences of "Eureka", "HomeKit", "characteristic_uuid", "LockControlComponent"
- [ ] All Rails 8 conventions preserved (Minitest, service objects, ViewComponents, DaisyUI/Tailwind, Turbo/Hotwire)

**Verification**:
```bash
grep -i "eureka\|homekit\|characteristic_uuid\|LockControlComponent" ror-agent-config/rules/rails-base-rules.md
grep -i "minitest\|service object\|ViewComponent\|DaisyUI\|Turbo" ror-agent-config/rules/rails-base-rules.md
```

**Expected**: First grep returns no matches; second grep returns multiple matches.

---

### Task 1.3: Update Commit Policy in rails-base-rules.md
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/rules/rails-base-rules.md`

**Change**:
Replace:
```
NEVER run destructive git commands or commit without explicit user confirmation
```

With:
```
COMMIT POLICY:
- Commit plans always (no approval needed)
- Commit code only when all tests pass (green gate)
- NEVER run destructive git commands (drop, reset, truncate) without explicit user confirmation
```

**Acceptance Criteria**:
- [ ] Contains "Commit plans always"
- [ ] Contains "Commit code only when all tests pass" or "Commit code when tests pass (green)"
- [ ] Still prohibits destructive git commands without confirmation
- [ ] No contradictory commit language remains

**Verification**:
```bash
grep -n "Commit plans always" ror-agent-config/rules/rails-base-rules.md
grep -n "tests pass\|green" ror-agent-config/rules/rails-base-rules.md
grep -i "never.*commit" ror-agent-config/rules/rails-base-rules.md
```

**Expected**: First two greps return matches; third grep only matches destructive commands clause.

---

### Task 1.4: Update Commit Policy in delegation-rules.md
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/prompts/delegation-rules.md`

**Change**:
- Add explicit green gate for code commits: "Commit code only when all tests pass"
- Ensure plan commits are unconditional: "Commit plans immediately after approval"

**Acceptance Criteria**:
- [ ] Contains green gate for code commits
- [ ] Allows unconditional plan commits
- [ ] No contradictory language

**Verification**:
```bash
grep -i "commit.*code.*test\|commit.*code.*green" ror-agent-config/prompts/delegation-rules.md
grep -i "commit.*plan" ror-agent-config/prompts/delegation-rules.md
```

**Expected**: Both greps return matches with correct policy.

---

### Task 1.5: Update Commit Logic in ror-rails Agent System Prompt
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-rails/config.json`

**Change**:
- Update the COMMIT LOGIC section in the system prompt to reflect:
  - "Commit plans always"
  - "Commit code when all tests pass (green)"

**Acceptance Criteria**:
- [ ] System prompt contains commit policy matching agreed language
- [ ] JSON remains valid after edit

**Verification**:
```bash
jq '.systemPrompt' ror-agent-config/agents/ror-rails/config.json | grep -i "commit"
jq . ror-agent-config/agents/ror-rails/config.json > /dev/null && echo "Valid JSON"
```

**Expected**: First command shows commit policy; second command outputs "Valid JSON".

---

### Task 1.6: Verify No Contradictory Commit Policy Remains
**Scope**: All files in `ror-agent-config/`

**Change**:
- Grep for contradictory commit language across all config files
- Document any found instances for manual review

**Acceptance Criteria**:
- [ ] No instances of "NEVER commit without explicit user confirmation" remain (except in destructive commands context)
- [ ] All commit policy statements align with agreed policy

**Verification**:
```bash
grep -r "without explicit user confirmation\|without.*confirmation" ror-agent-config/ | grep -i commit
grep -r "never.*commit" ror-agent-config/ | grep -v "destructive"
```

**Expected**: No matches or only destructive commands clause matches.

---

### Task 1.7: Verify Generic Rails 8 Conventions Preserved
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/rules/rails-base-rules.md`

**Change**:
- Manual review to confirm all essential Rails 8 conventions remain
- Check: Minitest, service objects, ViewComponents, DaisyUI/Tailwind, Turbo/Hotwire, idiomatic Ruby

**Acceptance Criteria**:
- [ ] Minitest is referenced as default testing framework
- [ ] Service objects pattern is documented
- [ ] ViewComponents convention is present
- [ ] DaisyUI/Tailwind styling is mentioned
- [ ] Turbo/Hotwire patterns are included
- [ ] Idiomatic Ruby guidelines remain

**Verification**:
```bash
grep -i "minitest" ror-agent-config/rules/rails-base-rules.md
grep -i "service object" ror-agent-config/rules/rails-base-rules.md
grep -i "viewcomponent" ror-agent-config/rules/rails-base-rules.md
```

**Expected**: All greps return matches.

---

### Task 1.8: Update WF-01 Status in Implementation Tracker
**File**: `knowledge_base/epics/epic-workflow/0001-IMPLEMENTATION-STATUS.md`

**Change**:
- Update WF-01 status to "Completed"
- Add completion date
- Update blocking status for WF-02, WF-03, WF-04

**Acceptance Criteria**:
- [ ] WF-01 marked as Completed with date
- [ ] WF-02, WF-03, WF-04 marked as unblocked

**Verification**: Manual review of status file.

---

## PRD WF-02: Create Human Command Files

**Total Tasks**: 10 atomic tasks
**Est. Duration**: 3-4 hours
**Depends On**: WF-01 complete

### Task 2.1: Read prompt-definitions.md for Reference
**File**: `knowledge_base/epics/epic-workflow/prompt-definitions.md`

**Change**:
- Read and extract exact prompt text for `/turn-idea-into-epic`
- Document key requirements and RULES.md phase references

**Acceptance Criteria**:
- [ ] Prompt text extracted and ready for use
- [ ] RULES.md phase references noted (Φ1–Φ2)
- [ ] Template references noted

**Verification**: Manual review — ensure prompt text is copied accurately.

---

### Task 2.2: Create turn-idea-into-epic.md
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/turn-idea-into-epic.md`

**Change**:
- Create new file with prompt from prompt-definitions.md
- Include RULES.md Φ1–Φ2 references
- Require PRD summary table output
- Reference epic template: `knowledge_base/templates/0000-EPIC-OVERVIEW-template.md`
- Use `{{1}}` templating for idea input if supported

**Acceptance Criteria**:
- [ ] File exists
- [ ] References RULES.md Φ1–Φ2
- [ ] Requires PRD summary table
- [ ] References epic template
- [ ] Follows same format as `implement-prd.md`

**Verification**:
```bash
test -f ror-agent-config/commands/turn-idea-into-epic.md && echo "File exists"
grep "RULES.md" ror-agent-config/commands/turn-idea-into-epic.md
grep -i "PRD summary" ror-agent-config/commands/turn-idea-into-epic.md
```

**Expected**: All checks pass.

---

### Task 2.3: Read prompt-definitions.md for get-feedback-on-epic
**File**: `knowledge_base/epics/epic-workflow/prompt-definitions.md`

**Change**:
- Extract exact prompt text for `/get-feedback-on-epic`
- Document delegation requirements to `ror-architect`

**Acceptance Criteria**:
- [ ] Prompt text extracted
- [ ] RULES.md phase references noted (Φ4–Φ6)
- [ ] Architect delegation pattern documented

**Verification**: Manual review.

---

### Task 2.4: Create get-feedback-on-epic.md
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/get-feedback-on-epic.md`

**Change**:
- Create new file with prompt from prompt-definitions.md
- Include RULES.md Φ4–Φ6 references
- Delegate to `ror-architect` for review
- Require Questions / Suggestions / Objections format
- Require every objection to include a solution
- Reference PRD template
- Specify feedback filename convention: `{epic-name}-feedback-V{N}.md` in `feedback/` subfolder

**Acceptance Criteria**:
- [ ] File exists
- [ ] References RULES.md Φ4–Φ6
- [ ] Delegates to `ror-architect` (template ID, not runtime ID)
- [ ] Requires Questions / Suggestions / Objections format
- [ ] References PRD template
- [ ] Specifies feedback filename convention

**Verification**:
```bash
test -f ror-agent-config/commands/get-feedback-on-epic.md && echo "File exists"
grep "RULES.md" ror-agent-config/commands/get-feedback-on-epic.md
grep "ror-architect" ror-agent-config/commands/get-feedback-on-epic.md
grep -i "questions\|suggestions\|objections" ror-agent-config/commands/get-feedback-on-epic.md
```

**Expected**: All checks pass.

---

### Task 2.5: Read prompt-definitions.md for finalize-epic
**File**: `knowledge_base/epics/epic-workflow/prompt-definitions.md`

**Change**:
- Extract exact prompt text for `/finalize-epic`
- Document PRD file creation requirements

**Acceptance Criteria**:
- [ ] Prompt text extracted
- [ ] RULES.md Φ7 reference noted
- [ ] PRD naming conventions documented

**Verification**: Manual review.

---

### Task 2.6: Create finalize-epic.md
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/finalize-epic.md`

**Change**:
- Create new file with prompt from prompt-definitions.md
- Include RULES.md Φ7 reference
- Require creation of individual PRD files following RULES.md Part 3 naming
- Require creation of `0001-IMPLEMENTATION-STATUS.md` from template
- Delegate to `ror-architect` for `/plan-epic`
- Require commit of all artifacts per commit policy
- Follow RULES.md Φ7 directory structure

**Acceptance Criteria**:
- [ ] File exists
- [ ] References RULES.md Φ7
- [ ] Requires PRD file creation with correct naming
- [ ] Requires `0001-IMPLEMENTATION-STATUS.md` creation
- [ ] Delegates to `ror-architect` for `/plan-epic`
- [ ] States commit policy
- [ ] Follows RULES.md directory structure

**Verification**:
```bash
test -f ror-agent-config/commands/finalize-epic.md && echo "File exists"
grep "RULES.md" ror-agent-config/commands/finalize-epic.md
grep "ror-architect" ror-agent-config/commands/finalize-epic.md
grep -i "PRD.*file\|individual PRD" ror-agent-config/commands/finalize-epic.md
grep -i "IMPLEMENTATION-STATUS" ror-agent-config/commands/finalize-epic.md
```

**Expected**: All checks pass.

---

### Task 2.7: Verify Template Agent IDs in All New Commands
**Files**: 
- `turn-idea-into-epic.md`
- `get-feedback-on-epic.md`
- `finalize-epic.md`

**Change**:
- Grep for agent IDs in all three new files
- Confirm template format (`ror-architect`, `ror-qa`, `ror-debug`, `ror-rails`)
- Confirm NO runtime suffixes (`-<project>`) are present

**Acceptance Criteria**:
- [ ] All agent references use template format
- [ ] No runtime suffixes found

**Verification**:
```bash
grep -E "ror-(architect|qa|debug|rails)-[a-z]" ror-agent-config/commands/turn-idea-into-epic.md
grep -E "ror-(architect|qa|debug|rails)-[a-z]" ror-agent-config/commands/get-feedback-on-epic.md
grep -E "ror-(architect|qa|debug|rails)-[a-z]" ror-agent-config/commands/finalize-epic.md
```

**Expected**: All greps return no matches (no runtime suffixes).

---

### Task 2.8: Verify Format Consistency with implement-prd.md
**Files**:
- `turn-idea-into-epic.md`
- `get-feedback-on-epic.md`
- `finalize-epic.md`
- `implement-prd.md` (reference)

**Change**:
- Manual review to confirm all new command files follow the same Markdown format as `implement-prd.md`
- Check: headers, sections, RULES.md references, agent delegation syntax

**Acceptance Criteria**:
- [ ] All files use consistent Markdown format
- [ ] Header structure matches `implement-prd.md`
- [ ] RULES.md references formatted identically

**Verification**: Manual side-by-side comparison.

---

### Task 2.9: Verify RULES.md Phase References
**Files**:
- `turn-idea-into-epic.md` (should reference Φ1–Φ2)
- `get-feedback-on-epic.md` (should reference Φ4–Φ6)
- `finalize-epic.md` (should reference Φ7)

**Change**:
- Grep for phase references in each file
- Confirm correct phases are referenced

**Acceptance Criteria**:
- [ ] `turn-idea-into-epic.md` references Φ1 and/or Φ2
- [ ] `get-feedback-on-epic.md` references Φ4, Φ5, and/or Φ6
- [ ] `finalize-epic.md` references Φ7

**Verification**:
```bash
grep "Φ[12]" ror-agent-config/commands/turn-idea-into-epic.md
grep "Φ[456]" ror-agent-config/commands/get-feedback-on-epic.md
grep "Φ7" ror-agent-config/commands/finalize-epic.md
```

**Expected**: All greps return matches.

---

### Task 2.10: Update WF-02 Status in Implementation Tracker
**File**: `knowledge_base/epics/epic-workflow/0001-IMPLEMENTATION-STATUS.md`

**Change**:
- Update WF-02 status to "Completed"
- Add completion date

**Acceptance Criteria**:
- [ ] WF-02 marked as Completed with date

**Verification**: Manual review.

---

## PRD WF-03: Update implement-prd and Legacy Commands

**Total Tasks**: 9 atomic tasks
**Est. Duration**: 2-3 hours
**Depends On**: WF-01 complete

### Task 3.1: Read prompt-definitions.md for implement-prd
**File**: `knowledge_base/epics/epic-workflow/prompt-definitions.md`

**Change**:
- Extract updated prompt text for `/implement-prd`
- Document Blueprint loop phases (Φ8–Φ12)
- Document escalation paths

**Acceptance Criteria**:
- [ ] Prompt text extracted
- [ ] Blueprint phases documented
- [ ] Escalation rules noted

**Verification**: Manual review.

---

### Task 3.2: Update implement-prd.md with Full Blueprint Loop
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/implement-prd.md`

**Change**:
- Replace current content with prompt from prompt-definitions.md
- Explicitly instruct Coding Agent to locate and adhere to approved PRD plan
- Include full Blueprint loop: Φ8 (Plan) → Φ9 (Architect Gate) → Φ10 (Code) → Φ11 (QA Gate) → Φ12 (Log)
- Reference RULES.md Φ8–Φ12 with rubric weights
- Include escalation paths: 3 plan revisions → escalate; 3 QA cycles → escalate
- Include `/log-task` and `/update-implementation-status` as byproducts
- State commit policy

**Acceptance Criteria**:
- [ ] References RULES.md Φ8–Φ12
- [ ] Explicitly requires adherence to approved PRD plan
- [ ] Includes full Blueprint loop (Plan → Approve → Code → Score → Log)
- [ ] Includes escalation paths (3 revisions, 3 QA cycles)
- [ ] Includes `/log-task` and `/update-implementation-status` as byproducts
- [ ] States commit policy correctly

**Verification**:
```bash
grep "RULES.md.*Φ[89]" ror-agent-config/commands/implement-prd.md
grep -i "approved PRD plan\|PRD plan" ror-agent-config/commands/implement-prd.md
grep -i "escalate" ror-agent-config/commands/implement-prd.md
grep -i "log-task\|update-implementation-status" ror-agent-config/commands/implement-prd.md
```

**Expected**: All greps return matches.

---

### Task 3.3: Add INTERNAL Header to review-epic.md
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/review-epic.md`

**Change**:
- Add header comment at top of file: `<!-- INTERNAL — invoked by /get-feedback-on-epic, not by humans directly -->`

**Acceptance Criteria**:
- [ ] Header comment present at top of file

**Verification**:
```bash
head -5 ror-agent-config/commands/review-epic.md | grep "INTERNAL"
```

**Expected**: Grep returns match.

---

### Task 3.4: Update review-epic.md Content for Architect Delegation
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/review-epic.md`

**Change**:
- Update content to serve as internal architect delegation target for `/get-feedback-on-epic`
- Align with `prompt-definitions.md` architect review requirements
- Ensure it requires Questions / Suggestions / Objections format

**Acceptance Criteria**:
- [ ] Content aligned with architect review requirements
- [ ] Requires Questions / Suggestions / Objections format
- [ ] References RULES.md phases

**Verification**:
```bash
grep -i "questions\|suggestions\|objections" ror-agent-config/commands/review-epic.md
grep "RULES.md" ror-agent-config/commands/review-epic.md
```

**Expected**: Both greps return matches.

---

### Task 3.5: Add INTERNAL Header to implement-plan.md
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/implement-plan.md`

**Change**:
- Add header comment: `<!-- INTERNAL — used after PLAN-APPROVED for re-runs. Not a human command -->`

**Acceptance Criteria**:
- [ ] Header comment present

**Verification**:
```bash
head -5 ror-agent-config/commands/implement-plan.md | grep "INTERNAL"
```

**Expected**: Grep returns match.

---

### Task 3.6: Verify implement-plan.md References Approved Plan
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/implement-plan.md`

**Change**:
- Read existing content
- Confirm it references the approved plan
- If not, add reference

**Acceptance Criteria**:
- [ ] File references approved plan

**Verification**:
```bash
grep -i "approved.*plan\|plan.*approved" ror-agent-config/commands/implement-plan.md
```

**Expected**: Grep returns match.

---

### Task 3.7: Delete audit-homekit.md
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/audit-homekit.md`

**Change**:
- Delete the file (confirmed by Eric: no backward-compatible alias needed)

**Acceptance Criteria**:
- [ ] File no longer exists

**Verification**:
```bash
test ! -f ror-agent-config/commands/audit-homekit.md && echo "File deleted"
```

**Expected**: Outputs "File deleted".

---

### Task 3.8: Update Agent IDs in roll-call.md and validate-installation.md
**Files**:
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/roll-call.md`
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/validate-installation.md`

**Change**:
- Replace any bare agent IDs (`architect`, `qa`, `debug`, `rails`) with `ror-architect`, `ror-qa`, `ror-debug`, `ror-rails`
- Ensure template format (no runtime suffixes)

**Acceptance Criteria**:
- [ ] All agent IDs use `ror-*` prefix in both files
- [ ] No bare agent IDs remain
- [ ] No runtime suffixes present

**Verification**:
```bash
grep -E "\"(architect|qa|debug|rails)\"" ror-agent-config/commands/roll-call.md
grep -E "\"(architect|qa|debug|rails)\"" ror-agent-config/commands/validate-installation.md
grep -E "ror-(architect|qa|debug|rails)" ror-agent-config/commands/roll-call.md
grep -E "ror-(architect|qa|debug|rails)" ror-agent-config/commands/validate-installation.md
```

**Expected**: First two greps return no matches; second two greps return matches.

---

### Task 3.9: Update WF-03 Status in Implementation Tracker
**File**: `knowledge_base/epics/epic-workflow/0001-IMPLEMENTATION-STATUS.md`

**Change**:
- Update WF-03 status to "Completed"
- Add completion date

**Acceptance Criteria**:
- [ ] WF-03 marked as Completed with date

**Verification**: Manual review.

---

## PRD WF-04: Update Agent System Prompts

**Total Tasks**: 8 atomic tasks
**Est. Duration**: 2-3 hours
**Depends On**: WF-01 complete

### Task 4.1: Read ror-qa Agent System Prompt
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-qa/config.json`

**Change**:
- Read current system prompt
- Identify where to add Minitest reference
- Identify where to add RULES.md Φ11 rubric reference

**Acceptance Criteria**:
- [ ] Current prompt analyzed
- [ ] Insertion points identified

**Verification**: Manual review.

---

### Task 4.2: Update ror-qa System Prompt — Add Minitest
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-qa/config.json`

**Change**:
- Add explicit Minitest mention to system prompt
- Update testing framework references from RuboCop-only to RuboCop + Minitest

**Acceptance Criteria**:
- [ ] System prompt mentions Minitest
- [ ] JSON remains valid

**Verification**:
```bash
jq '.systemPrompt' ror-agent-config/agents/ror-qa/config.json | grep -i minitest
jq . ror-agent-config/agents/ror-qa/config.json > /dev/null && echo "Valid JSON"
```

**Expected**: First grep returns match; second outputs "Valid JSON".

---

### Task 4.3: Update ror-qa System Prompt — Add RULES.md Φ11 Rubric
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-qa/config.json`

**Change**:
- Add reference to RULES.md Φ11 QA rubric
- State rubric weights: AC Compliance 30, Test Coverage 30, Code Quality 20, Plan Adherence 20
- State ≥ 90 pass threshold

**Acceptance Criteria**:
- [ ] System prompt references RULES.md Φ11
- [ ] Rubric weights listed
- [ ] Pass threshold (≥ 90) stated
- [ ] JSON remains valid

**Verification**:
```bash
jq '.systemPrompt' ror-agent-config/agents/ror-qa/config.json | grep -i "Φ11\|rubric"
jq '.systemPrompt' ror-agent-config/agents/ror-qa/config.json | grep -i "90"
jq . ror-agent-config/agents/ror-qa/config.json > /dev/null && echo "Valid JSON"
```

**Expected**: All checks pass.

---

### Task 4.4: Read ror-debug Agent System Prompt
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-debug/config.json`

**Change**:
- Read current system prompt (likely generic "Troubleshooting Specialist")
- Identify where to strengthen with workflow requirements

**Acceptance Criteria**:
- [ ] Current prompt analyzed
- [ ] Enhancement areas identified

**Verification**: Manual review.

---

### Task 4.5: Update ror-debug System Prompt — Add Workflow Protocol
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-debug/config.json`

**Change**:
- Strengthen system prompt to require:
  1. Reproduce the issue (steps + expected/actual)
  2. Identify root cause with evidence
  3. Propose minimal fix plan
  4. List exact verification tests to run
- Align with `prompt-definitions.md` → `/debug-triage`

**Acceptance Criteria**:
- [ ] System prompt requires reproduction steps
- [ ] System prompt requires root-cause analysis
- [ ] System prompt requires minimal fix plan
- [ ] System prompt requires verification test list
- [ ] JSON remains valid

**Verification**:
```bash
jq '.systemPrompt' ror-agent-config/agents/ror-debug/config.json | grep -i "reproduce\|root cause\|minimal fix\|verification"
jq . ror-agent-config/agents/ror-debug/config.json > /dev/null && echo "Valid JSON"
```

**Expected**: First grep returns matches; second outputs "Valid JSON".

---

### Task 4.6: Verify ror-rails Agent System Prompt — No HomeKit References
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-rails/config.json`

**Change**:
- Grep system prompt for HomeKit references
- If found, remove them

**Acceptance Criteria**:
- [ ] No HomeKit references in system prompt
- [ ] Commit logic matches agreed policy (already done in Task 1.5)
- [ ] Minitest is referenced (not RSpec)
- [ ] JSON remains valid

**Verification**:
```bash
jq '.systemPrompt' ror-agent-config/agents/ror-rails/config.json | grep -i "homekit\|eureka"
jq '.systemPrompt' ror-agent-config/agents/ror-rails/config.json | grep -i "minitest"
jq . ror-agent-config/agents/ror-rails/config.json > /dev/null && echo "Valid JSON"
```

**Expected**: First grep returns no matches; second grep returns match; third outputs "Valid JSON".

---

### Task 4.7: Verify ror-architect Agent System Prompt
**File**: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-architect/config.json`

**Change**:
- Read system prompt
- Confirm it references plan review and feedback conventions
- Confirm no changes needed (per epic: "already generic enough")
- Document confirmation

**Acceptance Criteria**:
- [ ] System prompt reviewed
- [ ] No changes needed or changes documented
- [ ] JSON is valid

**Verification**:
```bash
jq '.systemPrompt' ror-agent-config/agents/ror-architect/config.json
jq . ror-agent-config/agents/ror-architect/config.json > /dev/null && echo "Valid JSON"
```

**Expected**: Second command outputs "Valid JSON".

---

### Task 4.8: Update WF-04 Status in Implementation Tracker
**File**: `knowledge_base/epics/epic-workflow/0001-IMPLEMENTATION-STATUS.md`

**Change**:
- Update WF-04 status to "Completed"
- Add completion date

**Acceptance Criteria**:
- [ ] WF-04 marked as Completed with date

**Verification**: Manual review.

---

## PRD WF-05: Validate & Align Documentation

**Total Tasks**: 6 atomic tasks
**Est. Duration**: 2-3 hours
**Depends On**: WF-01, WF-02, WF-03, WF-04 all complete

### Task 5.1: Grep for RSpec Remnants Across All Config Files
**Scope**: All files in `ror-agent-config/`

**Change**:
- Search for "RSpec", "rspec", "spec_helper" across all config files
- Document any found references
- Replace with Minitest equivalents

**Acceptance Criteria**:
- [ ] Zero RSpec references in any `ror-agent-config/` file

**Verification**:
```bash
grep -ri "rspec\|spec_helper" ror-agent-config/
```

**Expected**: No matches found.

---

### Task 5.2: Verify Four-Command Model Consistency
**Files**:
- `knowledge_base/epics/epic-workflow/workflow.md`
- `knowledge_base/epics/epic-workflow/how-to-use-workflow.md`
- `knowledge_base/epics/epic-workflow/prompt-definitions.md`

**Change**:
- Read all three files
- Confirm each lists exactly four human-run commands
- Confirm command names match
- Confirm RULES.md phase mappings match
- Document any discrepancies

**Acceptance Criteria**:
- [ ] `workflow.md` lists exactly four human-run commands
- [ ] `how-to-use-workflow.md` describes exactly four human-run commands
- [ ] `prompt-definitions.md` has prompt text for exactly four human commands
- [ ] All three documents agree on command names
- [ ] All three documents agree on RULES.md phase mappings

**Verification**:
```bash
grep -c "/turn-idea-into-epic\|/get-feedback-on-epic\|/finalize-epic\|/implement-prd" knowledge_base/epics/epic-workflow/workflow.md
grep -c "/turn-idea-into-epic\|/get-feedback-on-epic\|/finalize-epic\|/implement-prd" knowledge_base/epics/epic-workflow/how-to-use-workflow.md
grep -c "/turn-idea-into-epic\|/get-feedback-on-epic\|/finalize-epic\|/implement-prd" knowledge_base/epics/epic-workflow/prompt-definitions.md
```

**Expected**: All three commands return ≥ 4.

---

### Task 5.3: Update workflow-table-of-contence.md
**File**: `knowledge_base/epics/epic-workflow/workflow-table-of-contence.md`

**Change**:
- Add three new command files: `turn-idea-into-epic.md`, `get-feedback-on-epic.md`, `finalize-epic.md`
- Mark `audit-homekit.md` as removed (✅ REMOVED)
- Mark `review-epic.md` as repurposed to internal (✅ INTERNAL)
- Mark `implement-plan.md` as internal-only (✅ INTERNAL)
- Update agent entries to reflect prompt changes
- Remove all "TO CREATE/UPDATE/REMOVE" markers
- Add ✅ markers for completed items

**Acceptance Criteria**:
- [ ] Three new command files listed
- [ ] `audit-homekit.md` marked as ✅ REMOVED
- [ ] `review-epic.md` marked as ✅ INTERNAL
- [ ] `implement-plan.md` marked as ✅ INTERNAL
- [ ] Agent prompt updates reflected
- [ ] Zero "TO CREATE/UPDATE/REMOVE" markers remain
- [ ] All completed items have ✅ markers

**Verification**:
```bash
grep "turn-idea-into-epic.md" knowledge_base/epics/epic-workflow/workflow-table-of-contence.md
grep "audit-homekit.md" knowledge_base/epics/epic-workflow/workflow-table-of-contence.md | grep "REMOVED"
grep "TO CREATE\|TO UPDATE\|TO REMOVE\|TO REPURPOSE" knowledge_base/epics/epic-workflow/workflow-table-of-contence.md
```

**Expected**: First two greps return matches; third grep returns no matches.

---

### Task 5.4: Verify RULES.md Alignment Across All Command Files
**Scope**: All command files in `ror-agent-config/commands/`

**Change**:
- Grep for RULES.md references in all command files
- Confirm phase references are correct
- Confirm commit policy language matches RULES.md Φ10

**Acceptance Criteria**:
- [ ] All command files reference RULES.md
- [ ] Phase references are correct
- [ ] Commit policy matches RULES.md Φ10

**Verification**:
```bash
grep -l "RULES.md" ror-agent-config/commands/*.md
grep -h "commit" ror-agent-config/commands/*.md | sort -u
```

**Expected**: First grep lists all command files; second grep shows consistent commit policy.

---

### Task 5.5: Run Full Validation Checklist
**File**: `knowledge_base/epics/epic-workflow/workflow-implementaion-plan.md`

**Change**:
- Execute every item in Section I validation checklist
- Mark each item as [x] when verified
- Document any failures with remediation steps

**Acceptance Criteria**:
- [ ] All checklist items in Section I are marked [x]
- [ ] Any failures are documented with remediation

**Verification**: Manual review of implementation plan file.

---

### Task 5.6: Update WF-05 Status and Epic Completion
**Files**:
- `knowledge_base/epics/epic-workflow/0001-IMPLEMENTATION-STATUS.md`
- `knowledge_base/epics/epic-workflow/0000-epic.md`

**Change**:
- Update WF-05 status to "Completed"
- Add completion date
- Add epic completion summary
- Confirm all Success Metrics in `0000-epic.md` are met

**Acceptance Criteria**:
- [ ] WF-05 marked as Completed with date
- [ ] Epic marked as complete
- [ ] All Success Metrics verified
- [ ] Implementation Status summary updated

**Verification**: Manual review.

---

## Execution Strategy

### Phase 1: Foundation (WF-01)
Execute Tasks 1.1 through 1.8 sequentially. This is the critical path — all other work is blocked until WF-01 is complete.

**Checkpoint**: After Task 1.8, verify:
- `rails-base-rules.md` has no HomeKit references
- Commit policy is consistent across all three files (rails-base-rules.md, delegation-rules.md, ror-rails/config.json)
- All JSON files are valid

### Phase 2: Parallel Execution (WF-02, WF-03, WF-04)
After WF-01 completes, these three PRDs can be executed in parallel:
- **WF-02**: Create human command files (Tasks 2.1–2.10)
- **WF-03**: Update legacy commands (Tasks 3.1–3.9)
- **WF-04**: Update agent prompts (Tasks 4.1–4.8)

**Checkpoint**: After all three complete, verify:
- Three new command files exist
- All agent IDs use template format
- All agent prompts are updated
- All JSON files are valid

### Phase 3: Validation (WF-05)
Execute Tasks 5.1 through 5.6 sequentially after WF-02, WF-03, and WF-04 are all complete.

**Final Checkpoint**: After Task 5.6, verify:
- Zero RSpec references
- Four-command model is consistent across all docs
- Table of Contents is complete
- All validation checklist items pass
- Epic Success Metrics are met

---

## Risk Mitigation

### Risk: JSON Syntax Errors
**Mitigation**: After every JSON edit, run `jq . <file.json>` to validate syntax.

### Risk: Breaking Agent Runtime
**Mitigation**: Changes target source files only; the sync script controls deployment. Test with sync script after each PRD completion.

### Risk: Missing HomeKit References
**Mitigation**: After WF-01, run comprehensive grep across entire `ror-agent-config/` directory for all HomeKit-related terms.

### Risk: Inconsistent Commit Policy
**Mitigation**: After WF-01, grep all files for commit-related language and manually review for consistency.

### Risk: Agent ID Mismatches
**Mitigation**: After WF-02 and WF-03, grep all command files for agent IDs and verify template format (no runtime suffixes).

---

## Success Criteria (Epic-Level)

Upon completion of all 41 atomic tasks:

- [ ] All four human commands exist with correct prompt text
- [ ] `rails-base-rules.md` contains zero HomeKit-specific references
- [ ] Commit policy is identical across all config files
- [ ] No RSpec references remain
- [ ] All agent system prompts are updated
- [ ] All utility commands have correct agent IDs
- [ ] Table of Contents is complete and accurate
- [ ] Validation checklist is 100% complete
- [ ] Epic Success Metrics are verified

---

## Appendix A: Quick Reference — File Paths

### Source Config Directory
Base: `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/`

**Rules**:
- `rules/rails-base-rules.md`

**Prompts**:
- `prompts/delegation-rules.md`

**Agents**:
- `agents/ror-architect/config.json`
- `agents/ror-qa/config.json`
- `agents/ror-debug/config.json`
- `agents/ror-rails/config.json`

**Commands**:
- `commands/turn-idea-into-epic.md` (TO CREATE)
- `commands/get-feedback-on-epic.md` (TO CREATE)
- `commands/finalize-epic.md` (TO CREATE)
- `commands/implement-prd.md` (UPDATE)
- `commands/review-epic.md` (REPURPOSE)
- `commands/implement-plan.md` (MARK INTERNAL)
- `commands/audit-homekit.md` (DELETE)
- `commands/roll-call.md` (UPDATE)
- `commands/validate-installation.md` (UPDATE)

### Epic Documentation Directory
Base: `knowledge_base/epics/epic-workflow/`

**Key Files**:
- `0000-epic.md` (epic overview)
- `0001-IMPLEMENTATION-STATUS.md` (tracker)
- `workflow-implementaion-plan.md` (detailed change list)
- `prompt-definitions.md` (source of truth for prompts)
- `workflow.md` (workflow definition)
- `how-to-use-workflow.md` (human guide)
- `workflow-table-of-contence.md` (file inventory)

---

## Appendix B: Grep Patterns for Validation

### HomeKit References
```bash
grep -ri "eureka\|homekit\|characteristic_uuid\|LockControlComponent" ror-agent-config/
```

### Commit Policy
```bash
grep -ri "commit" ror-agent-config/ | grep -i "never\|explicit.*confirmation"
```

### RSpec References
```bash
grep -ri "rspec\|spec_helper" ror-agent-config/
```

### Agent ID Format
```bash
# Should return matches (template IDs):
grep -r "ror-architect\|ror-qa\|ror-debug\|ror-rails" ror-agent-config/commands/

# Should return NO matches (runtime IDs):
grep -rE "ror-(architect|qa|debug|rails)-[a-z]" ror-agent-config/commands/
```

### JSON Validation
```bash
for f in ror-agent-config/agents/*/config.json; do
  echo "Checking $f..."
  jq . "$f" > /dev/null && echo "✓ Valid" || echo "✗ INVALID"
done
```

---

**End of Atomic Implementation Plan**
