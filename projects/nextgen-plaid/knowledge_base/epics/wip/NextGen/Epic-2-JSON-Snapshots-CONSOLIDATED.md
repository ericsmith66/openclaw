**Epic 2: Financial Snapshots Foundation & Net Worth Scaffold**

**Epic Overview**
Implement the data foundation (FinancialSnapshot model, daily job, structured JSON blobs with aggregates/breakdowns) and initial UI scaffold (navigation wireframe, authenticated layout, sidebar with full tree, placeholder center panel) to enable safe, incremental building of Net Worth dashboards. All existing UI (dashboard, holdings, transactions, accounts, other_incomes, etc.) is POC/prototype — it is OK and expected to break, refactor, rename, or replace conventions as needed. By the end of Epic 2 and the follow-on Epic 3, the entire UI will be refactored to the new structure. Prioritize clean, consistent design per style guide over legacy compatibility.

**Important Dependency Note:** Epic 2 PRDs 2-03 through 2-05 (Asset Allocation, Sector Weights, Holdings Summary) assume SecurityEnrichment columns from Epic 1 PRD-0170 v2 are live. If Epic 1 is incomplete, use fallback to `holding.sector` or security `data` JSON until SecurityEnrichment columns are available.

**User Capabilities**
Users get a navigable skeleton (sidebar + top bar) with placeholders; owners/admins see full admin/Mission Control/Agent Hub links. Snapshots provide portable JSON context for future UI (Epic 3) and AI tutor RAG.

**Fit into Big Picture**
Establishes queryable financial context (snapshots) and modern UI foundation without real-time overload. Enables curriculum grounding and scalable dashboard polish in Epic 3.

**PRD Summary Table** (Epic 2 – 10 PRDs max)

| Priority | PRD Title                                      | Scope                                      | Dependencies          | Suggested Branch                     | Notes |
|----------|------------------------------------------------|--------------------------------------------|-----------------------|--------------------------------------|-------|
| 0        | Navigation Wireframe Setup – Initial Scaffold  | Top bar + sidebar + placeholder center     | None                  | feature/prd-2-00-nw-wireframe        | Zero-dependency; start here |
| 1        | FinancialSnapshot Model & Migration            | Model + migration + scopes                 | Existing models       | feature/prd-2-01-snapshot-model      | Core storage |
| 2        | Daily FinancialSnapshotJob – Core Aggregates   | Job + basic sums + OtherIncome             | PRD-2-01              | feature/prd-2-02-snapshot-core       | Scheduling + sums |
| 3        | Snapshot – Asset Allocation Breakdown          | Nested percent + value                     | PRD-2-02              | feature/prd-2-03-snapshot-allocation | Feeds allocation view |
| 4        | Snapshot – Sector Weights                      | Equity sectors percent + value             | PRD-2-03              | feature/prd-2-04-snapshot-sectors    | Feeds sector view |
| 5        | Snapshot – Holdings & Transactions Summary     | Top holdings + monthly tx summary          | PRD-2-04              | feature/prd-2-05-snapshot-summaries  | Feeds summaries |
| 6        | Snapshot – Historical Deltas (NO ARRAY)        | Day/30d deltas (computed from prior)       | PRD-2-05              | feature/prd-2-06-snapshot-trends     | Delta calcs |
| 7        | Snapshot Validation & Admin Preview            | /admin/snapshots list + show               | PRD-2-06              | feature/prd-2-07-snapshot-validation | Debug tool |
| 8        | Snapshot Export API                            | /snapshots/:id/export (JSON/CSV/RAG)       | PRD-2-07              | feature/prd-2-08-snapshot-export     | Export + RAG context |
| 9        | Dashboard Layout & Navigation Integration      | Grid + quick links + breadcrumbs           | PRD-2-00 + PRD-2-02   | feature/prd-2-09-dashboard-layout    | Ties scaffold to data |

**Epic 3** (follow-on): Net Worth Dashboard Polish & Components (PRDs 10–18) – deferred until Epic 2 complete.

---

## Target Snapshot JSON Structure (Schema Version 1)

All snapshot PRDs (2-02 through 2-06) build toward this comprehensive JSON structure stored in `financial_snapshots.data` (JSONB):

