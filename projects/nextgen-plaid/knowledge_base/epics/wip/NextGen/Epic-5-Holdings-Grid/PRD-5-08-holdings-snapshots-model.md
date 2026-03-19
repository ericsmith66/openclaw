# PRD 5-08: Holdings Snapshots – Model & JSON Storage

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Define the HoldingsSnapshot model to store point-in-time JSON representations of holdings data per user or per account, enabling historical views and comparisons.

## Requirements

### Functional
- **Fields**:
  - user_id (bigint, foreign key, not null, indexed)
  - account_id (bigint, foreign key, nullable) — null = user-level snapshot (all accounts)
  - snapshot_data (jsonb, not null) — structured holdings JSON
  - name (string, optional) — user-provided or auto-generated name
  - created_at (datetime, not null, indexed)
- **JSON Structure**:
  ```json
  {
    "holdings": [
      {
        "security_id": "abc123",
        "ticker_symbol": "AAPL",
        "name": "Apple Inc.",
        "quantity": 100,
        "market_value": 15000.00,
        "cost_basis": 12000.00,
        "unrealized_gain_loss": 3000.00,
        "asset_class": "equity",
        "account_id": 123,
        "account_name": "Brokerage",
        "account_mask": "1234"
      }
    ],
    "totals": {
      "portfolio_value": 250000.00,
      "total_gl_dollars": 45000.00,
      "total_gl_pct": 21.95
    }
  }
  ```
- **Scopes**:
  - by_user(user_id)
  - by_account(account_id)
  - by_date_range(start_date, end_date)
  - recent_first (order: created_at desc)
  - user_level (where account_id is null)
  - account_level (where account_id is not null)
- **Naming Convention**:
  - Auto-generated (scheduled job): "Daily #{created_at.to_date}" (e.g., "Daily 2026-02-04")
  - Manual snapshots: "Manual Snapshot #{created_at.strftime('%Y-%m-%d %H:%M')}"
  - User can override with custom name

### Non-Functional
- **Indexes**:
  - (user_id, created_at DESC)
  - (account_id, created_at DESC)
  - (user_id, account_id, created_at DESC)
- **RLS Policy**: `USING (user_id = current_setting('app.current_user_id', true)::bigint)`
- **Validations**:
  - snapshot_data must be valid JSON
  - snapshot_data must contain "holdings" array
  - Size limit: < 1MB per record (check constraint)
- **Monitoring**: track snapshot table size, alert if > 10GB

## Database Schema

```ruby
create_table "holdings_snapshots", force: :cascade do |t|
  t.bigint "user_id", null: false
  t.bigint "account_id"
  t.jsonb "snapshot_data", null: false
  t.string "name"
  t.datetime "created_at", null: false

  t.index ["user_id", "created_at"], order: { created_at: :desc }
  t.index ["account_id", "created_at"], order: { created_at: :desc }
  t.index ["user_id", "account_id", "created_at"], order: { created_at: :desc }

  t.check_constraint "octet_length(snapshot_data::text) < 1048576", name: "snapshot_size_limit"
end

# Foreign keys
add_foreign_key "holdings_snapshots", "users"
add_foreign_key "holdings_snapshots", "accounts"

# RLS Policy
execute <<-SQL
  ALTER TABLE holdings_snapshots ENABLE ROW LEVEL SECURITY;

  CREATE POLICY user_snapshots ON holdings_snapshots
    USING (user_id = current_setting('app.current_user_id', true)::bigint);
SQL
```

## Model Implementation

```ruby
# app/models/holdings_snapshot.rb
class HoldingsSnapshot < ApplicationRecord
  belongs_to :user
  belongs_to :account, optional: true

  validates :snapshot_data, presence: true
  validate :validate_snapshot_structure
  validate :validate_snapshot_size

  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :user_level, -> { where(account_id: nil) }
  scope :account_level, -> { where.not(account_id: nil) }

  before_validation :generate_name, if: -> { name.blank? }

  private

  def validate_snapshot_structure
    return unless snapshot_data

    unless snapshot_data.is_a?(Hash) && snapshot_data['holdings'].is_a?(Array)
      errors.add(:snapshot_data, 'must contain holdings array')
    end
  end

  def validate_snapshot_size
    return unless snapshot_data

    if snapshot_data.to_json.bytesize > 1.megabyte
      errors.add(:snapshot_data, 'size exceeds 1MB limit')
    end
  end

  def generate_name
    self.name = if account_id.present?
      "Account Snapshot #{created_at.strftime('%Y-%m-%d %H:%M')}"
    else
      "Daily #{created_at.to_date}"
    end
  end
end
```

## Acceptance Criteria
- Snapshot creatable with valid JSON via console or service
- Queryable by user_id, account_id, date range
- Scopes return correct filtered records
- RLS prevents cross-user access (integration test)
- JSON round-trips without data loss
- Size validation prevents oversized records
- Name auto-generates if not provided
- Invalid JSON structure rejected by validation
- User-level vs account-level snapshots distinguished correctly

## Test Cases
- **Model**:
  - Valid/invalid JSON structure
  - Size validation (>1MB rejected)
  - Scopes return correct records
  - Name generation (user-level, account-level, manual)
  - Belongs_to associations work
- **RSpec**:
  - RLS test: User A cannot access User B's snapshots
  - JSONB queries work (e.g., snapshot_data -> 'holdings')
  - Foreign key constraints enforced
- **FactoryBot**:
  - Create valid snapshot fixture
  - Assert structure matches schema
- **Edge**:
  - Empty holdings array (valid)
  - No account_id (user-level snapshot, valid)
  - Missing totals in JSON (should fail validation if we add that)
  - Very large holdings array (near 1MB limit)

## Manual Testing Steps
1. Rails console: create snapshot with valid JSON
   ```ruby
   snapshot = HoldingsSnapshot.create!(
     user_id: 1,
     snapshot_data: {
       holdings: [{ security_id: 'abc', ticker_symbol: 'AAPL', quantity: 100, ... }],
       totals: { portfolio_value: 15000 }
     }
   )
   ```
2. Verify snapshot saved with auto-generated name
3. Query: HoldingsSnapshot.by_user(1).recent_first → verify returns snapshot
4. Try creating snapshot with invalid JSON (missing holdings) → verify validation error
5. Try creating >1MB snapshot → verify size validation error
6. Create snapshot with custom name → verify name persists
7. Create account-level snapshot (with account_id) → verify scoping works
8. Test RLS: set different current_user_id → verify cannot access other user's snapshots
9. Query snapshot_data: snapshot.snapshot_data['holdings'] → verify structure accessible

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-08-holdings-snapshots-model`. Ask questions/plan in log. Commit green code only.

## Dependencies
- None (foundational model for snapshots)

## Blocked By
- None

## Blocks
- PRD 5-09 (Snapshot creation service uses this model)
- PRD 5-10 (Snapshot comparison queries this model)
- PRD 5-11 (Snapshot selector lists records from this model)
- PRD 5-13 (Snapshot management CRUD uses this model)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [Data Dictionary](../../../../data-dictionary.md) — snapshot_data schema
- [Feedback V2 - Snapshot Storage](./Epic-5-Holding-Grid-feedback-V2.md#prd-8-snapshots-model)
