# Epic 3 Additions: UI Updates & New PRDs

**Purpose**: This document contains ONLY the changes/additions needed for Epic 3 based on feedback review and Eric's responses.

---

## Global Updates (Apply to ALL Epic 3 PRDs)

### 1. Routing Update: Use Nested Namespace

**Issue**: Current epic references flat controller names (`NetWorthController`, `AllocationsController`, etc.)

**Fix**: Use nested namespace for better organization:

**Routing**:
```ruby
namespace :net_worth do
  resource :dashboard, only: :show
  resources :allocations, only: :show
  resources :sectors, only: :show
  resources :performance, only: :show
  resources :holdings, only: :index
  resources :transactions, only: :index
  resources :liabilities, only: :index
end
```

**Controllers**:
- `NetWorth::DashboardController#show` (was NetWorthController)
- `NetWorth::AllocationsController#show`
- `NetWorth::SectorsController#show`
- `NetWorth::PerformanceController#show`
- `NetWorth::HoldingsController#index` (NEW)
- `NetWorth::TransactionsController#index` (NEW)
- `NetWorth::LiabilitiesController#index` (NEW)

**Paths**:
- `/net_worth/dashboard` (root dashboard)
- `/net_worth/allocations`
- `/net_worth/sectors`
- `/net_worth/performance`
- `/net_worth/holdings`
- `/net_worth/transactions`
- `/net_worth/liabilities`

---

### 2. Chart Library Decision: Use Chartkick

**Issue**: PRD-3-04 says "no lib" and uses CSS/SVG for charts, but Eric's feedback suggests using chartkick.

**Fix**: Install and use chartkick + groupdate gems for performance placeholder (and future charts).

**Installation**:
```bash
bundle add chartkick groupdate
```

**Layout**:
```erb
<!-- app/views/layouts/application.html.erb -->
<%= javascript_include_tag "chartkick", "Chart.bundle" %>
```

**Usage** (PRD-3-04):
```erb
<%= line_chart @historical_data, library: {
  title: { text: 'Net Worth Trend (Last 30 Days)' },
  colors: ['#1f77b4']
} %>
```

**Rationale**: Per Eric's feedback, use chartkick for lightweight charting instead of custom CSS/SVG.

---

### 3. Update JSON Access: Use Nested Hash Structure

**Issue**: Epic 2 now stores `{ "percent": 0.62, "value": 16228311.38 }` for allocation/sectors.

**Fix**: Update all component JSON access to handle nested structure:

**Before**:
```ruby
allocation["equity"] # => 0.62
```

**After**:
```ruby
allocation["equity"]["percent"] # => 0.62
allocation["equity"]["value"] # => 16228311.38
```

---

## PRD-Specific Updates

### PRD-3-01 Update: Display Both Value + Percent in Deltas

**Changes**:
- Update component to show both absolute and percentage deltas:
  ```erb
  <div class="badge badge-success">
    +$124,500 (0.48%)
  </div>
  ```
- Calculate percentage from JSON:
  ```ruby
  delta_day = snapshot.data["delta_day"]
  delta_day_pct = (delta_day / snapshot.data["total_net_worth"]) * 100
  ```

---

### PRD-3-02 Update: Asset Allocation with Value + Percent Tooltips

**Changes**:
- Update component to display both percent and value from nested JSON:
  ```erb
  <% allocation.each do |asset_class, data| %>
    <div class="progress-bar" style="width: <%= data['percent'] * 100 %>%;"
         title="<%= asset_class.titleize %>: <%= number_to_percentage(data['percent'] * 100, precision: 2) %> ($<%= number_with_delimiter(data['value']) %>)">
    </div>
  <% end %>
  ```
- Or use DaisyUI native tooltips:
  ```erb
  <div class="tooltip" data-tip="<%= asset_class.titleize %>: <%= data['percent'] * 100 %>% ($<%= number_with_delimiter(data['value']) %>)">
    <div class="progress-bar" style="width: <%= data['percent'] * 100 %>%;"></div>
  </div>
  ```

---

### PRD-3-03 Update: Sector Weights with Value + Percent Tooltips

**Changes**:
- Update component to display both percent and value:
  ```erb
  <% weights.each do |sector, data| %>
    <tr>
      <td><%= sector.titleize %></td>
      <td><%= number_to_percentage(data['percent'] * 100, precision: 2) %></td>
      <td>$<%= number_with_delimiter(data['value']) %></td>
    </tr>
  <% end %>
  ```

---

### PRD-3-04 Update: Use Chartkick for Performance Placeholder

**Changes**:
- Replace "no lib" CSS/SVG with chartkick line chart
- Update component to use chartkick:
  ```erb
  <%= line_chart @historical_data, library: {
    title: { text: 'Net Worth Trend (Last 30 Days)' },
    colors: ['#1f77b4']
  } %>
  ```