```json
{
  "schema_version": 1,
  "snapshot_date": "2026-01-21",
  "aggregates": {
    "total_net_worth": 125000.00,
    "total_assets": 135000.00,
    "total_liabilities": 10000.00,
    "liquid_assets": 25000.00,
    "invested_assets": 100000.00,
    "other_income_annual": 5000.00
  },
  "allocation": {
    "stocks": { "value": 70000.00, "percent": 70.0 },
    "bonds": { "value": 20000.00, "percent": 20.0 },
    "cash": { "value": 10000.00, "percent": 10.0 }
  },
  "sectors": {
    "technology": { "value": 35000.00, "percent": 50.0 },
    "healthcare": { "value": 21000.00, "percent": 30.0 },
    "financials": { "value": 14000.00, "percent": 20.0 }
  },
  "top_holdings": [
    { "symbol": "AAPL", "name": "Apple Inc.", "value": 15000.00, "percent": 15.0 },
    { "symbol": "MSFT", "name": "Microsoft", "value": 12000.00, "percent": 12.0 }
  ],
  "transaction_summary": {
    "last_30_days": {
      "count": 45,
      "total_spent": 3200.00,
      "categories": { "groceries": 800, "dining": 450 }
    }
  },
  "trends": {
    "day_over_day": { "value_change": 150.00, "percent_change": 0.12 },
    "month_over_month": { "value_change": 2500.00, "percent_change": 2.04 }
  },
  "metadata": {
    "generated_at": "2026-01-21T02:00:00Z",
    "data_quality_score": 0.95,
    "warnings": ["3 holdings missing current price"]
  }
}
```

**Schema Versioning:** The `schema_version` field enables future evolution. When structure changes (Epic 3+), increment version and write migration logic to handle older snapshots.

### Detailed PRD: PRD-2-00 – Navigation Wireframe Setup – Initial Scaffold

**PRD ID:** PRD-2-00  
**Priority:** 0 (immediate foundation)  
**Scope:** Atomic – Static, navigable wireframe: top bar, sidebar with full tree, placeholder center panel. No data, no real components — structure + links only.  
**Estimated Effort:** 1–2 developer days  
**Developer:** Junie Pro (default: Claude Sonnet 4.5 in RubyMine)

**Overview**  
Scaffold the authenticated layout: fixed top bar (logo + notifications + avatar), persistent sidebar with complete navigation tree (user + owner/admin), and center panel placeholder. This gives a clickable skeleton of the future UI without depending on snapshots or enrichment. Existing POC UI (dashboard, holdings, etc.) is disposable — break/refactor freely.

**Log Requirements**  
Junie: Before starting any work, read and strictly follow:
- `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`
- `<project root>/knowledge_base/style_guide.md`
- Any relevant templates in `<project root>/knowledge_base/templates/`

**Junie Important Guidance:**  
All UI and navigation code to this point (including dashboard, holdings, transactions, accounts, other_incomes, etc.) is **pure POC/prototype** — it is OK (and expected) to **break, refactor, rename, or completely replace** existing conventions, layouts, partials, controllers, or views as needed to achieve a clean, consistent, professional structure. By the end of Epic 2 and Epic 3, the entire UI of the project will be refactored to the new authenticated layout + sidebar pattern. Do **not** attempt to maintain backward compatibility with existing POC pages or styles — prioritize the new wireframe and style guide over legacy code.

Log all decisions, questions, deviations, and test outcomes in the junie-log file.

**Requirements**

**Functional**
- **Feature Flag for Gradual Rollout**
    - Add `ENABLE_NEW_LAYOUT` environment variable (default: `true` in development/staging, `false` in production)
    - In `ApplicationController`:
      ```ruby
      layout :set_layout
      private
      def set_layout
        if user_signed_in? && (Rails.env.development? || ENV['ENABLE_NEW_LAYOUT'] == 'true')
          "authenticated"
        else
          "application"
        end
      end
      ```
    - Allows gradual rollout: owner → beta users → all users
    - Rollback plan: flip flag to disable if issues arise

- **Authenticated Layout** (`app/views/layouts/authenticated.html.erb`)
    - Extend `application.html.erb` (keep minimal — no modifications needed to application.html.erb)
    - Fixed top bar (full-width)
    - Fixed left sidebar (288px / `w-72` desktop, collapsible drawer on mobile via DaisyUI)
    - Center panel: full remaining width/height with placeholder text (centered, large font, gray):
      ```erb
      <div class="flex items-center justify-center h-full">
        <div class="text-center">
          <h2 class="text-2xl font-semibold text-base-content/60 mb-2">
            Center Panel Placeholder
          </h2>
          <p class="text-base-content/40">Content Coming Soon</p>
        </div>
      </div>
      ```

