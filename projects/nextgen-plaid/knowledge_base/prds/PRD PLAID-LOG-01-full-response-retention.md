# PRD: PLAID-LOG-01 — Persist Full Plaid API Responses (30-day Retention)

## Overview
Improve operational debugging and data reconciliation by persisting the **full JSON response** from Plaid API calls (e.g., holdings, transactions, investment transactions, liabilities). Persisted responses must be queryable, correlated to the existing `PlaidApiCall` cost/usage tracking, and automatically retained for **30 days**.

This PRD explicitly assumes we **do not** use an opt-in approach; the system should store responses by default.

## Log Requirements
Junie read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`

## Goals
- Make Plaid data discrepancies debuggable without re-running expensive/slow Plaid calls.
- Enable “what did Plaid actually return?” analysis for:
  - missing positions/quantities
  - stale holdings
  - missing investment transactions
  - missing `ticker_symbol`/identifier fields
- Keep the persisted history bounded via **automatic 30-day retention**.

## Non-Goals
- Storing LLM prompts/responses (out of scope).
- Replacing Rails logs as a general log store.
- Building a full “event sourcing” system for all Plaid data.
- Redaction/PII minimization (see Risks); this PRD requires storing the full response.

## Requirements

### Functional
1. **Persist full Plaid responses**
   - For each Plaid API call initiated by the app, persist the complete JSON response payload.
   - The stored payload must be queryable by:
     - Plaid `request_id`
     - endpoint (e.g., `/investments/holdings/get`)
     - product/category (e.g., `investments_holdings`, `transactions`, `liabilities`)
     - called-at timestamp
     - PlaidItem / user (directly or indirectly via foreign keys)

2. **Storage: JSONB**
   - Store the full response body in a `jsonb` field.
   - The design may either:
     - add a `response_json` column to `plaid_api_calls`, or
     - create a new table (recommended if we want to keep `plaid_api_calls` lightweight).

3. **Retention: 30 days**
   - Automatically delete records older than 30 days.
   - Retention job must be safe, idempotent, and run at least daily.

4. **Error responses**
   - For failed calls, persist the error response payload when available (e.g., Plaid error JSON).
   - Associate error payload with the same correlation key (`request_id`) if present.

5. **Performance & bounded size**
   - Writes must not block the sync flow unreasonably.
   - The system should support large payloads (holdings + securities can be large).
   - The PRD does not require compression, but the implementation may include it if it preserves “full response” semantics.

### Non-Functional
1. **Security**
   - This feature stores sensitive financial data (account masks, holdings, transactions).
   - Access must be restricted to owner/admin views (e.g., Mission Control) and not exposed to normal users.
   - Do not log these payloads to STDOUT or Rails log files.

2. **Reliability**
   - If persistence fails (DB issue), the Plaid sync should still complete when possible.
   - Persistence failure should be observable via error logs/alerts.

3. **Maintainability**
   - Stored payload format should remain as returned by Plaid (no transformations), to preserve forensic value.
   - Correlate payloads with `PlaidApiCall` rows for easy cost/request linking.

## Proposed Data Model

### Option A (simpler): Add JSONB to `plaid_api_calls`
Add fields:
- `plaid_api_calls.response_json` (`jsonb`, null: true)
- `plaid_api_calls.error_json` (`jsonb`, null: true)

Pros:
- Single table: cost + request_id + response in one place

Cons:
- `plaid_api_calls` becomes “heavy” and may slow list queries

### Option B (recommended): New table `plaid_api_responses`
Create table:
- `plaid_api_responses`
  - `id`
  - `plaid_api_call_id` (FK to `plaid_api_calls`, optional if we want to support legacy rows)
  - `plaid_item_id` (FK, for filtering by institution/item)
  - `endpoint` (string)
  - `product` (string)
  - `request_id` (string, indexed)
  - `response_json` (jsonb)
  - `error_json` (jsonb, optional)
  - `called_at` (datetime)
  - `created_at`/`updated_at`

Indexes:
- `index_plaid_api_responses_on_called_at`
- `index_plaid_api_responses_on_request_id`
- `index_plaid_api_responses_on_plaid_item_id`
- optional GIN index on `response_json` if we need JSON-path queries (only if needed)

Pros:
- Keeps `plaid_api_calls` lean
- Easier to enforce retention and storage policies

Cons:
- Requires join for cost correlation

## Implementation Notes (High Level)
- Add a small wrapper around Plaid client calls in the sync services/jobs that:
  - captures `response.to_hash` (or serializable structure)
  - writes it to DB as `jsonb`
  - stores Plaid `request_id` and endpoint
- Implement a recurring SolidQueue task:
  - daily cleanup: delete rows where `called_at < 30.days.ago`

## Acceptance Criteria
- For a holdings sync, a developer can find the full response JSON via `request_id` and endpoint.
- For a transactions sync (including investment transactions), the full response is persisted.
- Retention job removes payloads older than 30 days.
- No full Plaid responses are written to Rails logs.
- Mission Control/admin tooling can locate the payload given a PlaidItem and a time window.

## Test Cases
- Unit: persistence layer stores JSONB, preserves keys/values, and associates correctly.
- Integration: run a stubbed Plaid response through the sync service and assert a response row exists with:
  - correct `endpoint`, `request_id`, and `response_json`
- Retention: create old rows (>30 days) and assert cleanup job deletes them.

## Risks / Tradeoffs
- **Sensitive data retention**: storing full Plaid responses increases data-at-rest sensitivity.
- **DB growth**: holdings + transactions payloads can be large; 30-day retention limits growth but may still be significant.
- **Access control**: accidental exposure must be prevented (no default UI rendering).

## Follow-ups
- [ ] Decide between Option A vs Option B data model.
- [ ] Decide whether to store both success + error payloads.
- [ ] Decide whether to add compression (must still be retrievable as full JSON).
