### AiderDesk Pull Request Implementation Plan

This document outlines the step-by-step plan for implementing and submitting the proposed Pull Requests to the upstream `aider-desk` repository.

---

#### 📋 PR 1: Agent Orchestration & Task Creation
**Goal**: Fix issues where sub-tasks did not correctly inherit specialized agent profiles and models.

1.  **GitHub Issue Creation**:
    - Title: `[Bug] Sub-tasks do not inherit Agent Profile model/provider settings`
    - Description: Use the problem description and reproduction steps from `AIDER_DESK_PR_STRATEGY.md`. Mention that new tasks default to parent task settings, ignoring the requested `agentProfileId` configuration.
2.  **Branch Setup**:
    - `git checkout -b fix/agent-orchestration-logic`
3.  **Implementation**:
    - Apply changes to `src/common/types.ts` (API schema).
    - Apply changes to `src/main/agent/agent-profile-manager.ts` (Name lookup fallback).
    - Apply changes to `src/main/agent/tools/tasks.ts` (Tool description and param passing).
    - Apply changes to `src/main/project/project.ts` (Task initialization logic).
    - Update `llms.txt` and relevant docs to include the list of standard sub-agent profiles.
4.  **Testing**:
    - **Unit Test**: Create/update tests for `AgentProfileManager` to verify name-based lookups.
    - **Integration Test**: Verify that calling `tasks---create_task` with an `agentProfileId` results in a task with the correct model.
5.  **Verification**:
    - `npm run lint:check`
    - `npm run typecheck`
    - `npm run test` (Ensuring all node/web tests pass)
6.  **Submission**:
    - Push branch and create PR referencing the GitHub issue.

---

#### 📋 PR 2: Ollama Aider Integration
**Goal**: Fix model name prefix mismatch for Ollama models when used with Aider.

1.  **GitHub Issue Creation**:
    - Title: `[Bug] Ollama models fail in Aider due to incorrect name prefix`
    - Description: Detail the `ollama_chat/` vs `ollama/` prefix issue.
2.  **Branch Setup**:
    - `git checkout -b fix/ollama-aider-prefix`
3.  **Implementation**:
    - Apply changes to `src/main/models/providers/ollama.ts`.
4.  **Testing**:
    - **Unit Test**: Run existing `src/main/models/providers/__tests__/ollama.test.ts`.
5.  **Verification**:
    - `npm run lint:check`
    - `npm run typecheck`
    - `npm run test`
    - Manual check using an Ollama model to run an Aider tool.
6.  **Submission**:
    - Push branch and create PR.

---

#### 📋 PR 3: Platform Performance & Stability
**Goal**: Reduce CPU overhead during context updates and prevent IPC listener warnings.

1.  **GitHub Issue Creation**:
    - Title: `[Optimization] Debounce token counting and increase IPC max listeners`
    - Description: Describe CPU spikes during bulk file additions and `MaxListenersExceededWarning` in multi-agent flows.
2.  **Branch Setup**:
    - `git checkout -b perf/platform-stability`
3.  **Implementation**:
    - Apply changes to `src/main/task/task.ts` (Debouncing).
    - Apply changes to `src/preload/index.ts` (Max listeners).
4.  **Testing**:
    - Verify that adding a large directory to a task no longer causes a sustained 100% CPU spike.
    - Monitor console logs for `MaxListenersExceededWarning` during sub-agent heavy tasks.
5.  **Verification**:
    - `npm run lint:check`
    - `npm run typecheck`
    - `npm run test`
    - `npm run dev` and manual stress test.
6.  **Submission**:
    - Push branch and create PR.

---

#### 📋 PR 4: Test Infrastructure Improvements
**Goal**: Ensure the vitest environment supports web features like `localStorage`.

1.  **GitHub Issue Creation**:
    - Title: `[Test] Add storage mocks to vitest setup`
    - Description: Explain that components using `localStorage` crash in JSDOM tests.
2.  **Branch Setup**:
    - `git checkout -b test/jsdom-storage-mocks`
3.  **Implementation**:
    - Apply changes to `src/renderer/src/__tests__/setup.ts`.
4.  **Testing**:
    - Run renderer tests: `npm run test:web`.
5.  **Verification**:
    - `npm run lint:check`
    - `npm run typecheck`
    - `npm run test`
    - Verify that tests previously failing due to `ReferenceError: localStorage` now pass.
6.  **Submission**:
    - Push branch and create PR.

---

#### 🚀 Execution Guidelines
- **Atomic PRs**: Strictly follow the one-feature-per-PR rule. Do not combine unrelated fixes.
- **Code Style**: Adhere to existing naming conventions, indentation, and project-specific patterns.
- **Commits**: Use descriptive, atomic commit messages following the Conventional Commits specification.
- **Review**: Self-review the diff for any accidental changes or debug logs before pushing.
- **Documentation**: Update markdown documentation (e.g., `llms.txt`, tool descriptions) for any functional changes.