- Controller fetches historical data on-demand (NOT from JSON):
  ```ruby
  def show
    @historical_data = current_user.financial_snapshots
                                   .where('snapshot_date >= ?', 30.days.ago)
                                   .order(:snapshot_date)
                                   .pluck(:snapshot_date, Arel.sql("data->>'total_net_worth'"))
                                   .map { |date, value| [date, value.to_f] }
                                   .to_h
  end
  ```

**Updated Requirements**:
- Install chartkick + groupdate gems
- Query snapshots directly (Epic 2 PRD-2-06 removed historical_net_worth from JSON)
- Use chartkick line_chart helper

---

### PRD-3-05 Update: Nested Routing + Update Links

**Changes**:
- Update controller name: `NetWorthController` → `NetWorth::DashboardController`
- Update route: `/net_worth` → `/net_worth/dashboard`
- Update sidebar links to use nested paths:
  ```erb
  <%= link_to "Dashboard", net_worth_dashboard_path %>
  <%= link_to "Asset Allocation", net_worth_allocations_path %>
  <%= link_to "Sector Weights", net_worth_sectors_path %>
  <%= link_to "Performance", net_worth_performance_path %>
  <%= link_to "Holdings", net_worth_holdings_path %>
  <%= link_to "Transactions", net_worth_transactions_path %>
  ```

---

## New PRDs (Add to Epic 3)

### PRD-3-06: Holdings Summary View (NEW)

**Overview**
Build holdings list page showing top holdings table from snapshot JSON with expand/collapse for full list.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Controller: `NetWorth::HoldingsController#index`.
- View: Table with columns: Ticker, Name, Value, % Portfolio (from snapshot.data["top_holdings"]).
- Expand: "View All Holdings" button loads full Holdings.where(user: current_user).order(institution_value: :desc) via Turbo Frame.
- Empty state: "No holdings data" if nil.

**Non-Functional**
- Responsive: Table scrolls horizontally on mobile.
- Performant: Use snapshot JSON for top 10, query on expand only.

**Architectural Context**
- Rails: Controller + ViewComponent (HoldingsSummaryComponent).
- UI: `knowledge_base/UI/templates/table.md` for structure.

**Acceptance Criteria**
- Renders top 10 holdings from snapshot JSON.
- Expand button loads full list via Turbo Frame.
- % Portfolio sums to correct total.
- Handles no holdings (empty state).

**Test Cases**
- Controller spec:
  ```ruby
  describe NetWorth::HoldingsController do
    it "renders holdings summary" do
      get net_worth_holdings_path
      expect(response.body).to include("AAPL")
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-06-holdings-summary`
- Use `rails g controller net_worth/holdings index`
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-3-07: Transactions Summary View (NEW)

**Overview**
Build transactions summary page showing monthly income/expenses from snapshot JSON with link to full transaction list.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Controller: `NetWorth::TransactionsController#index`.
- View: Card with summary stats (income, expenses, top categories from snapshot.data["monthly_transaction_summary"]).
- Link: "View All Transactions" → full paginated Transaction list (Epic 4).
- Empty state: "No transaction data" if nil.

**Non-Functional**
- Responsive: Cards stack on mobile.

**Architectural Context**
- Rails: Controller + ViewComponent (TransactionsSummaryComponent).
- UI: `knowledge_base/UI/templates/general.md` for card layout.

**Acceptance Criteria**
- Renders income, expenses, top 5 categories from snapshot JSON.
- Link navigates correctly.
- Handles no transactions (empty state).

**Test Cases**
- Controller spec:
  ```ruby
  describe NetWorth::TransactionsController do
    it "renders transaction summary" do
      get net_worth_transactions_path
      expect(response.body).to include("Income")
      expect(response.body).to include("Expenses")
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-07-transactions-summary`
- Use `rails g controller net_worth/transactions index`
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-3-08: Snapshot Export Button (NEW)

**Overview**
Add "Export Snapshot" button to net worth dashboard linking to snapshot export endpoint (Epic 2 PRD-2-09).

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Button: In net_worth/dashboard/show.html.erb, render button with dropdown for format (JSON/CSV).
- Link: `link_to "Export JSON", export_snapshot_path(@latest_snapshot, format: :json), class: "btn btn-ghost btn-sm"`.
- Placement: Top-right of dashboard (near refresh widget).

**Non-Functional**
- Download triggers immediately (no page navigation).

**Architectural Context**
- Rails: Simple link helper in view.
- Dependencies: Epic 2 PRD-2-09 (export endpoint).

**Acceptance Criteria**
- Button renders on dashboard.
- Click triggers download (JSON or CSV).
- Non-owner sees no button (or disabled).

