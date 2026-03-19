### Technical Documentation: Eureka-Homekit Agent Configuration & Complexity Model

This document outlines the architectural implementation of subagent orchestration within the `eureka-homekit` project, specifically focusing on the `architect` agent's role in complexity-driven workflows.

### 1. Project Configuration Overview
The `eureka-homekit` project uses a localized `.aider-desk` configuration to override global behaviors and define a specialized agent swarm.

*   **Location**: `/Users/ericsmith66/development/agent-forge/projects/eureka-homekit/.aider-desk`
*   **Key Directories**:
    *   `agents/`: Contains JSON configurations and markdown rules for project-specific agents.
    *   `knowledge_base/strategy/`: Houses the strategic definitions for the complexity model.

### 2. The Agent Swarm
The system "promotes" specialized subagents to first-class citizens, ensuring they are addressable by the task engine with specific models (primarily Claude 3.5 Sonnet).

| Agent | Primary Role | Key Configuration |
| :--- | :--- | :--- |
| **Architect** | Strategic planning & complexity scoring | `claude-3-5-sonnet`, `useTaskTools: true` |
| **QA** | Security & logic audits ("The Peeker") | Phase-Gate auditing based on Tier |
| **UI** | ViewComponent & Tailwind implementation | Specialized styling rules |
| **Refactor** | Codebase cleanup & architectural updates | Model-specific refinement logic |
| **Greenfield**| New feature scaffolding | Boilerplate & standard pattern generation |

### 3. Complexity Matrix & Scoring Model
The **Complexity Matrix** (`knowledge_base/strategy/complexity_matrix.json`) is the source of truth used by the **Architect** to categorize tasks and determine the required audit density.

#### Tier Definitions:
*   **Tier 1 (Low)**: UI updates, text changes, or read-only components.
    *   *Strategy*: Final Audit only at the end of the task.
*   **Tier 2 (Medium)**: Internal logic, state management, standard DB writes.
    *   *Strategy*: Service Audit + Final Audit.
*   **Tier 3 (High)**: External hardware synchronization (HomeKit), security-sensitive logic, complex concurrency.
    *   *Strategy*: **Blueprint Audit** (Plan Review) + Service Audit + Final Audit.

### 4. The "Strategic Architect" Workflow
The Architect agent analyzes Epics and PRDs against the matrix to generate a **Strategic Roadmap**.

1.  **Analysis**: The Architect reviews the PRD for risk factors (e.g., Garage Door confirmation logic).
2.  **Scoring**: It assigns a Tier (1-3) and defines **Audit Milestones**.
3.  **Roadmap Generation**: Produces a JSON roadmap that the automation script uses to inject "Phase-Gates" into the Lead Agent's prompt.

### 5. The "Peeking Strategy" (Dynamic Handoff)
For Tier 3 tasks, the system enforces a **Phase-Gate** workflow where the Lead Agent is forced to STOP and invoke the **QA Subagent** at critical junctions:

*   **Phase 1 (Blueprint)**: The Lead Agent creates a plan; QA must audit the plan before any code is written.
*   **Phase 2 (Core Logic)**: QA audits the implementation of security-sensitive services (e.g., hardware sync).
*   **Phase 3 (Verification)**: Final Minitest audit before completion.

This "Model Inheritance Bypass" ensures that high-risk logic is always reviewed by a higher-reasoning model (Claude) regardless of the Lead Agent's base model.