- **Top Bar Component** (`app/components/navigation/top_bar_component.rb`)
    - Left: Logo linking to `/net_worth/dashboard`
    - Right: Notifications bell (Heroicons v2 `bell` outline), avatar dropdown (Profile → `/users/edit`, Sign Out)
    - Use `gem 'heroicon'` for icons (or inline SVGs from heroicons.com)

- **Sidebar Component** (`app/components/navigation/sidebar_component.rb`)
    - Render exact navigation tree (below)
    - DaisyUI `menu menu-lg bg-base-200 rounded-box w-72` (288px width)
    - Active highlighting (current_page? or `active` class)
    - Owner/admin sections conditional on `current_user.owner?`
    - Mobile: Hamburger toggles drawer (auto-close on navigation)

- **Routing Updates** (`config/routes.rb`)
    - Add redirect for legacy route: `get '/dashboard', to: redirect('/net_worth/dashboard')`
    - Create placeholder controllers for:
      - `TransactionsController#regular` → `/transactions/regular`
      - `TransactionsController#investment` → `/transactions/investment`
    - Render simple "Coming Soon" view for unbuilt routes
- **Navigation Tree (Exact Links)**
  ```
  • Net Worth
    - Dashboard → /net_worth/dashboard
    - Asset Allocation → /net_worth/allocations
    - Sector Weights → /net_worth/sectors
    - Performance → /net_worth/performance
    - Holdings → /net_worth/holdings
    - Transactions → /net_worth/transactions
    - Income & Cash Flow → /net_worth/income
  • Accounts & Linking
    - Accounts List → /accounts
    - Link New Account → /accounts/link
  • Transactions
    - Regular → /transactions/regular
    - Investment → /transactions/investment
  • Other Incomes → /other_incomes
  • Simulations & AI Tutor → /simulations (placeholder)
  • Settings & Profile
    - Profile → /users/edit
    - Brokerage Connect → /settings/brokerage_connect
  ────────────────────────── (owner/admin only)
  • Admin
    - Users → /admin/users
    - Accounts → /admin/accounts
    - Ownership Lookups → /admin/ownership_lookups
    - AI Workflow → /admin/ai_workflow
    - Health → /admin/health
    - RAG Inspector → /admin/rag_inspector
    - SAP Collaborate → /admin/sap_collaborate
    - Agents Monitor → /admin/agents/monitor
    - Mission Control → /admin/mission_control
  • Agent Hub → /agent_hub
  ```

**Non-Functional**
- Tailwind + DaisyUI only — match style guide theme
- Mobile-first: drawer on < lg
- Accessibility: ARIA labels, keyboard nav
- Minimal JS: DaisyUI drawer toggle only
- Performance: Static links, no queries

**Architectural Context**
- New layout + two ViewComponents (TopBarComponent, SidebarComponent)
- Layout selection in ApplicationController via feature flag (see Requirements)
- No data fetching — placeholders only
- POC pages: Safe to break/replace
- Icon library: Heroicons v2 (add `gem 'heroicon'` if not present)
- Sidebar width: `w-72` (288px) — standard Tailwind value
- ViewComponent testing: Include `ViewComponent::TestHelpers` in RSpec
  ```ruby
  # spec/rails_helper.rb
  require "view_component/test_helpers"

  RSpec.configure do |config|
    config.include ViewComponent::TestHelpers, type: :component
  end
  ```

**Acceptance Criteria**
- Feature flag `ENABLE_NEW_LAYOUT` controls layout visibility (default: true in dev/staging, false in production)
- Logged-in user sees top bar + sidebar with full tree (when flag enabled)
- All navigation links work (placeholder controllers render "Coming Soon" for unbuilt routes)
- Legacy `/dashboard` redirects to `/net_worth/dashboard`
- Owner sees Admin section + Mission Control/Agent Hub
- Regular user does NOT see Admin section
- Non-owner attempting `/admin/mission_control` gets 403/redirect with friendly error message
- Mobile drawer toggle works (hamburger icon visible, drawer opens/closes)
- Mobile drawer auto-closes on navigation
- Center panel shows styled placeholder text (centered, large, gray)
- No regressions on public/sign-in pages
- Heroicons render correctly (bell icon, avatar icon)

