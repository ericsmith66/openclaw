# Subagent Orchestration & Prompting Strategy

## 1. The Core Problem: "Discovery Loops"
As projects grow (like Eureka-Homekit), agents tend to fall into "Discovery Loops"—exhausting their iteration budget by re-researching patterns they have already encountered or that are already defined in the Strategic Roadmap. This leads to the "Hard-Coding" trap, where the user must provide hyper-specific prompts to force execution.

## 2. The Plan-First Execution Strategy
To maintain high-level orchestration, we must move from **Instruction-Based Prompts** to **Plan-Based Execution**.

### 2.1 Visible Guardrails: Architect's Responsibility
It is the job of the **Architect (or User)** to ensure that all technical guardrails, anchors, and directives are recorded in the **Plan/Roadmap** rather than being buried in "Magic Config" files or hidden system prompts.

This transparency ensures:
1.  **Lead Agent Compliance**: The agent can see the specific files and patterns it must follow without guessing.
2.  **Auditability**: The QA subagent (Claude) reviews the implementation against the visible plan, not a hidden directive.
3.  **Durable Context**: Knowledge is recorded in the project history, making the system self-documenting.

#### 2.2 The Execution Context (The "Save Point")
To prevent the agent from "forgetting" its location or operational state, the Roadmap MUST include a **CURRENT EXECUTION CONTEXT** block. This block acts as a mandatory "State Persistence Anchor" that the agent reads at the start of every iteration.
- **Project Root**: Defines the active working directory.
- **Active Task**: Defines the specific PRD or task ID.
- **Phase Gates**: Lists the mandatory audits and document writes required to move forward.
- **Directives**: Hard-coded safety or architectural rules.

## 3. Standardized Prompting Guardrails
When starting any PRD or Epic task, the prompt should be simple and high-level, pointing the agent to the **CURRENT EXECUTION CONTEXT** in the Roadmap.

### Template: The "Roadmap-Driven" Prompt
> "Implement [PRD-ID] according to the **Strategic Roadmap** at [PATH].
>
> **Execution Guardrails:**
> 1. **SOURCE OF TRUTH**: The Roadmap contains all technical anchors (file paths, patterns, and security requirements). Follow them strictly.
> 2. **NO-DISCOVERY ZONE**: Skip exploratory searches. Use the paths provided in the Roadmap. Move directly to **Phase 1: Blueprint**.
> 3. **PHASE GATES**: You must submit a Blueprint and pass a **QA Audit (Claude)** before modifying any production code.
> 4. **REUSE POLICY**: Reuse [SPECIFIC SHARED COMPONENT] for all applicable interactions."

## 4. Phase-Gate Architecture
To prevent iteration exhaustion, the agent must be forced through specific "Gates":

| Phase | Action | Exit Criteria |
| :--- | :--- | :--- |
| **1. Blueprint** | Write the implementation plan to the `0001-IMPLEMENTATION-STATUS` doc. | Plan exists in file. |
| **2. Audit** | Invoke QA Subagent (Claude) to review the Blueprint against Security Directives. | Claude "Approved" log entry. |
| **3. Execution** | Implement the code in small, testable chunks. | Tests pass. |
| **4. Post-Mortem** | Update the Roadmap status and create audit logs. | Roadmap marked 'Complete'. |

## 5. Strategy for PRD-5-07 and Beyond
For the remainder of Epic 5 and future Epics, we will use **Roadmap-Driven Prompts**. If an agent fails to follow the roadmap, the "Correction" is not to hard-code the fix, but to **update the Knowledge Base** (e.g., the after-action report or a pattern doc) and tell the agent: *"The pattern for this is now documented in the Knowledge Base. Follow it."*

This builds a "Project Memory" that the agent can query, rather than relying on the user's prompt memory.
