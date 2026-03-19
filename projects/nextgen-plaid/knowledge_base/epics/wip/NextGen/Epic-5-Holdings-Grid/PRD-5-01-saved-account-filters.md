# PRD 5-01: Saved Account Filters – Model, CRUD & UI Selector

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Implement model, CRUD interfaces, and reusable selector component for saved account filter sets. These are reusable across holdings, net worth, transactions, and future reports.

## Requirements

### Functional
- **Model**: user_id, name (unique per user), criteria (jsonb: account_ids array, institution_ids, ownership_types ["Individual","Trust","Other"], asset_strategy, trust_code, holder_category, context), created_at, updated_at
- **Criteria Schema** (document in knowledge_base/data-dictionary.md):
  ```json
  {
    "account_ids": [1, 2, 3],
    "institution_ids": [10],
    "ownership_types": ["Individual", "Trust", "Other"],
    "asset_strategy": "long_term",
    "trust_code": "TR001",
    "holder_category": "primary",
    "context": "holdings" // optional: "holdings", "transactions", "net_worth"
  }
  ```
- **CRUD**:
  - index (list user's filters)
  - new/edit (form for name + multi-select accounts or criteria builder)
  - create/update/delete
- **Selector**: ViewComponent dropdown/pills showing user's filters + "All Accounts" default
- When selected, passes criteria to data provider
- Validate presence of at least one criteria key on create/update

### Non-Functional
- Validates name uniqueness per user
- JSON schema validation on criteria (optional but recommended)
- Scoped to current_user only (RLS + app scoping)
- Reusable component for other views
- Extensible `context` field for future filtering by use case

## Architectural Context
Rails model `SavedAccountFilter` belongs_to :user. Controller in app/controllers/saved_account_filters_controller.rb. ViewComponent for selector. Criteria serialized as JSON for flexibility.

## Database Schema

```ruby
create_table "saved_account_filters", force: :cascade do |t|
  t.bigint "user_id", null: false
  t.string "name", null: false
  t.jsonb "criteria", null: false, default: {}
  t.string "context" # optional: "holdings", "transactions", "net_worth"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["user_id", "name"], unique: true
  t.index ["user_id", "created_at"]
end

# RLS Policy
execute <<-SQL
  ALTER TABLE saved_account_filters ENABLE ROW LEVEL SECURITY;
  CREATE POLICY user_filters ON saved_account_filters
    USING (user_id = current_setting('app.current_user_id', true)::bigint);
SQL
```

## Acceptance Criteria
- User can create filter named "Trust Assets" selecting trust-owned accounts
- Selector appears in holdings grid and applies filter correctly
- Default "All Accounts" selected on first visit
- Delete works; list shows only own filters
- Criteria persists and deserializes correctly
- RLS prevents cross-user access
- Context field is optional and filterable

## Test Cases
- **Model**: valid/invalid criteria, uniqueness, RLS policy enforcement
- **Controller**: CRUD actions, authorization (only own filters)
- **ViewComponent**: renders dropdown with options, highlights selected
- **Integration**: select filter → holdings grid shows only matching accounts
- **Edge**: empty criteria = all accounts, invalid JSON, cross-user access attempt

## Manual Testing Steps
1. Create filter "Trust Accounts" with `{"ownership_types": ["Trust"]}`
2. Verify filter appears in dropdown
3. Select filter → verify only trust accounts shown in holdings
4. Edit filter name → verify update persists
5. Create duplicate name → verify validation error
6. Delete filter → verify removed from dropdown
7. Login as different user → verify filter not visible
8. Apply filter in net worth view → verify same criteria works

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-01-saved-account-filters`. Ask questions/plan in log. Commit green code only.

## Dependencies
- None (standalone foundation PRD)

## Blocked By
- None

## Blocks
- PRD 5-02 (Data Provider needs SavedAccountFilter model)
- PRD 5-04 (Filter integration needs selector UI)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [Data Dictionary](../../../../data-dictionary.md) - criteria schema
