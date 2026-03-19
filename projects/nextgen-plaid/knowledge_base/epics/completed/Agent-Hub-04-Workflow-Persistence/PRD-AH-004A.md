# PRD-AH-004A: AiWorkflowRun Model & Migration
## Overview
Durable storage for AI runs per Vision 2026.
## Requirements
- Functional: CRUD for runs.
- Non-Functional: JSONB metadata.
- Rails Guidance: AiWorkflowRun; belongs_to :user.
- Logging: JSON lifecycle.
- Disclaimers: None.
## Architectural Context
PG; Metadata schema.
## Acceptance Criteria
- Migration runs.
- Model validates owner.
- Metadata stores hash.
- Scopes for status.
- Associations work.
- Logs creation.
- RLS verified.
## Test Cases
- RSpec: model validation pass.
- Integration: save run; assert count.
## Workflow for Junie
- Pull main; branch feature/prd-ah-004a.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
