# Workflow.md Feedback V1

**Date**: 2026-02-22
**Reviewer**: Architect Agent
**Source Document**: `knowledge_base/epics/epic-workflow/workflow.md`
**Context**: Review informed by `architect-review-prompt.md` as reference for detailed phase documentation

---

## Executive Summary

The `workflow.md` document provides a strong high-level overview of the 14-phase epic workflow and successfully maps phases to human commands. It serves well as a "bridge" document between RULES.md and AiderDesk runtime implementation. However, it lacks the **detailed procedural guidance** needed for agents to execute individual phases (particularly Φ4, Φ5, Φ6).

**Key Observations:**
- ✅ Clear actor roles and phase-to-command mapping
- ✅ Effective conflict resolution hierarchy (RULES.md → workflow.md → AiderDesk config)
- ⚠️ Missing detailed "how-to" sections for multi-step phases
- ⚠️ Φ5 mentioned but not elaborated (architect-review-prompt.md fills this gap)

**Readiness**: Document is suitable for its stated purpose (high-level reconciliation) but should be enhanced with references to detailed phase guides.

---

## Questions

### Q1: Workflow.md Scope — Implementation Plan or Reference Guide?
**Context**: The document title says "Implementation Plan" but it reads more like a reference/overview document. The detailed implementation tasks are in `workflow-implementation-plan.md`.

**Question**: Should this document be renamed to better reflect its role as a **reference guide** rather than an implementation plan? Consider:
- Current title: "Unified Workflow Implementation Plan"
- Suggested: "Unified Workflow Reference" or "Workflow Overview & Command Mapping"

### Q2: Phase Detail Location Strategy
**Context**: `architect-review-prompt.md` provides detailed Φ5 guidance. Similar detailed guides may be needed for Φ4, Φ6, Φ8, Φ9, Φ11.

**Question**: What's the intended pattern for detailed phase documentation?
- **Option A**: Keep workflow.md high-level, create separate phase guides (e.g., `phi-4-full-expansion-guide.md`, `phi-6-feedback-response-guide.md`)
- **Option B**: Expand workflow.md to include detailed sections for each phase
- **Option C**: Move all phase details to RULES.md and keep workflow.md as pure command mapping

---

## Suggestions

### S1: Line 50 — Add Reference to Architect Review Prompt
**Current state**: `/get-feedback-on-epic` mentions "Architect returns Questions/Suggestions/Objections" but doesn't reference the detailed guide.

**Suggested improvement**:
```markdown
| `/get-feedback-on-epic` | Φ4–Φ6 | Coding Agent delegates to Architect for review (see `architect-review-prompt.md` for detailed Φ5 guidance). Architect returns Questions/Suggestions/Objections (with solutions). Eric + High-Reasoning AI respond. Repeat 1–3 cycles. |
```

**Rationale**: Helps agents/humans discover the detailed procedural guide when executing this command.

### S2: Add "Detailed Phase Guides" Section
**Current state**: No index of available detailed guides.

**Suggested improvement**: Add a new section after "Agent Roles (Unified)":
```markdown
---

## Detailed Phase Guides

For phases requiring multi-step execution or quality standards, detailed guides are available:

| Phase | Guide Document | Purpose |
|-------|----------------|---------|
| Φ5 | `architect-review-prompt.md` | Architect review process, feedback format, quality standards |
| Φ4 | *TBD* | Full PRD expansion from atomic summaries |
| Φ6 | *TBD* | Feedback response synthesis and integration |
| Φ8 | *TBD* | Implementation plan creation rubric |
| Φ9 | *TBD* | Architect plan approval criteria |
| Φ11 | *TBD* | QA scoring rubric and remediation standards |

**Note**: Phases not listed use the rules and templates defined in RULES.md without additional procedural guides.

---
```

**Rationale**: Provides discoverability and clarifies which phases have detailed guidance vs. which rely solely on RULES.md.

### S3: Lines 47-52 — Add "Agent Lead" Column to Phase Mapping Table
**Current state**: Table shows phases and outcomes but not who leads each phase.

**Suggested improvement**:
```markdown
| Human Command | RULES.md Phases | Agent Lead | What Happens |
|---------------|-----------------|------------|--------------|
| `/turn-idea-into-epic` | Φ1–Φ2 | Coding Agent | Eric provides idea; Coding Agent drafts epic... |
| `/get-feedback-on-epic` | Φ4–Φ6 | Coding Agent (delegates to Architect for Φ5) | Coding Agent expands epic (Φ4), delegates to Architect for review (Φ5)... |
| `/finalize-epic` | Φ7 | Coding Agent | Coding Agent reads all feedback/response docs... |
| `/implement-prd` | Φ8–Φ12 | Coding Agent (delegates to Architect for Φ9, QA for Φ11) | Coding Agent writes plan (Φ8)... |
```

