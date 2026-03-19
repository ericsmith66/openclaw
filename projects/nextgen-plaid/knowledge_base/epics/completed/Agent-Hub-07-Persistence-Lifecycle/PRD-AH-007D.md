# PRD-AH-007D: External Backlog Integration (JSONB)
## Overview
Enable persisting approved artifacts (epics, PRDs) to an external DB-backed backlog using JSONB, separate from development/production environments.

## Requirements
- **Functional**: `/backlog` command; Persistence to a `BacklogItem` model or external service; JSONB structure.
- **Non-Functional**: Multi-tenant/external focus (EAS: Persist outside all environments).
- **Rails Guidance**: Service object `BacklogService`; New table `backlog_items` with `metadata` JSONB.
- **Traceability**: Original Spec (User Capabilities); Remaining Capabilities Doc (Decisions & EAS Feedback).

## Acceptance Criteria
- Commands like `/backlog PRD-0070` extract the artifact and save it to the `backlog_items` table.
- Backlog items store priority, dependencies, and full content in JSONB.
- UI provides feedback that the item was successfully sent to the backlog.

## Test Cases
- **Integration**: Type `/backlog My Feature`; verify a new `BacklogItem` record is created with the correct metadata.
