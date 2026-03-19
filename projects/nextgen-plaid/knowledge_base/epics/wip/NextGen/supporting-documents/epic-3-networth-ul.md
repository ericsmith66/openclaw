### Epic 3: Build the UI for Net Worth Dashboards

**Epic Overview**  
Create clean, professional dashboard pages showing net worth summary, breakdowns, and trends using Tailwind + DaisyUI + ViewComponent. Adjusted for expanded v1 scope: net worth dashboard, asset allocation, sector weights, performance placeholder. Data from Epic 2 snapshots (JSON blobs).

**User Capabilities**  
Interns view aggregated net worth, changes, allocation %, sector exposure, trends (placeholder). Admins preview via Mission Control stub.

**Fit into Big Picture**  
Provides visual "aha" moment with personal data, grounding curriculum in real context. Uses snapshots for fast renders.

**PRD Summary Table**

| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Net Worth Summary Card Component | Hero card with total NW + changes. | Epic 2 snapshots | feature/prd-3-01-nw-summary-card |
| 2 | Asset Allocation View | Breakdown pie/bar display. | #1 + allocation JSON | feature/prd-3-02-allocation-view |
| 3 | Sector Weights View | Equity sector % display. | #2 + sector JSON | feature/prd-3-03-sector-weights-view |
| 4 | Performance Placeholder View | Teaser trend line/chart stub. | #3 + historical JSON | feature/prd-3-04-performance-placeholder |
| 5 | Dashboard Layout & Navigation Integration | /net_worth route with sidebar links, grid for components. | #1–4 | feature/prd-3-05-dashboard-layout |

### PRD-3-01: Net Worth Summary Card Component

**Overview**  
Build a reusable ViewComponent for the net worth hero card showing total NW, day/30d changes, as-of date. Pulls from latest FinancialSnapshot.data JSON. This powers the main dashboard visual.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Component: `NetWorthSummaryComponent` (rails g component net_worth_summary snapshot:references).
- Render: Large card with h1 total_net_worth (formatted currency), badges for delta_day/30d (% + $), as-of timestamp.
- Positive deltas: success color; negative: error color.
- Empty state: "No snapshot yet" alert if nil.

**Non-Functional**
- Responsive: Full-width on mobile, centered on lg+.
- Performant: No extra queries (use passed snapshot.data).

**Architectural Context**
- Rails: ViewComponent in app/components, render in views (e.g., <%= render NetWorthSummaryComponent.new(snapshot: @latest_snapshot) %>).
- Data: From FinancialSnapshot.latest_for_user(current_user).data.
- UI: Follow `knowledge_base/UI/STYLE_GUIDE.md` (business theme, card bg-base-100 p-6 shadow border), `knowledge_base/UI/templates/general.md` for card structure.
- Privacy: User owns snapshot.

**Acceptance Criteria**
- Renders total NW as "$26,174,695.59" in h1.
- Delta_day "+$124,500 (0.48%)" in green badge.
- Delta_30d negative in red badge.
- As-of "As of Jan 17, 2026".
- No snapshot: Shows info alert.
- Currency: USD default, 2 decimals.
- Positive test: Matches JSON input.
- Mobile: Badges stack vertically.

**Test Cases**
- Component spec (RSpec):
  ```ruby
  describe NetWorthSummaryComponent do
    it "renders total and deltas" do
      snapshot = create(:financial_snapshot, data: { total_net_worth: 1000000, delta_day: 1000, delta_30d: -5000 })
      render_inline(NetWorthSummaryComponent.new(snapshot: snapshot))
      expect(page).to have_text("$1,000,000")
      expect(page).to have_css(".badge-success", text: "+$1,000")
      expect(page).to have_css(".badge-error", text: "-$5,000")
    end
    it "handles no snapshot" do
      render_inline(NetWorthSummaryComponent.new(snapshot: nil))
      expect(page).to have_css(".alert-info", text: "No snapshot yet")
    end
  end
  ```

**Workflow**
- Pull from master: `git pull origin main`
- Create branch: `git checkout -b feature/prd-3-01-nw-summary-card`
- Use `rails g component net_worth_summary`
- Ask questions and build a plan (e.g., "Badge colors? Currency format?").
- Commit only green code (tests pass).
- Default LLM: Claude Sonnet 4.5 in RubyMine.

### PRD-3-02: Asset Allocation View

**Overview**  
Build component and view for asset allocation page showing pie/bar breakdown from snapshot JSON. Reusable for dashboard embed.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Component: `AssetAllocationComponent` (pie or bar using CSS conic-gradient or simple DaisyUI progress bars).
- Render: % by class (equities, fixed_income, etc.) from data["asset_allocation"].
- Hover: Tooltip with exact % + value (if in JSON).
- Total: 100% footer.

**Non-Functional**
- Colors: Different accents per class (primary for equities, etc.).
- Responsive: Pie on lg+, stacked bars on mobile.

**Architectural Context**
- Rails: Component in app/components, render in allocations/show.html.erb.
- Data: snapshot.data["asset_allocation"] hash.
- UI: `knowledge_base/UI/STYLE_GUIDE.md` (business palette, card layout), `knowledge_base/UI/templates/general.md` for page grid.
- No lib deps (pure CSS pie).

**Acceptance Criteria**
- Renders pie/bar with correct % segments.
- Hover tooltip shows "Equities: 62% ($16,228,311)".
- Sums to 100% (handle rounding).
- Empty: "No allocation data" message.
- Colors consistent (e.g., blue for equities).
- Mobile: Bars vertical.
- Matches JSON input.