**Test Cases**
**Unit (RSpec)**
- `TopBarComponent` renders logo, notifications (Heroicon bell), avatar dropdown
- `SidebarComponent` regular user: no Admin section rendered
- `SidebarComponent` owner: includes Admin/Mission Control/Agent Hub
- Example test structure:
  ```ruby
  RSpec.describe Navigation::SidebarComponent, type: :component do
    let(:user) { create(:user) }

    context "regular user" do
      it "does not render admin section" do
        render_inline(described_class.new(user: user))
        expect(page).not_to have_link("Mission Control")
      end
    end

    context "owner user" do
      let(:user) { create(:user, :owner) }

      it "renders admin section" do
        render_inline(described_class.new(user: user))
        expect(page).to have_link("Mission Control")
      end
    end
  end
  ```

**System (Capybara)**
- Visit `/net_worth/dashboard` → assert top bar + sidebar visible
- Visit `/dashboard` → assert redirects to `/net_worth/dashboard`
- Click "Transactions → Regular" → assert path `/transactions/regular`, "Coming Soon" visible
- Click "Transactions → Investment" → assert path `/transactions/investment`, "Coming Soon" visible
- Mobile viewport → assert hamburger visible, toggles drawer
- Mobile → click link → drawer auto-closes
- Owner login → assert "Mission Control" link visible
- Regular user login → assert no "Admin" section
- Non-owner visit `/admin/mission_control` → 403/redirect with error message

**Manual Testing Checklist**
- [ ] Desktop (1920x1080): Sidebar visible (288px), top bar spans full width
- [ ] Tablet (768px): Sidebar visible or drawer depending on breakpoint
- [ ] Mobile (375px): Hamburger icon visible, drawer toggles on click
- [ ] Click each navigation link: URL changes, placeholder/coming soon acceptable
- [ ] Sign in as owner: Admin section visible with all links
- [ ] Sign in as regular user: Admin section hidden
- [ ] Avatar dropdown: Profile and Sign Out links functional
- [ ] Keyboard navigation: Tab through menu items, Enter activates links
- [ ] Heroicons render correctly (no broken images/icons)
- [ ] Feature flag test: Set `ENABLE_NEW_LAYOUT=false` → layout reverts to application.html.erb

**Text-Based Wireframe (Desktop lg+)**
```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [Logo] NextGen Plaid                               🔔 Notifications   Avatar ▼  │
└──────────────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────┬────────────────────────────────────────────────┐
│ Sidebar (fixed left, 288px) │ Center Panel (flex-1)                          │
│ w-72                        │                                                │
│                             │                                                │
│ • Net Worth                 │          Center Panel Placeholder              │
│   - Dashboard               │            Content Coming Soon                 │
│   - Asset Allocation        │                                                │
│   - Sector Weights          │      (centered, large font, gray text)         │
│   - Performance             │                                                │
│   - Holdings                │                                                │
│   - Transactions            │                                                │
│   - Income & Cash Flow      │                                                │
│ • Accounts & Linking        │                                                │
│ • Transactions              │                                                │
│   - Regular                 │                                                │
│   - Investment              │                                                │
│ • Other Incomes             │                                                │
│ • Simulations & AI Tutor    │                                                │
│ • Settings & Profile        │                                                │
│ ─────────────────────────── │                                                │
│ • Admin (owner only)        │                                                │
│   - Users                   │                                                │
│   - Accounts                │                                                │
│   - Ownership Lookups       │                                                │
│   - AI Workflow             │                                                │
│   - Health                  │                                                │
│   - RAG Inspector           │                                                │
│   - SAP Collaborate         │                                                │
│   - Agents Monitor          │                                                │
│   - Mission Control         │                                                │
│ • Agent Hub (owner only)    │                                                │
└─────────────────────────────┴────────────────────────────────────────────────┘
```

**Mobile (<lg)**
- Hamburger opens drawer overlay with same menu

**Workflow**
1. `git pull origin main`
2. `git checkout -b feature/prd-2-00-nw-wireframe`
3. Implement per style guide
4. `rspec` + manual tests
5. Commit green: `git commit -m "Set up navigable wireframe layout + sidebar + placeholder [PRD-2-00]"`
6. Push & PR

