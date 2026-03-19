# PRD-AH-004C: Metadata & Audit Storage
## Overview
Detailed logging for AI parameters/approvals per Vision 2026.
## Requirements
- Functional: Store temp/top-p; approval user.
- Non-Functional: Immutable audit.
- Rails Guidance: JSONB attributes.
- Logging: Full metadata.
- Disclaimers: None.
## Architectural Context
Audit trail.
## Acceptance Criteria
- Save model params.
- Save approver_id.
- Audit log entry.
- Queryable via JSONB.
- No PII in metadata.
- Logs full hash.
- Performance indexed.
## Test Cases
- RSpec: metadata[:temp] eq 0.7.
- Integration: check logs for approval user.
## Workflow for Junie
- Pull main; branch feature/prd-ah-004c.
- Claude Sonnet 4.5.
- Plan before code.
- Test, commit green.
  Junie: Review, ask, plan, implement—green only.
