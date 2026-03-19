# Agent Hub 11: SDLC RAG & Context Injection Reference

This document provides a detailed view of how context and prompts are injected into the different workflow phases of the Software Development Life Cycle (SDLC) within the Agent Hub.

## SDLC Phases & Agent Ownership

| Phase | Owner Persona | Primary Goal |
| :--- | :--- | :--- |
| **Backlog** | SAP | Store ideas and initial requests. |
| **Ready for Analysis** | SAP | Refine the initial request into a draft PRD. |
| **In Analysis** | Coordinator | Review PRD, clarify requirements, and prepare for planning. |
| **Planning** | Coordinator / Planner | Breakdown PRD into technical micro-tasks. |
| **Ready for Development** | CWA | Awaiting execution of the technical plan. |
| **In Development** | CWA | Coding, testing, and local commits. |
| **Ready for QA** | Coordinator | Verification of implementation against PRD. |
| **Complete** | Human | Final sign-off. |

---

## Context Injection (RAG) Detailed View

At every phase, the system builds a "Context Prefix" for the agent. This is achieved by replacing placeholders in the system prompts with real-time data. Below are the actual formats and examples of what is injected for each component.

### 1. `[ACTIVE_ARTIFACT]`
This contains the core details of the artifact currently being worked on. For **CWA** and **Coordinator**, it also includes the structured Technical Plan.

**Format Example:**
```markdown
--- [ACTIVE_ARTIFACT] ---
Name: Implement Plaid Link
Type: Feature
Phase: In development

### PRD (Primary Requirements):
# PRD-0010: Plaid Sandbox Link Token Generation
## Overview
Enable secure generation of Plaid link tokens for sandbox mode to initiate account linking.
...

### TECHNICAL PLAN (Micro-tasks):
- [x] 1: Generate migration for PlaidItem (1h)
- [ ] 2: Implement LinkTokenService (2h)
- [ ] 3: Add PlaidController endpoint (1h)

Implementation Notes (Free-form Plan):
Ensure we use the sandbox environment variables for this phase.
--- END ACTIVE_ARTIFACT ---
```

### 2. `[CONTEXT_BACKLOG]`
Provides a summary of other items assigned to the current agent to maintain awareness of their workload.

**Format Example:**
```markdown
--- ASSIGNED ARTIFACTS (Total: 2) ---
ID: 101 | Name: Fix Transaction Sync | Type: Bug | Phase: Backlog | Updated: 2026-01-10
ID: 105 | Name: Audit Logging PRD | Type: Documentation | Phase: Ready for analysis | Updated: 2026-01-11

To move an item forward, you MUST include this tag in your response: [ACTION: <INTENT>: ID]
Valid intents: MOVE_TO_ANALYSIS, APPROVE_PRD, READY_FOR_DEV, START_DEV, COMPLETE_DEV, APPROVE_QA, REJECT, BACKLOG, START_BUILD (silent)
```

### 3. `[VISION_SSOT]`
The master project vision, pulled directly from `knowledge_base/static_docs/MCP.md`.

**Format Example:**
```markdown
# Master Vision: NextGen Wealth Advisor
## Core Vision
Build a “virtual family office” for families with $20M–$50M net worth...
```

### 4. `[PROJECT_STRUCTURE]`
A file tree of the project (depth 2) to give the agent awareness of the codebase layout.

**Format Example:**
```text
.
./app
./app/models
./app/controllers
./config
./db
./lib
```

### 5. `[DATABASE_SCHEMA]`
Explicit database table definitions parsed from `db/schema.rb`. Injected specifically for the **CWA** persona.

**Format Example:**
```text
Table: users
  t.string "email", default: "", null: false
  t.string "encrypted_password", default: "", null: false
...
Table: accounts
  t.string "account_id"
  t.string "name"
```

### 6. `[PROJECT_CONTEXT]`
A JSON snapshot of the user's financial state, with sensitive values (balances, account numbers) redacted.

**Format Example:**
```json
{
  "accounts": [
    {
      "account_id": "[REDACTED_ID]",
      "name": "Plaid Checking",
      "mask": "[REDACTED]",
      "balances": {
        "current": "[REDACTED]",
        "available": "[REDACTED]"
      }
    }
  ],
  "transactions_summary": {
    "count": 45,
    "last_month_total": "[REDACTED]"
  }
}
```

### 7. `[STATIC DOCUMENTS]`
Relevant architectural or process documentation selected based on the current `query_type`.

**Format Example:**
```markdown
--- STATIC DOCUMENTS ---
File: knowledge_base/static_docs/context_map.md
# SAP Context Map
...
---
File: knowledge_base/static_docs/eric_grok_static_rag.md
# NextGen Wealth Advisor Project Context
...
```

---

## Phase-by-Phase Prompt & Action Details

### 1. Requirements & Discovery (SAP)
*   **Phases**: `backlog`, `ready_for_analysis`
*   **System Prompt**: `config/agent_prompts/sap_system.md`
*   **Context Injected**: Full RAG (Vision, Snapshot, Backlog, Active Artifact).
*   **User/Agent Actions**:
    *   `[ACTION: FINALIZE_PRD: ID]` - Submits the first draft; moves to `in_analysis`.
    *   `[ACTION: SAVE_TO_BACKLOG: ID]` - Parks the item in `backlog`.
    *   `[ACTION: MOVE_TO_ANALYSIS: ID]` - Hands off to Coordinator for review.

### 2. Analysis & Technical Breakdown (Coordinator / Planner)
*   **Phases**: `in_analysis`, `planning`
*   **System Prompt**: `config/agent_prompts/coordinator_system.md` + Planner instructions from `personas.yml`.
*   **Context Injected**: Full RAG + `TaskBreakdownTool` output during planning.
*   **User/Agent Actions**:
    *   `[ACTION: APPROVE_PRD: ID]` - Confirms requirements are solid; moves to `planning`.
    *   `[ACTION: START_PLANNING: ID]` - Triggers the Planner to create micro-tasks.
    *   `[ACTION: APPROVE_PLAN: ID]` - Finalizes the technical plan; moves to `ready_for_development`.

### 3. Implementation (CWA)
*   **Phases**: `ready_for_development`, `in_development`
*   **System Prompt**: `config/agent_prompts/cwa_system.md`
*   **Context Injected**: Full RAG + Technical Plan from `[ACTIVE_ARTIFACT]`.
*   **User/Agent Actions**:
    *   `[ACTION: START_IMPLEMENTATION: ID]` - CWA begins code execution.
    *   `[ACTION: REJECT: ID]` - Moves back to `planning` or `ready_for_development` if issues are found.
    *   (Automatic) - Once CWA completes tasks, the ball moves to `ready_for_qa`.

### 4. Verification & Closing (Coordinator)
*   **Phases**: `ready_for_qa`, `complete`
*   **System Prompt**: `config/agent_prompts/coordinator_system.md`
*   **Context Injected**: Full RAG + Implementation summary.
*   **User/Agent Actions**:
    *   `[ACTION: APPROVE_QA: ID]` - Moves artifact to `complete`.
    *   `[ACTION: REJECT: ID]` - Returns to `in_development` for fixes.

---

## Implementation Reference (Code)

*   **Context Construction**: `SapAgent::RagProvider.build_prefix`
*   **Agent Initialization**: `AiWorkflowService.run_once`
*   **State Transitions**: `Artifact#transition_to`
*   **Routing Logic**: `Ai::RoutingPolicy`