**Answers to Common Questions**
- **Q: Tailwind/DaisyUI theme?** A: Match style guide exactly — refer to `knowledge_base/style_guide.md`
- **Q: Extend existing layout?** A: Create new `authenticated.html.erb`, extend existing `application.html.erb` (no modifications to application.html.erb needed)
- **Q: Stimulus controller for drawer?** A: DaisyUI drawer uses native HTML/CSS, minimal or no Stimulus needed (checkbox toggle pattern)
- **Q: Placeholder text styling?** A: Centered, large font (`text-2xl`), gray (`text-base-content/60`) — see code in Requirements section
- **Q: Icon set?** A: Heroicons v2 — add `gem 'heroicon'` or use inline SVGs from heroicons.com
- **Q: Sidebar width?** A: Use `w-72` (288px) — standard Tailwind value
- **Q: What about /transactions/regular and /investment routes?** A: Create placeholder controllers now (minimal effort) rendering "Coming Soon" view
- **Q: Legacy /dashboard route?** A: Add redirect: `get '/dashboard', to: redirect('/net_worth/dashboard')`

**Additional Resources for Junie**
- ViewComponent docs: https://viewcomponent.org/guide/
- Heroicons: https://heroicons.com
- DaisyUI drawer: https://daisyui.com/components/drawer/
- First ViewComponent (TopBar) should be extensively commented as reference for subsequent components

Ready for Junie — this PRD is self-contained, addresses all feedback, and emphasizes POC refactoring freedom.

---

### Detailed PRD: PRD-2-01 – FinancialSnapshot Model & Migration

**PRD ID:** PRD-2-01
**Priority:** 1 (can run parallel with PRD-2-00)
**Scope:** Atomic – Model + migration + indexes + validation + scopes
**Estimated Effort:** 1 developer day
**Developer:** Junie Pro (default: Claude Sonnet 4.5 in RubyMine)

**Overview**
Create the `FinancialSnapshot` model to store daily financial snapshots as JSONB. Include schema versioning, unique constraints, status tracking, and performance indexes. This is the core storage layer for all snapshot data.

**Log Requirements**
Junie: Before starting any work, read and strictly follow:
- `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`
- `<project root>/knowledge_base/style_guide.md`

**Requirements**

**Functional**
- **Model:** `app/models/financial_snapshot.rb`
  - Belongs to `user`
  - Fields:
    - `user_id` (integer, not null, indexed)
    - `snapshot_date` (date, not null)
    - `schema_version` (integer, not null, default: 1)
    - `status` (enum: pending, complete, error, stale)
    - `data` (jsonb, not null)
    - `timestamps` (created_at, updated_at)

- **Validations:**
  ```ruby
  validates :user_id, presence: true
  validates :snapshot_date, presence: true, uniqueness: { scope: :user_id }
  validates :schema_version, presence: true, inclusion: { in: 1..2 } # allow future v2
  validates :status, presence: true
  validates :data, presence: true
  ```

- **Enums:**
  ```ruby
  enum status: { pending: 0, complete: 1, error: 2, stale: 3 }
  ```

- **Scopes:**
  ```ruby
  scope :recent, -> { order(snapshot_date: :desc) }
  scope :for_date_range, ->(start_date, end_date) { where(snapshot_date: start_date..end_date) }
  scope :complete, -> { where(status: :complete) }
  scope :with_errors, -> { where(status: :error) }
  ```

- **Data Quality Methods:**
  ```ruby
  # Returns 0.0 to 1.0 based on data completeness
  def data_quality_score
    score = 0.0
    score += 0.4 if holdings_have_prices?
    score += 0.3 if securities_enriched?
    score += 0.2 if transactions_present?
    score += 0.1 if other_income_present?
    score
  end

  # Returns array of warning strings for admin preview
  def warnings
    data.dig('metadata', 'warnings') || []
  end

  private

  def holdings_have_prices?
    # Logic based on data JSON
  end

  def securities_enriched?
    # Logic based on data JSON
  end

  def transactions_present?
    # Logic based on data JSON
  end

  def other_income_present?
    # Logic based on data JSON
  end
  ```

**Non-Functional**
- **Performance:** JSONB indexes for common queries
- **Data Integrity:** Unique constraint on [user_id, snapshot_date]
- **Schema Evolution:** schema_version enables future migrations

**Migration**
```ruby
class CreateFinancialSnapshots < ActiveRecord::Migration[7.0]
  def change
    create_table :financial_snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.date :snapshot_date, null: false
      t.integer :schema_version, null: false, default: 1
      t.integer :status, null: false, default: 0
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end

    add_index :financial_snapshots, [:user_id, :snapshot_date], unique: true, name: 'index_snapshots_on_user_and_date'
    add_index :financial_snapshots, :snapshot_date
    add_index :financial_snapshots, :status

    # JSONB performance indexes
    add_index :financial_snapshots, "(data -> 'aggregates' ->> 'total_net_worth')", name: 'index_snapshots_on_net_worth', using: :btree
    add_index :financial_snapshots, "(data -> 'metadata' ->> 'data_quality_score')", name: 'index_snapshots_on_quality', using: :btree
  end
end
```

