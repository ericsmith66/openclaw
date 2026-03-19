# Junie Task Log — PRD 5-01: Saved Account Filters
Date: 2026-02-04  
Mode: Brave  
Branch: epic-5-holding-grid  
Owner: Junie (AI)

## 1. Goal
- Implement `SavedAccountFilter` (model + CRUD + reusable selector UI) so users can save and apply account filter sets across the app.

## 2. Context
- PRD: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/PRD-5-01-saved-account-filters.md`
- Epic overview: `knowledge_base/epics/wip/NextGen/Epic-5-Holdings-Grid/0000-overview-epic-5.md`
- Constraints: follow repo safety rails (no destructive DB commands), use Minitest, and keep diffs focused.

## 3. Plan
1. Create `SavedAccountFilter` persistence (migration + RLS policy) and model validations.
2. Add scoped CRUD controller + views.
3. Add a reusable ViewComponent selector and integrate into holdings grid entry point.
4. Add tests (model/controller/component) and run targeted test commands.
5. Document manual verification steps and update Epic implementation status when complete.

## 4. Work Log (Chronological)
- 2026-02-04: Reviewed Epic 5 overview, Epic 5 consolidated doc, and PRD 5-01. Created branch `epic-5-holding-grid`. Created this task log.
- 2026-02-04: Implemented `SavedAccountFilter` (migration + model + CRUD) and integrated a selector into Net Worth → Holdings. Added `Reporting::DataProvider#with_account_filter` to apply criteria. Added tests and ran targeted suite.

## 5. Files Changed
- `db/migrate/20260204124500_create_saved_account_filters.rb`
- `app/models/saved_account_filter.rb`
- `app/models/user.rb`
- `config/routes.rb`
- `app/controllers/saved_account_filters_controller.rb`
- `app/views/saved_account_filters/*`
- `app/services/reporting/data_provider.rb`
- `app/controllers/net_worth/holdings_controller.rb`
- `app/components/saved_account_filter_selector_component.*`
- `app/components/net_worth/holdings_summary_component.*`
- `app/views/net_worth/holdings/show.html.erb`
- `test/models/saved_account_filter_test.rb`
- `test/controllers/saved_account_filters_controller_test.rb`
- `test/components/saved_account_filter_selector_component_test.rb`

## 6. Commands Run
- `git switch -c epic-5-holding-grid` — created and switched to branch
- `bin/rails db:migrate RAILS_ENV=test`
- `bin/rails test test/models/saved_account_filter_test.rb test/controllers/saved_account_filters_controller_test.rb test/components/saved_account_filter_selector_component_test.rb test/components/net_worth/holdings_summary_component_test.rb`

## 7. Tests
- ✅ 11 runs, 0 failures (targeted suite listed above)

## 8. Decisions & Rationale
- Decision: Use a `jsonb` `criteria` column with minimal validation (presence of at least one supported key) in v1.
    - Rationale: PRD calls for flexible criteria schema; strict JSON schema validation can be added later without blocking CRUD/UI.

## 9. Risks / Tradeoffs
- RLS policies require correct `app.current_user_id` session setting; app-level scoping will still be enforced in controllers.

## 10. Follow-ups
- [ ] Ensure `knowledge_base/data-dictionary.md` includes the criteria schema (or add if missing).
- [ ] Update Epic 5 `0001-IMPLEMENTATION-STATUS.md` when PRD 5-01 is complete.

## 11. Outcome
- Implemented and ready for review (no commit yet).

## 12. Commit(s)
- Pending

## 13. Manual steps to verify and what user should see
1. Create a saved filter (e.g., "Trust Accounts") with `ownership_types: ["Trust"]`.
2. Confirm it appears in the selector (and "All Accounts" remains available).
3. Select the filter and confirm the holdings grid is scoped accordingly.
4. Attempt to create a duplicate name; expect a validation error.
5. Delete the filter; confirm it disappears from the selector.
6. Sign in as a different user; confirm the filter is not visible/accessible.