**Rationale**: Makes the delegation pattern explicit at a glance.

### S4: Line 110 — Clarify Φ4 Execution
**Current state**: `/get-feedback-on-epic` description doesn't explicitly state who performs Φ4 (full expansion).

**Suggested improvement**:
```markdown
- `/get-feedback-on-epic` — **Φ4**: Coding Agent expands epic to full consolidated document; **Φ5**: delegates to Architect for review; **Φ6**: human+AI respond to feedback (Φ4–Φ6)
```

**Rationale**: Clarifies that Φ4 is automated (Coding Agent) vs. Φ6 which is human-led.

### S5: Add Example Epic Directory Structure
**Current state**: Line 51 mentions creating files but doesn't show the final directory structure.

**Suggested improvement**: Add to "Agent Roles (Unified)" or create a new "Artifacts & File Organization" section:
```markdown
### Example: Epic Directory Structure

After `/finalize-epic` (Φ7), the epic directory structure is:

```
knowledge_base/epics/wip/{Stream}/{Epic-ID}/
  ├── 0000-epic.md                      # Finalized epic with "Key Decisions Locked In"
  ├── 0001-implementation-status.md     # Status tracker (all PRDs "Not Started")
  ├── PRD-{epic}-01-{slug}.md           # Individual PRD files
  ├── PRD-{epic}-02-{slug}.md
  ├── ...
  └── feedback/
      ├── {epic-name}-feedback-V1.md    # Architect feedback (Φ5)
      ├── {epic-name}-response-V1.md    # Human/AI response (Φ6)
      ├── {epic-name}-feedback-V2.md    # Second cycle (if needed)
      └── ...
```
```

**Rationale**: Provides concrete visualization of workflow artifacts.

### S6: Lines 126-150 — Move "Required Changes" to Implementation Plan
**Current state**: Section A-D lists blocking tasks, which belong in `workflow-implementation-plan.md`.

**Suggested improvement**: Replace with:
```markdown
## Implementation Status

This workflow is currently **in progress**. See `workflow-implementation-plan.md` for detailed implementation tasks.

**Completed**:
- ✅ RULES.md created at `knowledge_base/epics/instructions/RULES.md`
- ✅ Φ10 commit policy updated
- ✅ Architect review prompt created (`architect-review-prompt.md`)

**In Progress**:
- ⏳ Creating missing command files (`turn-idea-into-epic.md`, `get-feedback-on-epic.md`, `finalize-epic.md`)
- ⏳ Generalizing agent configs (remove HomeKit references)

**Blocked**:
- See `workflow-implementation-plan.md` Section A-D for full task list
```

**Rationale**: Keeps workflow.md focused on "what the workflow is" rather than "how to implement it."

---

## Objections

### O1: Line 50 — Incomplete Φ4 Execution Guidance
**Problem**: The `/get-feedback-on-epic` command mentions Φ4 (full expansion) but provides no guidance on:
- How to expand atomic PRD summaries into 8-section PRDs
- What template to follow for expansion
- Quality standards for expanded PRDs

**Impact**: Coding Agent may produce inconsistent or incomplete PRD expansions without clear procedural guidance. This could result in Architect feedback cycles wasted on structural issues rather than architectural concerns.

**Proposed Solution**: Create `phi-4-prd-expansion-guide.md` similar to `architect-review-prompt.md`. Should include:

```markdown
# Φ4 — Full PRD Expansion Guide

## Purpose
Expand atomic PRD summaries (2-3 sentences from Φ2) into fully detailed PRDs with all 8 required sections.

## Input
- Epic with PRD summary table (output from Φ2, approved in Φ3)
- PRD template: `knowledge_base/templates/PRD-template.md`

## Output
- Single consolidated document: `0000-epic-{N}-consolidated.md`
- Contains: Epic overview + all PRDs fully expanded

## Expansion Process

### For Each PRD:
1. Read the atomic summary (2-3 sentences)
2. Expand into 8 sections following PRD-template.md:
   - Overview
   - Requirements (Functional & Non-Functional)
   - Error Scenarios & Fallbacks
   - Architectural Context
   - Acceptance Criteria (must be specific and testable)
   - Test Cases
   - Manual Verification
   - Dependencies

### Quality Standards:
- ✅ Acceptance criteria are specific (not "works correctly")
- ✅ Manual tests include expected results
- ✅ Dependencies declare Blocked By and Blocks relationships
- ✅ Each PRD is self-contained (readable without others)

## Reference
- RULES.md Φ4 rules
- PRD-template.md for section structure
```