**Architectural Context**
- Foundation for all snapshot PRDs (2-02 through 2-09)
- JSONB allows flexible schema evolution
- Status field enables monitoring and retry logic
- Unique index prevents duplicate snapshots for same user/date
- Target JSON structure defined in Epic 2 overview (see "Target Snapshot JSON Structure" section)

**Acceptance Criteria**
- Migration runs successfully
- Model validations prevent duplicate snapshots
- Status enum works correctly
- Scopes filter correctly
- Data quality methods return expected values
- JSONB indexes created successfully
- Can create snapshot: `FinancialSnapshot.create!(user: user, snapshot_date: Date.today, status: :complete, data: { schema_version: 1 })`

**Test Cases**

**Unit (RSpec)**
```ruby
RSpec.describe FinancialSnapshot, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:snapshot_date) }
    it { should validate_uniqueness_of(:snapshot_date).scoped_to(:user_id) }
  end

  describe 'status enum' do
    it { should define_enum_for(:status).with_values(pending: 0, complete: 1, error: 2, stale: 3) }
  end

  describe '#data_quality_score' do
    let(:snapshot) { create(:financial_snapshot, :with_complete_data) }

    it 'returns 1.0 for complete data' do
      expect(snapshot.data_quality_score).to eq(1.0)
    end
  end

  describe 'scopes' do
    it 'returns recent snapshots in desc order' do
      old = create(:financial_snapshot, snapshot_date: 2.days.ago)
      new = create(:financial_snapshot, snapshot_date: 1.day.ago)
      expect(FinancialSnapshot.recent).to eq([new, old])
    end
  end
end
```

**System (Capybara)**
- N/A (model only, no UI yet)

**Workflow**
1. `git pull origin main`
2. `git checkout -b feature/prd-2-01-snapshot-model`
3. Generate model: `rails g model FinancialSnapshot user:references snapshot_date:date schema_version:integer status:integer data:jsonb`
4. Edit migration to add indexes and constraints
5. `rails db:migrate`
6. Implement model validations, enums, scopes, methods
7. Write RSpec tests
8. `rspec spec/models/financial_snapshot_spec.rb`
9. Commit green: `git commit -m "Add FinancialSnapshot model with schema versioning and JSONB storage [PRD-2-01]"`
10. Push & PR

**Notes**
- Schema version 1 is defined in Epic 2 overview
- Future PRDs (2-02 through 2-06) will populate the `data` field
- Data quality methods will be refined as snapshot job is built

---

### Detailed PRD: PRD-2-02 – Daily FinancialSnapshotJob – Core Aggregates

**PRD ID:** PRD-2-02
**Priority:** 2
**Scope:** Small – Background job + scheduling + aggregates + error handling
**Estimated Effort:** 2 developer days
**Dependencies:** PRD-2-01
**Developer:** Junie Pro (default: Claude Sonnet 4.5 in RubyMine)

**Overview**
Create a Sidekiq job to generate daily financial snapshots for all active users. Calculate core aggregates (net worth, assets, liabilities, liquid/invested assets, other income). Run daily at 2 AM UTC. Include retry logic, error handling, and monitoring.

**Log Requirements**
Junie: Before starting any work, read and strictly follow:
- `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md`
- `<project root>/knowledge_base/style_guide.md`

**Requirements**

**Functional**
- **Job:** `app/jobs/financial_snapshot_job.rb`
  - Run for all active users (account status != 'suspended')
  - Idempotent: Check if snapshot exists for date; if yes, skip or update based on timestamp
  - Calculate aggregates:
    - `total_net_worth` = assets - liabilities
    - `total_assets` = sum of all account balances + holdings values
    - `total_liabilities` = sum of credit/loan balances (negative)
    - `liquid_assets` = checking + savings + money market
    - `invested_assets` = brokerage + retirement holdings
    - `other_income_annual` = sum of active OtherIncome records × 12 (if monthly)