**Test Cases**
- View spec:
  ```ruby
  it "renders export button" do
    render
    expect(rendered).to have_link("Export JSON")
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-08-export-button`
- Update net_worth/dashboard/show.html.erb.
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

### PRD-3-09: Refresh Snapshot / Sync Status Widget (NEW)

**Overview**
Add widget to dashboard showing last sync time and "Refresh" button to trigger new snapshot generation.

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Widget: Component showing `@latest_snapshot.snapshot_date` + "Last synced X hours ago" + status badge.
- Refresh button: `button_to "Refresh", refresh_snapshot_path, method: :post, class: "btn btn-primary btn-sm"`.
- Endpoint: `POST /snapshots/refresh` → enqueues FinancialSnapshotJob.perform_later(current_user).
- Feedback: Turbo Stream replaces widget with "Refreshing..." spinner, then updated snapshot on completion.

**Non-Functional**
- Non-blocking: Button stays clickable (rate limit: max 1 refresh per 5 minutes).

**Architectural Context**
- Rails: SnapshotsController#refresh action.
- Turbo: Use Turbo Streams for async update.
- UI: `knowledge_base/UI/STYLE_GUIDE.md` for badge/button styles.

**Acceptance Criteria**
- Widget shows last sync time + status.
- Refresh button triggers job.
- Rate limiting prevents spam (flash message if <5min since last refresh).
- Turbo Stream updates widget on completion.

**Test Cases**
- Controller spec:
  ```ruby
  describe SnapshotsController do
    it "enqueues snapshot job on refresh" do
      expect {
        post refresh_snapshot_path
      }.to have_enqueued_job(FinancialSnapshotJob).with(current_user)
    end
    it "rate limits refresh" do
      post refresh_snapshot_path
      post refresh_snapshot_path
      expect(flash[:alert]).to include("Please wait")
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-09-refresh-widget`
- Use `rails g controller snapshots refresh`
- Commit green.
- Default LLM: Claude Sonnet 4.5.

---

## Updated Epic 3 PRD Priority Table

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| 1 | Net Worth Summary Card Component | Hero card with total NW + changes (value + %) | Epic 2 snapshots | feature/prd-3-01-nw-summary-card | **UPDATED** |
| 2 | Asset Allocation View | Breakdown with percent + value tooltips | PRD-3-01, Epic 2 PRD-2-03 | feature/prd-3-02-allocation-view | **UPDATED** |
| 3 | Sector Weights View | Equity sector % + value display | PRD-3-02, Epic 2 PRD-2-04 | feature/prd-3-03-sector-weights-view | **UPDATED** |
| 4 | Performance Placeholder View | Chartkick line chart from on-demand query | PRD-3-03, chartkick gem | feature/prd-3-04-performance-placeholder | **UPDATED** |
| 5 | Dashboard Layout & Navigation (NetWorth::Dashboard) | Nested routing, updated links | PRD-3-01–04 | feature/prd-3-05-dashboard-layout | **UPDATED** |
| **6** | **Holdings Summary View (NEW)** | Top holdings table with expand | Epic 2 PRD-2-05 | feature/prd-3-06-holdings-summary | **NEW** |
| **7** | **Transactions Summary View (NEW)** | Monthly transaction summary cards | Epic 2 PRD-2-05 | feature/prd-3-07-transactions-summary | **NEW** |
| **8** | **Snapshot Export Button (NEW)** | Export button for JSON/CSV download | Epic 2 PRD-2-09 | feature/prd-3-08-export-button | **NEW** |
| **9** | **Refresh Snapshot / Sync Status Widget (NEW)** | Refresh button + status indicator | Epic 2 snapshots | feature/prd-3-09-refresh-widget | **NEW** |

---

## Summary of Changes

**Global Updates**:
- Routing: Use nested namespace (NetWorth::*)
- Chart library: Install and use chartkick + groupdate
- JSON access: Handle nested `{ "percent": ..., "value": ... }` structure

**PRD Updates**:
- PRD-3-01: Display both value + percent in deltas
- PRD-3-02: Use nested JSON structure for tooltips (percent + value)
- PRD-3-03: Use nested JSON structure for table (percent + value)
- PRD-3-04: Replace CSS/SVG with chartkick, query snapshots on-demand
- PRD-3-05: Update to nested routing (NetWorth::DashboardController)

**New PRDs**:
- PRD-3-06: Holdings Summary View
- PRD-3-07: Transactions Summary View
- PRD-3-08: Snapshot Export Button
- PRD-3-09: Refresh Snapshot / Sync Status Widget

**Key Decisions**:
- Nested routing for better organization
- Chartkick for charts (not custom CSS/SVG)
- Query historical data on-demand (not from JSON)
- Both percentage and value displayed in UI