**Test Cases**
- Component spec:
  ```ruby
  describe AssetAllocationComponent do
    it "renders allocation bars" do
      data = { "equity": 0.62, "cash": 0.38 }
      render_inline(AssetAllocationComponent.new(allocation: data))
      expect(page).to have_css(".progress-bar", count: 2) # e.g.
      expect(page).to have_text("62%")
    end
  end
  ```

**Workflow**
- Pull from master: `git pull origin main`
- Create branch: `git checkout -b feature/prd-3-02-allocation-view`
- Use `rails g component asset_allocation`
- Ask questions and build a plan (e.g., "Pie vs bar? Color map?").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

### PRD-3-03: Sector Weights View

**Overview**  
Component and view for sector weights page showing % breakdown from JSON.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Component: `SectorWeightsComponent` (bar chart or list with progress bars).
- Render: % by sector from data["sector_weights"].
- Hover: Tooltip with % + value.
- Note: "Equity portion only".

**Non-Functional**
- Sort descending.
- Colors: Varied accents.

**Architectural Context**
- Rails: Component, render in sectors/show.html.erb.
- Data: snapshot.data["sector_weights"].
- UI: `knowledge_base/UI/STYLE_GUIDE.md`, `knowledge_base/UI/templates/general.md`.

**Acceptance Criteria**
- Renders bars/list with %.
- Hover shows "Technology: 28% ($7,321,314)".
- Sums ~100% (equities).
- Empty: "No sector data".
- Sorted high to low.
- Mobile responsive.

**Test Cases**
- Component spec:
  ```ruby
  describe SectorWeightsComponent do
    it "renders sector bars" do
      data = { "technology": 0.28, "healthcare": 0.15 }
      render_inline(SectorWeightsComponent.new(weights: data))
      expect(page).to have_text("28%")
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-03-sector-weights-view`
- Use `rails g component sector_weights`
- Ask questions (e.g., "Bar or list?").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

### PRD-3-04: Performance Placeholder View

**Overview**  
Placeholder component/view for performance page with teaser trend line from historical JSON.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- Component: `PerformancePlaceholderComponent` (simple line chart stub using CSS or mock SVG).
- Render: "Coming Soon" card with trend line from data["historical_net_worth"] (dates + values).
- Note: "Historical net worth trend".

**Non-Functional**
- Mock if <7 days data.
- Basic line (no lib).

**Architectural Context**
- Rails: Component, render in performance/show.html.erb.
- Data: snapshot.data["historical_net_worth"] array.
- UI: `knowledge_base/UI/STYLE_GUIDE.md`, `knowledge_base/UI/templates/general.md`.

**Acceptance Criteria**
- Renders "Coming Soon" + teaser line with points.
- Line reflects historical values.
- <3 points: "Insufficient data" message.
- Dates formatted.
- Responsive.

**Test Cases**
- Component spec:
  ```ruby
  describe PerformancePlaceholderComponent do
    it "renders trend placeholder" do
      history = [{date: "2026-01-01", value: 1000000}, {date: "2026-01-02", value: 1010000}]
      render_inline(PerformancePlaceholderComponent.new(history: history))
      expect(page).to have_text("Coming Soon")
      expect(page).to have_css(".trend-line") # e.g.
    end
  end
  ```

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-04-performance-placeholder`
- Use `rails g component performance_placeholder`
- Ask questions (e.g., "CSS line style?").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

### PRD-3-05: Dashboard Layout & Navigation Integration

**Overview**  
Integrate all components into /net_worth route with grid layout, update sidebar navigation for v1 pages.

**Log Requirements**  
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.

**Requirements**

**Functional**
- View: net_worth/show.html.erb with grid: hero card, allocation, sector, performance placeholder.
- Sidebar: Add links for allocations, sectors, performance (with badge).
- Breadcrumbs: Home > Net Worth.

**Non-Functional**
- Grid: 1-col mobile, 2-col lg+.
- Fast load: Use @latest_snapshot preload.

**Architectural Context**
- Rails: NetWorthController#show (fetch snapshot).
- UI: `knowledge_base/UI/STYLE_GUIDE.md`, `knowledge_base/UI/templates/general.md` for grid.
- Navigation: Update navigation_component.

**Acceptance Criteria**
- /net_worth renders all components in grid.
- Sidebar has new links + "Coming Soon" badge on performance.
- Breadcrumbs correct.
- Mobile: Stacked vertically.
- No errors if no snapshot (fallbacks from components).
- Links navigate correctly.

**Test Cases**
- Controller spec:
  ```ruby
  describe NetWorthController do
    it "renders dashboard with components" do
      get net_worth_path
      expect(response.body).to include("Net Worth Dashboard")
      expect(response.body).to include("Asset Allocation")
    end
  end
  ```
- View spec for navigation: Includes new links.

**Workflow**
- Pull master.
- Branch: `git checkout -b feature/prd-3-05-dashboard-layout`
- Use `rails g controller net_worth show`
- Ask questions (e.g., "Grid cols? Badge style?").
- Commit green.
- Default LLM: Claude Sonnet 4.5.

Next steps: Commit UI guide/templates to knowledge_base/UI/. Then implement Epic 2 first (snapshots), as Epic 3 depends on them. Questions: Any preferred grid order for components on net_worth page?