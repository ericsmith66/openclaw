# Subagent Peeking Strategy: Model Inheritance Bypass

This document details the "Peeking Strategy" used in AiderDesk/Eureka-Homekit to ensure architectural integrity and security through specialized subagent orchestration.

## 1. Executive Summary
The **Peeking Strategy** (or **Model Inheritance Bypass**) is an orchestration pattern where a high-reasoning model (e.g., Claude 3.5 Sonnet) is strategically invoked to audit the work of a lower-reasoning or faster lead agent (e.g., Qwen 3).

By forcing the Lead Agent to "STOP" and "Invoke" a specialized subagent at critical junctions, we ensure that high-risk logic is always validated by a "Senior Architect" model regardless of the primary model's capabilities.

## 2. The Model Inheritance Bypass
In a typical subagent setup, the subagent often "inherits" the reasoning context of the Lead. The Peeking Strategy intentionally breaks this by:
1. **Explicit Routing**: Directing critical tasks (Architecture, Security, QA) to a dedicated profile (Claude).
2. **Phase-Gating**: Injecting mandatory stop points in the Lead Agent's workflow.
3. **Adversarial Audit**: Using the subagent as a critic rather than a collaborator.

## 3. The Complexity Matrix
The intensity of the peeking is determined by the **Complexity Tier** of the task, defined in `knowledge_base/strategy/complexity_matrix.json`.

| Tier | Complexity | Definition | Strategy | Audit Milestones |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | Low | UI updates, text changes, read-only components. | **Passive** | Final Audit Only. |
| **Tier 2** | Medium | Internal logic, state management, standard DB writes. | **Active** | Service Audit + Final Audit. |
| **Tier 3** | High | External hardware sync, security logic, concurrency. | **Strict** | **Blueprint** + Service + Final Audit. |

## 4. Strategic Architect Workflow
To automate this, the **Architect Subagent** performs a pre-implementation audit of the entire Epic/PRD backlog.

1. **Backlog Scoring**: The Architect reviews PRDs against the Complexity Matrix.
2. **Strategic Roadmap**: It generates a JSON roadmap (`epic-5-roadmap.json`) containing Tiers and required Audit Milestones.
3. **Prompt Injection**: The orchestration layer uses this JSON to dynamically inject the correct "Phase-Gate" instructions into the Lead Agent's prompt.

## 5. The Phase-Gate Audit Process

### Phase 1: Blueprint Audit (Tier 3 Only)
- **Goal**: Validate the *plan* before code is written.
- **Action**: Lead Agent stops after creating a Technical Spec/Plan. QA Subagent audits for architectural flaws or missing security constraints.

### Phase 2: Service Audit (Tier 2 & 3)
- **Goal**: Validate core business logic and external integrations.
- **Action**: Lead Agent stops after implementing the Service layer but before the UI. QA Subagent audits for edge cases, error handling, and adherence to the **Strict Execution Directive**.

### Phase 3: Final Verification (All Tiers)
- **Goal**: End-to-end verification.
- **Action**: Lead Agent stops after full implementation. QA Subagent runs/reviews tests and performs a final "Peeker" audit of the UI and integration.

## 6. Implementation Patterns (Prompts)

### Tier 3 Implementation Prompt Example:
```text
Lead the implementation of [PRD-ID].

### PHASE 1: BLUEPRINT (Stop here)
1. Create a detailed implementation plan.
2. STOP and invoke the QA Subagent (Claude) with `agentProfileId: 'qa'` and `execute: true` to review this plan.

### PHASE 2: CORE LOGIC
3. Implement the service logic according to the audited plan.
4. STOP and invoke the QA Subagent to audit the service implementation.

### PHASE 3: UI & FINALIZATION
5. Finish the UI components.
6. Invoke the QA Subagent for final test verification.
```

## 7. Benefits
- **Security**: Hardware-sync and security-sensitive logic are never "guessed" by a lower-tier model.
- **Consistency**: The Architect ensures that patterns established in early PRDs are strictly followed in later ones.
- **Transparency**: Every "Peek" creates a sub-task record, providing a clear audit trail of who approved what and why.
