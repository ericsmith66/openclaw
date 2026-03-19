---
description: Performs an interactive pre-implementation architectural review of a specific Epic.
arguments:
  - description: The Epic number (e.g., 5) to review.
    required: true
---
As the Principal Architect, please initiate an **Interactive Architectural Review** of **Epic-{{1}}**.

**STEP 1: DISCOVERY & QUESTIONS (Current Phase)**
1.  **Analyze Source Material**: Review `knowledge_base/epics/Epic-{{1}}-*/0000-overview-epic-{{1}}.md` and all its associated PRDs within that directory.
2.  **Complexity Scoring**: Provide an initial complexity assessment (e.g., Low, Medium, High, or Story Points) and justify it.
3.  **Clarifying Questions**: List any ambiguities, missing details, or technical risks that require user feedback before a plan can be built.

**DO NOT** build the detailed implementation plan yet. This first step is strictly for discovery, scoring, and gathering feedback.

**STEP 2: EPIC MASTER PLAN (Pending User Feedback)**
*Once the user has answered your questions and provided feedback, you will then move to Phase 2: Generate the Epic Master Implementation Plan and save it as `0002-master-implementation-plan.md` in the Epic directory.*

The plan must include:
- PRD sequencing and dependency order
- Cross-PRD architectural decisions and risks
- Overall test strategy (Backend, Frontend, QA, UI-UX)
- Per-PRD summary of scope and complexity estimate
- This plan is the strategic roadmap the Lead Developer will reference when creating individual PRD implementation plans (`PRD-{id}-implementation-plan.md`).