- **Error Handling:**
  ```ruby
  class FinancialSnapshotJob < ApplicationJob
    queue_as :default
    retry_on StandardError, wait: :exponentially_longer, attempts: 3

    rescue_from StandardError do |e|
      snapshot.update(status: :error, data: { error: e.message, backtrace: e.backtrace.first(5) })
      Rails.logger.error("[FinancialSnapshotJob] Failed for user #{user_id}: #{e.message}")
      # Optional: Notify owner if 3 consecutive failures
    end

    def perform(user_id, snapshot_date = Date.today)
      user = User.find(user_id)
      snapshot = FinancialSnapshot.find_or_initialize_by(user: user, snapshot_date: snapshot_date)

      return if snapshot.persisted? && snapshot.updated_at > 1.hour.ago # Skip recent snapshots

      snapshot.status = :pending
      snapshot.save!

      data = calculate_snapshot_data(user, snapshot_date)
      snapshot.update!(status: :complete, data: data)
    end

    private

    def calculate_snapshot_data(user, snapshot_date)
      {
        schema_version: 1,
        snapshot_date: snapshot_date.to_s,
        aggregates: calculate_aggregates(user),
        metadata: {
          generated_at: Time.current.iso8601,
          data_quality_score: 0.0, # Will be calculated after all PRDs complete
          warnings: []
        }
      }
    end

    def calculate_aggregates(user)
      # Implementation based on existing models
      {
        total_net_worth: calculate_net_worth(user),
        total_assets: calculate_total_assets(user),
        total_liabilities: calculate_liabilities(user),
        liquid_assets: calculate_liquid_assets(user),
        invested_assets: calculate_invested_assets(user),
        other_income_annual: calculate_other_income(user)
      }
    end
  end
  ```

- **Scheduling:**
  - Use `sidekiq-scheduler` (or similar)
  - Schedule: Daily at 2 AM UTC (`cron: '0 2 * * *'`)
  - Config in `config/sidekiq.yml`:
    ```yaml
    :schedule:
      daily_financial_snapshots:
        cron: '0 2 * * *'
        class: DailySnapshotSchedulerJob
        queue: default
    ```

- **Batch Processing:**
  ```ruby
  class DailySnapshotSchedulerJob < ApplicationJob
    def perform
      User.active.find_in_batches(batch_size: 100) do |users|
        users.each do |user|
          FinancialSnapshotJob.perform_later(user.id)
        end
      end
    end
  end
  ```

**Non-Functional**
- **Performance:** Batch processing (100 users per batch), parallel Sidekiq workers
- **Monitoring:** Log job duration, track p50/p95/p99 metrics
- **Reliability:** 3 retry attempts with exponential backoff
- **Idempotency:** Skip if snapshot exists and was updated in last hour

**Architectural Context**
- Runs after Plaid sync jobs complete (assume sync runs at 1 AM UTC)
- Uses existing models: User, Account, Holding, Transaction, OtherIncome
- PRDs 2-03 through 2-06 will extend this job to add allocation, sectors, holdings, trends
- Fallback logic if SecurityEnrichment (Epic 1) incomplete: use `holding.sector` or `security.data` JSON

**Acceptance Criteria**
- Job runs successfully for single user
- Aggregates calculated correctly
- Snapshot saved with status: complete
- Failed job sets status: error and logs error message
- Batch scheduler processes all active users
- Idempotency: Running job twice on same day doesn't duplicate snapshots
- Job duration logged for monitoring

**Test Cases**

**Unit (RSpec)**
```ruby
RSpec.describe FinancialSnapshotJob, type: :job do
  let(:user) { create(:user, :with_accounts_and_holdings) }

  describe '#perform' do
    it 'creates snapshot with correct aggregates' do
      expect {
        described_class.perform_now(user.id)
      }.to change(FinancialSnapshot, :count).by(1)

      snapshot = FinancialSnapshot.last
      expect(snapshot.status).to eq('complete')
      expect(snapshot.data['aggregates']['total_net_worth']).to be_present
    end

    it 'skips recent snapshots' do
      create(:financial_snapshot, user: user, snapshot_date: Date.today, updated_at: 30.minutes.ago)

      expect {
        described_class.perform_now(user.id)
      }.not_to change(FinancialSnapshot, :count)
    end

    it 'handles errors gracefully' do
      allow_any_instance_of(FinancialSnapshotJob).to receive(:calculate_aggregates).and_raise(StandardError, 'Test error')

      described_class.perform_now(user.id)

      snapshot = FinancialSnapshot.last
      expect(snapshot.status).to eq('error')
      expect(snapshot.data['error']).to eq('Test error')
    end
  end
end
```

**System (Capybara)**
- N/A (background job, no UI yet)

**Manual Testing**
- Run job manually: `FinancialSnapshotJob.perform_now(user.id)`
- Check snapshot created: `FinancialSnapshot.last`
- Verify aggregates match expected values
- Check Sidekiq dashboard for job status
- Trigger error (e.g., delete user mid-job) and verify error handling

