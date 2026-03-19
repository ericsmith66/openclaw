# Epic 2: Implementation Status

**Epic**: Epic 2 — WorkflowEngine & Quality Gates (CLI-First)
**Status**: Not Started
**Last Updated**: 2026-03-10

---

## Overview

Track completion status, blockers, key decisions, and branch merges for Epic 2 PRDs.

Update this document after each PRD completion per RULES.md Φ12.

---

## PRD Status Summary

| PRD | Title | Status | Branch | Merged | Completion Date | Notes |
|-----|-------|--------|--------|--------|-----------------|-------|
| 2-01 | Parallel Task Dispatch via Solid Queue | Not Started | `epic-2/prd-01-parallel-dispatch` | No | - | |
| 2-02 | Artifact Model & Structured Output | Not Started | `epic-2/prd-02-artifact-model` | No | - | |
| 2-03 | `bin/legion score` Command | Not Started | `epic-2/prd-03-score-command` | No | - | |
| 2-04 | Task Re-Run & Error Recovery | Not Started | `epic-2/prd-04-task-rerun` | No | - | |
| 2-05 | PromptBuilder Service (Liquid) | Not Started | `epic-2/prd-05-prompt-builder` | No | - | |
| 2-06 | Conductor Agent & WorkflowEngine | Not Started | `epic-2/prd-06-conductor-agent` | No | - | |
| 2-07 | QualityGate Base Class | Not Started | `epic-2/prd-07-quality-gate` | No | - | |
| 2-08 | ArchitectGate + QAGate | Not Started | `epic-2/prd-08-gates` | No | - | |
| 2-09 | Retry Logic with Context Accumulation | Not Started | `epic-2/prd-09-retry-logic` | No | - | |
| 2-10 | `bin/legion implement` Full Loop | Not Started | `epic-2/prd-10-implement-loop` | No | - | |

---
## PRD 2-01: Parallel Task Dispatch via Solid Queue

**Status**: Not Started
**Branch**: `epic-2/prd-01-parallel-dispatch`
**Dependencies**: Epic 1 (complete)

### Scope

- Epic 1's `PlanExecutionService` dispatches ready tasks one at a time in a synchronous loop (`ready.first`). For PRDs with parallel-eligible tasks, this leaves performance on the table — two independent tasks that could run simultaneously instead wait in line.
- PRD 2-01 replaces the synchronous dispatch loop with Solid Queue background jobs. A new `TaskDispatchJob` encapsulates the dispatch of a single task. When a task completes, the job checks if new tasks are now ready (dependencies satisfied) and enqueues them. A per-project PostgreSQL advisory lock prevents two workflows from editing the same project simultaneously. The human controls parallelism via `--sequential` and `--concurrency` flags.

### Acceptance Criteria

- [ ] AC-1: Given 3 ready tasks with no dependencies between them, `PlanExecutionService` in parallel mode enqueues 3 `TaskDispatchJob`s simultaneously (verified by Solid Queue job count)
- [ ] AC-2: Given `--sequential` flag, tasks dispatch one at a time in dependency order (Epic 1 behavior preserved)
- [ ] AC-3: Given `--concurrency 2` flag, at most 2 tasks run simultaneously (third waits for a slot)
- [ ] AC-4: Given Task A completes and Task B depends on Task A, a `TaskDispatchJob` for Task B is automatically enqueued
- [ ] AC-5: Given all tasks reach terminal state, a completion callback fires (logged as WorkflowEvent or hook call)
- [ ] AC-6: Given a task raises an exception, its status is `failed`, `last_error` contains the exception message, and `completed_at` is set
- [ ] AC-7: Given two tasks reference the same file path (e.g., both touch `app/models/user.rb`), the second task is held in `pending` until the first completes
- [ ] AC-8: Given a project advisory lock is held by execution #1, a second `execute-plan` command for the same project raises `WorkflowLockError` with execution #1's ID
- [ ] AC-9: Given a successful task dispatch, `Task.queued_at` is set when enqueued, `Task.started_at` when `perform` begins, `Task.completed_at` when done
- [ ] AC-10: Solid Queue worker starts via `bin/dev` (Procfile.dev entry exists and works)
- [ ] AC-11: `config/solid_queue.yml` configures `task_dispatch` queue with 3 threads
- [ ] AC-12: Task status enum includes `queued` value between `ready` and `running`

### Blockers

- None

### Key Decisions

- D-2: Solid Queue for parallel dispatch
- D-9: Per-project PostgreSQL advisory lock
- D-25: Parallel file conflict is a blocking validation (auto‑serialize conflicting tasks)
- D-35: Concurrency enforcement via application‑level count check (`Task.where(status: [:queued, :running]).count < concurrency`). Soft cap, not hard mutex.

### Completion Date

-

### Notes

-