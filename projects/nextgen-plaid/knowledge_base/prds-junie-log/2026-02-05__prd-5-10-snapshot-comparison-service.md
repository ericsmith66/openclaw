# Junie Task Log — PRD 5-10: Snapshot Comparison Service
Date: 2026-02-05  
Mode: Brave  
Branch: epic-5-holding-grid  
Owner: Junie

## 1. Goal
- Implement `HoldingsSnapshotComparator` to compare two holdings snapshots (or snapshot vs live) and compute overall + per-security performance metrics.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/PRD-5-10-snapshot-comparison-service.md`
- Depends on snapshot JSON produced by PRD 5-09 and snapshot model from PRD 5-08.
- Live holdings are obtained via `HoldingsGridDataProvider` (which returns grouped rows); comparator should compare aggregated parents per security.

## 3. Plan
1. Create `app/services/holdings_snapshot_comparator.rb` with O(n) matching and defensive normalization.
2. Add Minitest coverage for overall/per-security metrics and edge cases (zero start value, added/removed/changed).
3. Run scoped tests.
4. Update Epic 5 implementation status.

## 4. Work Log (Chronological)
- Implement comparator service with:
  - `security_id` primary matching
  - fallback matching by `ticker_symbol + name`
  - structured output: `overall`, `securities`, and `meta`
  - warnings logged for fallback matches and invalid payloads
  - optional caching (30 minutes) per PRD guidance
- Add service tests covering snapshot-vs-snapshot and snapshot-vs-live paths.

## 5. Files Changed
- `app/services/holdings_snapshot_comparator.rb` — New comparator service for snapshot-vs-snapshot and snapshot-vs-live.
- `test/services/holdings_snapshot_comparator_test.rb` — Unit tests covering deltas, overall metrics, zero-start handling, and live-provider path.
- `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0001-IMPLEMENTATION-STATUS.md` — Mark PRD 5-10 implemented and add changelog entry.
- `knowledge_base/prds-junie-log/2026-02-05__prd-5-10-snapshot-comparison-service.md` — This task log.

Notes:
- This working tree also includes pending (uncommitted) PRD 5-09-related files/changes from earlier work on the same branch (not re-documented here).

## 6. Commands Run
- `git diff --stat` — inspected current working changes
- `git diff` — inspected current working changes
- `git status --porcelain` — reviewed uncommitted/untracked files
- `bin/rails test test/services/holdings_snapshot_comparator_test.rb` — ✅ pass

## 7. Tests
- `bin/rails test test/services/holdings_snapshot_comparator_test.rb` — ✅ pass

## 8. Decisions & Rationale
- Decision: Compare *grouped parent rows* for live holdings.
  - Rationale: `HoldingsGridDataProvider` groups holdings across accounts; comparison should be per-security rather than per-account for PRD 5-10.
- Decision: Return `nil` return percentage when start value is `0`.
  - Rationale: Avoid division-by-zero and match PRD edge-case requirement.

## 9. Risks / Tradeoffs
- Fallback matching (`ticker_symbol + name`) can collide for non-unique names; warnings are logged to help investigate.

## 10. Follow-ups
- [ ] Consider enriching mismatch logs with snapshot IDs and security IDs if needed for debugging.
- [ ] If comparisons for large portfolios exceed ~2s, revisit caching strategy and payload size.

## 11. Outcome
- Implemented `HoldingsSnapshotComparator` service with caching, safe return calculation, O(n) matching, and a live comparison path using `HoldingsGridDataProvider`.
- Added Minitest coverage for core comparison scenarios and edge cases.

## 12. Commit(s)
- Pending

## 13. Manual steps to verify and what user should see
1. Create two snapshots for the same user (e.g., via console using `CreateHoldingsSnapshotService` or the PRD 5-09 job).
2. Ensure a known change between snapshots:
   - Add a new holding (e.g., buy `TSLA`)
   - Remove a holding (e.g., sell `GE`)
   - Change quantity/value for an existing holding (e.g., buy more `AAPL`)
3. In Rails console, run:
   ```ruby
   result = HoldingsSnapshotComparator.new(
     start_snapshot_id: snapshot1.id,
     end_snapshot_id: snapshot2.id,
     user_id: user.id
   ).call
   ```
4. Expected output:
   - `result[:overall][:start_value]` and `result[:overall][:end_value]` are numeric.
   - `result[:overall][:delta_value] == end_value - start_value`.
   - `result[:overall][:period_return_pct]` matches `((end-start)/start)*100` when start is non-zero; otherwise `nil`.
5. Expected per-security results in `result[:securities]`:
   - A changed holding has `status: :changed`, `delta_qty` non-zero (if qty changed) and `delta_value` reflecting market value delta.
   - A newly-added holding has `status: :added`, `start_value: 0`, `return_pct: nil`.
   - A removed holding has `status: :removed`, `end_value: 0`, negative `delta_value`.
6. Snapshot vs live:
   ```ruby
   result = HoldingsSnapshotComparator.new(
     start_snapshot_id: snapshot1.id,
     end_snapshot_id: :current,
     user_id: user.id
   ).call
   ```
   Expected: same output shape; uses live holdings for the end side.
7. Edge case: if any position has `start_value == 0`, expect `return_pct` to be `nil` and no crash.