Then reference this guide in workflow.md line 50 and in the suggested "Detailed Phase Guides" section (S2).

### O2: Line 114-122 — Agent-Internal Steps Lack Documentation
**Problem**: Seven agent-internal commands are listed (`/plan-epic`, `/plan-prds`, `/architect-review-plan`, etc.) but none have documentation explaining:
- When they're triggered
- What inputs they require
- What outputs they produce
- What their success/failure criteria are

**Impact**: Without documented internal commands, troubleshooting workflow failures is difficult. If `/architect-review-plan` fails, there's no reference for what went wrong.

**Proposed Solution**: Create an "Internal Commands Reference" section or separate document:

```markdown
## Internal Commands Reference

These commands are invoked by the Coding Agent during workflow execution. Humans never trigger them directly.

### `/plan-epic` (Φ7)
**Triggered by**: `/finalize-epic` command
**Actor**: Architect Agent
**Input**: Finalized `0000-epic.md` + all `PRD-*.md` files
**Output**: `{epic-name}-implementation-plan.md` — execution order, dependencies, risk assessment
**Success criteria**: Plan approved by Coding Agent, committed to repo

### `/architect-review-plan` (Φ9)
**Triggered by**: `/implement-prd` after plan creation (Φ8)
**Actor**: Architect Agent
**Input**: Implementation plan from Φ8
**Output**: `PLAN-APPROVED` or `PLAN-REVISE` + feedback
**Success criteria**: Architect emits `PLAN-APPROVED`

[... document remaining internal commands ...]
```

Add this section after "Agent-Internal Steps (Delegated by Coding Agent)" (line 114).

### O3: Missing Cross-Reference to RULES.md Φ Definitions
**Problem**: Workflow.md uses Φ notation (Φ1, Φ2, etc.) throughout but doesn't include a quick-reference table mapping Φ numbers to phase names. Readers must open RULES.md to understand "Φ5" means "Architect Review."

**Impact**: Reduces document usability as a standalone reference. Readers constantly context-switch to RULES.md.

**Proposed Solution**: Add a "Phase Quick Reference" section near the top (after "Actors" section):

```markdown
---

## Phase Quick Reference (from RULES.md)

| Phase | Name | Primary Actor | Key Output |
|-------|------|---------------|------------|
| Φ1 | Idea Origination | Eric | Raw feature idea |
| Φ2 | Atomic PRD Summaries | Eric + High-Reasoning AI | Epic draft with PRD table |
| Φ3 | Eric Approval | Eric | Approved epic skeleton |
| Φ4 | Full Expansion | Eric + High-Reasoning AI | Consolidated document (epic + all PRDs) |
| Φ5 | Architect Review | Architect Agent | Feedback document |
| Φ6 | Feedback Response | Eric + High-Reasoning AI | Response document |
| Φ7 | PRD Breakout | Coding Agent | Individual PRD files + status tracker |
| Φ8 | Implementation Plan | Coding Agent | Detailed implementation plan |
| Φ9 | Architect Plan Gate | Architect Agent | Plan approval or revision request |
| Φ10 | Implementation | Coding Agent | Code + tests |
| Φ11 | QA Score Gate | QA Agent | 0-100 score + remediation (if < 90) |
| Φ12 | Task Log + Status | Coding Agent | Task log + updated status tracker |
| Φ13 | Closeout | Eric | PR merged, branch cleaned up |
| Φ14 | Next Epic | Eric | Next epic initiated |

**Authoritative definitions**: See `knowledge_base/epics/instructions/RULES.md`

---
```

Insert this after line 34 (after "Actors" section, before "Reconciled Workflow").

---

## Summary

The workflow.md document effectively fulfills its role as a high-level reference and command mapping guide. The three objections address:

1. **Missing Φ4 guidance** — create `phi-4-prd-expansion-guide.md`
2. **Undocumented internal commands** — add "Internal Commands Reference" section
3. **Missing Φ quick reference** — add phase table for standalone usability

The six suggestions enhance discoverability, clarity, and organization without changing core content. All feedback aligns with the document's stated purpose as an "implementation bridge" between RULES.md and AiderDesk config.
