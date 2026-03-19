---

# Junie Task Log — PRD-1-04 Other Income Model & Integration
Date: 2026-01-19  
Mode: Brave  
Branch: epic-1-Plaid-Sync-Integrity  
Owner: junie

## 1. Goal
- Add an `OtherIncome` model that users can CRUD for their own income sources, with strict per-user access control.

## 2. Context
- Source PRD: `knowledge_base/epics/nexgen/Epic-1/0040-PRD-1-04.md`
- Epic 1 context: user-maintainable income sources (later integration into Epic 2 snapshots/net worth).
- Scope clarification (stakeholder): implement PRD-1-04 model + user-owned CRUD now; defer snapshot aggregation work.

## 3. Plan
1. Add `OtherIncome` model + migration with required fields and `belongs_to :user`.
2. Add user-only CRUD endpoints + views, enforcing ownership via Pundit and query scoping.
3. Add tests for model validation and controller scoping.
4. Run migrations and full test suite.

## 4. Work Log (Chronological)
> Keep entries short and timestamped if helpful.

- 2026-01-19: Implemented `OtherIncome` model/migration and user association.
- 2026-01-19: Added user-scoped controller/routes/views and Pundit policy enforcing per-user access.
- 2026-01-19: Added model + controller tests for validations and access control.

## 5. Files Changed
List every file added/modified/deleted with a brief note.

- `app/models/other_income.rb` — new model with validations
- `db/migrate/20260119124100_create_other_incomes.rb` — creates `other_incomes` table
- `app/models/user.rb` — adds `has_many :other_incomes`
- `app/controllers/other_incomes_controller.rb` — user-scoped CRUD with Pundit
- `app/policies/other_income_policy.rb` — user-only authorization + scope
- `app/views/other_incomes/*` — basic CRUD views
- `config/routes.rb` — adds `resources :other_incomes`
- `test/models/other_income_test.rb` — validation tests
- `test/controllers/other_incomes_controller_test.rb` — auth/scoping tests
- `knowledge_base/prds-junie-log/2026-01-19__prd-1-04-other-income-model.md` — task log (this file)

## 6. Commands Run
Record commands that were run locally/CI and their outcomes.  
Use placeholders for any sensitive arguments.

- `bin/rails db:migrate` — ✅ migrated
- `bin/rails test test/models/other_income_test.rb test/controllers/other_incomes_controller_test.rb` — ✅ pass
- `bin/rails test` — ✅ pass (full suite)

## 7. Tests
Record tests that were run and results.

- `bin/rails test test/models/other_income_test.rb test/controllers/other_incomes_controller_test.rb` — ✅ pass
- `bin/rails test` — ✅ pass

## 8. Decisions & Rationale
Document key decisions and why they were made.

- Decision: Enforce user ownership via both `policy_scope` (query scoping) and Pundit authorization.
    - Rationale: Prevents accidental access to other users' income records even if IDs are guessed.

## 9. Risks / Tradeoffs
- `suggested_tax_rate` is stored as a decimal without strict range enforcement yet; follow-up can add constraints once UX/meaning (0–1 vs 0–100) is finalized.

## 10. Follow-ups
Use checkboxes.

- [ ] Integrate `OtherIncome` into Epic 2 snapshot aggregation (deferred)
- [ ] Consider adding `suggested_tax_rate` range validation once semantics are finalized

## 11. Outcome
- Users can create, view, edit, and delete their own `OtherIncome` records; access to other users' records is blocked.

## 12. Commit(s)
List final commits that included this work. If not committed yet, say “Pending”.

- `feat: add other income model and user-scoped CRUD` — `8eb5f05`

---
