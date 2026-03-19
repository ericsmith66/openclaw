# PRD-AH-009A: System Readiness Checks + Admin System Health Dashboard (MVP)

Source: `knowledge_base/epics/Agent-hub/vision-agent_hub-workflow.md` §11 → `PRD-MVP-01`.

---

## Problem

We need a fast way to validate that the system can support SDLC iteration (proxy/queue/cable/cloudflare).

## User story

As the owner, I can open a simple system health page and see whether the critical runtime components are healthy.

---

## A) What SAP/CWA produce (workflow output)

SAP/CWA do more than “interpret results”. They help define, evolve, and validate the health checks.

Expected SAP/CWA contributions:

- **Define health checks** (what “healthy” means for proxy/workers/cable/cloudflare).
- **Build or extend endpoints/checks** as needed (either in the app or by calling existing endpoints).
- **Interpret results** and decide whether it’s safe to proceed with SDLC work.

Examples of SAP/CWA behavior:

- If proxy is unhealthy, do not proceed with SDLC work; create a backlog artifact or escalation note.
- If workers are on a different version than web, halt workflow execution until reconciled.
- If Cloudflare endpoints fail, route to infrastructure troubleshooting.

---

## B) What we build (platform/engineering work)

We build the health dashboard page, plus an extensible way to add/maintain checks.

Minimum platform implementation:

- A health controller/page that aggregates check results
- Check implementations for:
  - Proxy
  - Worker/version consistency
  - ActionCable
  - Cloudflare endpoints
- A place to configure endpoints (env) and a place to add new checks later

---

## C) UI elements introduced/changed

- New page: **Admin System Health** (operator-facing; simple table/cards)
- No changes required to the Agent Hub conversation UI for this PRD (other than adding a link, if desired)

---

## Functional requirements

- A minimal “Admin System Health” page that shows:
  - Proxy server reachable and serving model list/chat (or last successful check)
  - Job queue/worker health and whether workers are alive
  - ActionCable websocket connectivity status
  - Cloudflare endpoint reachability (HTTP ok) (env-configured)
  - Optional: artifact counts by phase + recent transitions (if artifact table exists)

---

## Acceptance criteria

- AC1: Proxy health: page shows OK/Fail with timestamp of last check.
- AC2: Worker health: page shows worker status and code version (git SHA or build identifier) for web + worker.
- AC3: Cloudflare health: page shows OK/Fail for configured endpoints.

Additional acceptance criteria:

- AC4: Health checks are extensible: SAP/CWA can add at least one new check (or tighten an existing check) without refactoring the whole page.
- AC5: Failures include actionable diagnostics (e.g., error message / last successful timestamp / endpoint tested).

---

## Notes/assumptions

- “Same codebase” means “same git SHA” (or similar deploy identifier).
- Cloudflare endpoints list is configured via env.
