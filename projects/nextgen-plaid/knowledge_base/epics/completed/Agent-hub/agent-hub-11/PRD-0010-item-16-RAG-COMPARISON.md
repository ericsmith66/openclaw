# PRD Quality Comparison — Artifact 16 (PRD 0010)

This document compares three PRDs for the same work item (`artifacts.id = 16`) to evaluate how PRD quality changes as RAG context becomes richer.

## 1) Documents Compared

### A) Original PRD (historical baseline)

* File: `knowledge_base/epics/Completed Epics/AGENT-05/AGENT-05-0050A.md`
* Title: `PRD 0010: Persona Setup & Console Handoffs (Spike)`
* Context level: **Medium** (clear intent and requirements, but not tightly grounded to current app internals)

### B) Artifact-Table-Only PRD (minimal RAG)

* File: `knowledge_base/epics/Agent-hub/agent-hub-11/PRD-0010-item-16-ARTIFACT-TABLE-RAG.md`
* Title: `PRD 0010 (Artifact 16): Persona Setup & Console Handoffs — Artifact-Table-Only Edition`
* Context level: **Low** (only `artifacts` table schema + id/name of Artifact 16)

### C) TEST-RAG PRD (rich RAG)

* File: `knowledge_base/epics/Agent-hub/agent-hub-11/PRD-0010-item-16-TEST-RAG.md`
* Title: `PRD 0010 (Artifact 16): Persona Setup & Console Handoffs — TEST-RAG Edition`
* Context level: **High** (adds app capabilities, workflows, and linkage targets like `sap_runs` / `ai_workflow_runs`, plus multi-LLM requirements)

---

## 2) Rubric (What “Quality” Means Here)

Each category is scored 1–5:

* `1` = vague / not implementable
* `3` = implementable with developer interpretation
* `5` = highly implementable, unambiguous, low rework risk

Categories:

1. **Clarity of goal and non-goals**
2. **Specificity of requirements** (inputs/outputs, contracts, data shapes)
3. **Integration accuracy** (uses real surfaces, avoids inventing new ones)
4. **Data model / schema grounding** (correct table/fields, correct linkage)
5. **Testability** (deterministic test plan and acceptance criteria)
6. **Operational realism** (guardrails, environment controls, failure modes)
7. **Completeness / coverage** (covers main paths + edges without bloat)

---

## 3) Score Summary

| Category | A) Original | B) Artifact-table-only | C) TEST-RAG |
|---|---:|---:|---:|
| 1) Goal/non-goals clarity | 4 | 3 | 5 |
| 2) Requirement specificity | 4 | 2 | 5 |
| 3) Integration accuracy | 3 | 2 | 5 |
| 4) Schema grounding | 3 | 2 | 5 |
| 5) Testability | 5 | 3 | 5 |
| 6) Operational realism | 4 | 3 | 5 |
| 7) Completeness | 4 | 3 | 5 |
| **Total (max 35)** | **27** | **18** | **35** |

Notes:

* The artifact-table-only PRD is intentionally weaker in categories 2–4 because it cannot reference known app surfaces, tables, and workflow conventions beyond `artifacts` itself.
* The TEST-RAG PRD scores highest because it has the ability to name concrete linkage patterns (`sap_runs.artifact_id`, `AiWorkflowRun.metadata[active_artifact_id]`), known surfaces (`/agent_hub`, `/admin/sap_collaborate`), and hard requirements (dual backends `ollama` + `grok-latest`).

---

## 4) Key Deltas Observed (What RAG “Buys” You)

### 4.1 From Artifact-Table-Only → Original

Improvements:

* Original PRD specifies concrete gem (`ai-agents`) and provider approach (SmartProxy `/v1/chat/completions`).
* Original PRD includes more operational detail (provider matrix, dev run checklist).
* Original PRD includes strong deterministic testing guidance (`WebMock`) and target coverage goals.

Still missing vs rich RAG:

* Original PRD doesn’t anchor as explicitly to current app tables/surfaces (conversation tables, Agent Hub UI linkage).

### 4.2 From Original → TEST-RAG

Improvements attributable to richer RAG context:

* **Hard, app-specific linkage requirements**:
  * conversation linkage via `sap_runs.artifact_id = 16`
  * workflow linkage via `AiWorkflowRun.metadata["active_artifact_id"] = "16"`
* **UI bridge requirements** that reuse existing surfaces rather than inventing new UI:
  * references to Agent Hub and context inspection patterns
  * explicit “no new UI” stance but requires hooks to existing pages
* **Model/backend specificity**:
  * mandates two backends: local `ollama` and `grok-latest`
* **Reduced ambiguity**:
  * fewer open questions; more “do X using Y table/field” instructions

---

## 5) Concrete Examples of Quality Change

### Example A — Artifact linkage

* Artifact-table-only: “persist a link … in at least one durable location” (framework-agnostic, but ambiguous)
* Original: mentions `context` schema and `correlation_id`, but not explicitly tied to the app’s artifact linkage implementation
* TEST-RAG: gives explicit target linkages and locations: `sap_runs.artifact_id` + `AiWorkflowRun.metadata[active_artifact_id]`

### Example B — Integration surfaces

* Artifact-table-only: cannot mention real UIs; asks open question “Are there existing UI surfaces?”
* TEST-RAG: references real known surfaces and requires “bridge to existing UI surfaces (no new UI)”

---

## 6) Recommendations for the Experiment

If the goal is to measure PRD quality improvements from RAG:

1. Keep the “artifact-table-only” prompt intentionally narrow (as done here) to create a clear baseline.
2. Add an intermediate condition (optional): “artifact row + artifact payload only” to isolate the value of payload enrichment vs full system overview.
3. Use the same scoring rubric across more artifacts (e.g., 3–5 items) to reduce single-sample bias.
