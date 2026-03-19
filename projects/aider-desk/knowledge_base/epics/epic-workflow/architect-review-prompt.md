# Φ5 — Architect Review: Epic Consolidated Document

## Purpose
Execute the Architect Review phase (Φ5) from RULES.md for a given epic. The Architect Agent reviews the consolidated epic document (output from Φ4) and provides structured feedback to ensure architectural soundness, completeness, and implementability before PRD breakout.

## Input Requirements
- **Source Document**: Consolidated epic file (format: `0000-epic-{N}-consolidated.md`)
  - Contains: Epic overview + all PRD sections fully expanded
  - Location: `knowledge_base/epics/wip/{Stream}/{Epic-ID}/`
- **Supporting Context**: Read for background understanding
  - `knowledge_base/instructions/RULES.md` — Phase rules and quality standards
  - `knowledge_base/templates/PRD-template.md` — PRD template for section completeness verification
  - Any epic-specific design documents referenced in the consolidated doc

## Review Scope

### Epic-Level Review
Review the epic overview section for:
- **Goal clarity**: Is the overarching objective well-defined?
- **Scope boundaries**: Are scope and non-goals explicit and unambiguous?
- **Success criteria**: Are success metrics specific and measurable?
- **Architectural context**: Does the epic provide sufficient context for implementation?
- **Dependency chain**: Are epic-level dependencies documented?

### PRD-Level Review
For each PRD in the consolidated document, review all 8 required sections:

1. **Overview**: Clear problem statement and solution summary
2. **Requirements** (Functional & Non-Functional): Complete, unambiguous, testable
3. **Error Scenarios & Fallbacks**: Edge cases and failure modes covered
4. **Architectural Context**: Integration points, design decisions, constraints
5. **Acceptance Criteria**: Specific, testable conditions (not vague statements)
6. **Test Cases**: Comprehensive coverage with expected outcomes
7. **Manual Verification**: Step-by-step validation with expected results
8. **Dependencies**: `Blocked By` and `Blocks` relationships declared

### Cross-Cutting Concerns
- **Consistency**: Do PRDs use aligned terminology and architectural patterns?
- **Dependency correctness**: Are dependency chains valid and complete?
- **Naming conventions**: Are naming patterns consistent across PRDs?
- **Separation of responsibilities**: Is each PRD self-contained with clear boundaries?

## Review Process

### Step 1: Load Source Document
1. Read the consolidated epic file completely
2. Identify the epic overview section and all PRD sections
3. Note any referenced supporting documents

### Step 2: Load Supporting Context
1. Review RULES.md Φ4 and Φ5 requirements for quality standards
2. Review PRD-template.md to confirm required sections
3. Review any epic-specific architectural design documents

### Step 3: Conduct Epic-Level Review
- Assess goal clarity and scope boundaries
- Evaluate success criteria for measurability
- Verify architectural context is sufficient for implementation
- Check epic-level dependency documentation

### Step 4: Conduct PRD-Level Reviews
For each PRD:
1. Verify all 8 sections are present
2. Check requirements for completeness and testability
3. Evaluate acceptance criteria specificity (reject vague statements)
4. Review test cases for coverage
5. Verify manual testing steps include expected results
6. Validate dependency declarations (`Blocked By`, `Blocks`)

### Step 5: Assess Cross-Cutting Concerns
- Check terminology consistency across PRDs
- Validate dependency chain correctness
- Verify naming conventions are applied consistently
- Confirm separation of responsibilities is clear

## Output Format

Organize feedback into three categories per RULES.md Φ5 rule 1:

### Questions
**Purpose**: Clarifications needed before implementation can proceed.

Format:
```markdown
### Questions

#### Q1: [PRD-ID or Epic Section] — [Brief Question]
**Context**: [1-2 sentences explaining what needs clarification]
**Question**: [Specific question to be answered]
```

### Suggestions
**Purpose**: Improvements you recommend (optional adoption — Eric decides).

Format:
```markdown
### Suggestions

#### S1: [PRD-ID or Epic Section] — [Brief Suggestion]
**Current state**: [What exists now]
**Suggested improvement**: [Concrete improvement]
**Rationale**: [Why this would be better]
```

### Objections
**Purpose**: Design concerns that should be addressed.

**IMPORTANT**: Every objection MUST include a proposed solution (RULES.md Φ5 rule 2). Never raise a problem without offering a fix.

Format:
```markdown
### Objections

#### O1: [PRD-ID or Epic Section] — [Brief Concern]
**Problem**: [Specific design issue]
**Impact**: [Why this is a problem]
**Proposed Solution**: [Concrete fix or alternative approach]
```

## Output Rules (RULES.md Φ5)

1. **Filename**: `{epic-name}-feedback-V{N}.md` where N increments per cycle
2. **Location**: `knowledge_base/epics/wip/{Stream}/{Epic-ID}/feedback/`
3. **Create directory**: Create the `feedback/` directory if it doesn't exist
4. **Header**: Include date, reviewer (Architect Agent), and source document reference
5. **Be specific**: Reference PRD numbers and section names (e.g., "PRD 4.2, FR-3: ...")
6. **Be constructive**: If everything looks good in a section, say so briefly — don't manufacture issues
7. **Focus**: Prioritize architectural soundness, implementability, and risk — not wordsmithing

## Feedback Header Template

```markdown
# Epic Feedback V{N}

**Date**: {YYYY-MM-DD}
**Reviewer**: Architect Agent
**Source Document**: `{path/to/consolidated-epic.md}`
**Phase**: Φ5 — Architect Review (RULES.md)

---

## Executive Summary
[1-2 paragraphs: overall assessment, major themes, readiness level]

---
```

## Quality Standards

### Required Checks
- ✅ All PRDs have 8 required sections
- ✅ Acceptance criteria are specific and testable (no vague statements)
- ✅ Manual testing steps include expected results
- ✅ Dependency chains are declared and valid
- ✅ Error scenarios and fallbacks are documented
- ✅ Architectural context explains integration points

### Common Issues to Flag
- ❌ Vague acceptance criteria (e.g., "works correctly", "recognizes commands")
- ❌ Missing dependency declarations
- ❌ Inconsistent naming conventions across PRDs
- ❌ Manual testing steps without expected results
- ❌ Missing error handling or fallback strategies
- ❌ Unclear separation of responsibilities between PRDs

## Context Awareness

### Key Architecture Decisions (Epic-Specific)
When reviewing Epic 4 AiderDesk Agent Manager Integration, be aware of:
- **Separation of concerns for Socket.IO events**: PRD 4.1 owns orchestration, PRD 4.4 owns presentation
- **Naming convention**: All agent execution models/components use `AgentTask` prefix
- **NO MOCKS in integration tests (PRD 4.7)**: All tests run against live AiderDesk

*Note: For other epics, adjust this section based on epic-specific architectural decisions.*

## Next Steps After Feedback

1. **Save feedback**: Write feedback to `{epic-name}-feedback-V{N}.md`
2. **Notify Eric**: Feedback is ready for human review
3. **Wait for response**: Eric + High-Reasoning AI will produce `{epic-name}-response-V{N}.md` (Φ6)
4. **Cycle if needed**: Repeat Φ5 → Φ6 up to 3 times until:
   - No remaining objections
   - All key decisions locked in
   - Ready for PRD breakout (Φ7)

## Reference

- **RULES.md**: `knowledge_base/instructions/RULES.md` (Φ5 definition)
- **PRD Template**: `knowledge_base/templates/PRD-template.md`
- **Workflow**: `knowledge_base/epics/epic-workflow/workflow.md`