**Workflow**
1. `git pull origin main`
2. `git checkout -b feature/prd-2-02-snapshot-core`
3. `rails g job FinancialSnapshotJob`
4. Implement job with aggregate calculations
5. Add error handling and retry logic
6. Create DailySnapshotSchedulerJob
7. Configure sidekiq-scheduler
8. Write RSpec tests
9. `rspec spec/jobs/financial_snapshot_job_spec.rb`
10. Manual test with console
11. Commit green: `git commit -m "Add daily FinancialSnapshotJob with core aggregates and error handling [PRD-2-02]"`
12. Push & PR

**Notes**
- Fallback logic if Epic 1 incomplete: Use `holding.sector || security.data['sector'] || 'Unknown'`
- Monitor job duration: Log start/end times, alert if >5 min per 1000 users
- Future optimization: Consider caching account balances if calculation is expensive
- Historical backfill deferred to future epic (accept no data for first 30 days)

---

### Stub PRDs (2-03 through 2-09)

**PRD-2-03: Snapshot – Asset Allocation Breakdown**
- Extend FinancialSnapshotJob to add `allocation` key to data JSON
- Calculate percent and value for stocks, bonds, cash, real estate, other
- Fallback to `holding.security_type` or SecurityEnrichment columns

**PRD-2-04: Snapshot – Sector Weights**
- Extend FinancialSnapshotJob to add `sectors` key to data JSON
- Calculate percent and value for equity sectors (technology, healthcare, financials, etc.)
- Use SecurityEnrichment.sector_primary if available, else fallback to `holding.sector`

**PRD-2-05: Snapshot – Holdings & Transactions Summary**
- Extend FinancialSnapshotJob to add `top_holdings` and `transaction_summary` keys
- Top 10 holdings by value with symbol, name, value, percent
- Monthly transaction summary: count, total_spent, top categories

**PRD-2-06: Snapshot – Historical Deltas (NO ARRAY)**
- Extend FinancialSnapshotJob to add `trends` key to data JSON
- Calculate day-over-day and month-over-month deltas by fetching prior snapshots
- Compute value_change and percent_change
- **Important:** Do NOT store historical array in JSON; compute deltas from prior snapshots

**PRD-2-07: Snapshot Validation & Admin Preview**
- Create `/admin/snapshots` (list view) and `/admin/snapshots/:id` (show view)
- Display data quality score as progress ring
- List warnings/issues for each snapshot
- "Regenerate Snapshot" button for admins (triggers job)

**PRD-2-08: Snapshot Export API**
- Create `/snapshots/:id/export` endpoint (JSON/CSV formats)
- Add `/snapshots/:id/rag_context` endpoint for AI tutor RAG integration
- RAG context returns sanitized, compact JSON:
  ```json
  {
    "user_id_hash": "sha256(user_id)",
    "snapshot_date": "2026-01-21",
    "net_worth": 125000.00,
    "asset_allocation": { ... },
    "sector_weights": { ... },
    "warnings": []
  }
  ```
- Strip sensitive fields (account numbers, full names, etc.)

**PRD-2-09: Dashboard Layout & Navigation Integration**
- Create `/net_worth/dashboard` controller and view
- Use authenticated layout from PRD-2-00
- Fetch latest snapshot for current user
- Display aggregate tiles: Net Worth, Assets, Liabilities, 30-day change
- Grid layout with quick links to allocations, sectors, holdings
- Breadcrumbs: Net Worth > Dashboard
- **Dependency correction:** PRD-2-00 + PRD-2-02 (not PRD-2-08)

---

**End of Epic 2 PRDs**

All PRDs now incorporate feedback from review document:
- ✅ Schema versioning (PRD-2-01)
- ✅ Unique constraints and status tracking (PRD-2-01)
- ✅ Error handling and retry logic (PRD-2-02)
- ✅ Batch processing and monitoring (PRD-2-02)
- ✅ Fallback logic for SecurityEnrichment (PRD-2-02, 2-03, 2-04)
- ✅ RAG context endpoint (PRD-2-08)
- ✅ Fixed dependency for PRD-2-09
- ✅ Feature flag for layout rollout (PRD-2-00)
- ✅ Comprehensive test cases and manual checklists

Epic 2 is ready for implementation. Start with PRD-2-00 (zero dependencies) or run PRD-2-00 and PRD-2-01 in parallel.