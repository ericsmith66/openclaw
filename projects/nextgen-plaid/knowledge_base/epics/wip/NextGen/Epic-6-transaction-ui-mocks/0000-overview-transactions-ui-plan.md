# Epic-6 Static Transaction UI Implementation Plan

**Date:** February 16, 2026  
**Goal:** Build five static transaction views (Cash, Investments, Credit Cards, Transfers, Summary) using mock data, ViewComponents, and DaisyUI for rapid prototyping without database dependencies.

## Current State Analysis

### Existing Infrastructure
- **Routes**: `/transactions/regular` and `/transactions/investment` exist but show "coming soon" placeholders
- **Controller**: `TransactionsController` has `regular` and `investment` actions (empty)
- **Component**: `TransactionTableComponent` exists for live data with sorting/pagination
- **Design System**: DaisyUI business theme + Tailwind, ViewComponent pattern well-established
- **Transaction Models**: STI implemented (`InvestmentTransaction`, `CreditTransaction`, `RegularTransaction`)

### Project Patterns
- ViewComponents used throughout (HoldingsGridComponent, TransactionTableComponent, etc.)
- DaisyUI components with business theme (`data-theme="business"`)
- YAML configuration common (plaid_costs.yml, personas.yml)
- Service objects for data provisioning

## Implementation Strategy

### 1. Mock Data Strategy (YAML-based)

**ARCHITECT NOTE**: YAML configuration files should be located in `config/` not `lib/mock_data/` to align with existing project patterns (plaid_costs.yml, personas.yml).

**Location**: `config/mock_transactions/`

**Files**:
- `cash.yml` - Depository account transactions (checking/savings)
- `investments.yml` - Investment transactions (buy/sell/dividend/interest)
- `credit.yml` - Credit/liability transactions (charges/payments)
- `transfers.yml` - Inter-account transfers
- `summary.yml` - Aggregated summary data for overview

**YAML Structure Example** (aligned with Transaction model fields):
```yaml
# config/mock_transactions/cash.yml
transactions:
  - date: "2026-01-15"
    name: "Starbucks"
    amount: -5.75
    merchant_name: "Starbucks"
    personal_finance_category_label: "FOOD_AND_DRINK"
    pending: false
    payment_channel: "in store"
    account_name: "Chase Checking"
    account_type: "depository"
    # Fields matching Transaction model schema:
    transaction_id: "mock_txn_001"
    source: "manual"
    subtype: null
    category: null
    
  - date: "2026-01-14"
    name: "Whole Foods"
    amount: -127.35
    merchant_name: "Whole Foods Market"
    personal_finance_category_label: "FOOD_AND_DRINK_GROCERIES"
    pending: false
    payment_channel: "in store"
    account_name: "Chase Checking"
    account_type: "depository"
    transaction_id: "mock_txn_002"
    source: "manual"
```

**YAML Structure for Investments**:
```yaml
# config/mock_transactions/investments.yml
transactions:
  - date: "2026-01-10"
    name: "Buy AAPL"
    amount: -5250.00
    subtype: "buy"
    quantity: 30.0
    price: 175.00
    fees: 0.00
    security_id: "sec_aapl_mock"
    security_name: "Apple Inc."
    iso_currency_code: "USD"
    account_name: "Schwab Brokerage"
    account_type: "investment"
    transaction_id: "mock_inv_001"
    source: "manual"
    type: "InvestmentTransaction"
```

**Service Class**: `MockTransactionDataProvider`
```ruby
# app/services/mock_transaction_data_provider.rb
# Follows HoldingsGridDataProvider pattern for consistency
class MockTransactionDataProvider
  def self.cash
    new('cash').call
  end
  
  def self.investments
    new('investments').call
  end
  
  def self.credit
    new('credit').call
  end
  
  def self.transfers
    new('transfers').call
  end
  
  def self.summary
    new('summary').call
  end
  
  def initialize(type)
    @type = type
    @file_path = Rails.root.join('config', 'mock_transactions', "#{type}.yml")
  end
  
  def call
    load_yaml
  end
  
  private
  
  attr_reader :type, :file_path
  
  def load_yaml
    return [] unless File.exist?(file_path)
    
    data = YAML.safe_load_file(file_path, permitted_classes: [Date, Time, Symbol])
    transactions = data['transactions'] || []
    
    # Convert to OpenStruct for attribute access like ActiveRecord
    transactions.map { |txn| OpenStruct.new(txn) }
  rescue StandardError => e
    Rails.logger.error "Failed to load mock transaction data for #{type}: #{e.message}"
    []
  end
end
```

### 2. Controller & Routes

**ARCHITECT DECISION**: Replace placeholder routes IMMEDIATELY instead of creating temporary mock routes. This reduces technical debt and aligns with existing route structure.

**Controller Updates** (modify `app/controllers/transactions_controller.rb`):
```ruby
# Update existing empty actions to use mock data
def regular
  @transactions = MockTransactionDataProvider.cash
  # Later: replace with Transaction.where(type: 'RegularTransaction')
end

def investment
  @transactions = MockTransactionDataProvider.investments
  # Later: replace with Transaction.where(type: 'InvestmentTransaction')
end

# Add new actions for credit and transfers
def credit
  @transactions = MockTransactionDataProvider.credit
  # Later: replace with Transaction.where(type: 'CreditTransaction')
end

def transfers
  @transactions = MockTransactionDataProvider.transfers
  # Later: filter by transfer-specific subtype
end

def summary
  @summary_data = MockTransactionDataProvider.summary
  # Later: build from Transaction.aggregate queries
end
```

**Routes** (update `config/routes.rb`):
```ruby
# Already exist - just update controller actions:
get "/transactions/regular", to: "transactions#regular"
get "/transactions/investment", to: "transactions#investment"

# Add new routes:
get "/transactions/credit", to: "transactions#credit"
get "/transactions/transfers", to: "transactions#transfers"
get "/transactions/summary", to: "transactions#summary"
```

**RATIONALE**: 
- No temporary routes to clean up later
- Consistent with existing route naming conventions
- `/transactions/regular` maps naturally to `RegularTransaction` STI type
- `/transactions/investment` maps to `InvestmentTransaction` STI type
- Clean migration path from mock to live data (same route, swap data source)

### 3. Reusable ViewComponents

**ARCHITECT CRITICAL FINDING**: Existing `TransactionTableComponent` is TOO SIMPLE (only accepts transactions array). Need rich components following `Portfolio::HoldingsGridComponent` patterns.

Create namespace and comprehensive components:

#### **Transactions::GridComponent** (Primary Container)
**Location**: `app/components/transactions/grid_component.rb`

**Responsibilities**:
- Main orchestrator (like `Portfolio::HoldingsGridComponent`)
- Handles pagination, sorting, filtering UI
- Renders header, filter bar, transaction groups, footer
- Accepts: transactions, total_count, page, per_page, sort, dir, type_filter
- Uses Turbo Frame for dynamic updates: `turbo_frame_tag "transactions_grid"`

**Pattern Match**: Follows HoldingsGridComponent initialization pattern with comprehensive params

#### **Transactions::RowComponent**
**Location**: `app/components/transactions/row_component.rb`

**Responsibilities**:
- Renders single transaction row with type-specific styling
- Color coding: DaisyUI success/error classes (text-success for positive, text-error for negative)
- Type-specific columns (show quantity/price for investments, payment_channel for credit)
- Responsive: collapses secondary fields on mobile using `hidden lg:table-cell`

**Key Features**:
- `def amount_class` - returns DaisyUI color classes based on positive/negative
- `def type_badge` - returns badge component for transaction type
- `def formatted_date` - consistent date formatting across app

#### **Transactions::MonthlyGroupComponent**
**Location**: `app/components/transactions/monthly_group_component.rb`

**Responsibilities**:
- Groups transactions by month using DaisyUI collapse/accordion
- Expand/collapse with Stimulus controller (optional)
- Monthly summary: total count, net amount, spending breakdown
- Renders `Transactions::RowComponent` for each transaction

**DaisyUI Pattern**:
```erb
<div class="collapse collapse-arrow bg-base-200 mb-2">
  <input type="checkbox" checked />
  <div class="collapse-title text-xl font-medium">
    January 2026 • <%= transactions.count %> transactions • <%= format_currency(net_amount) %>
  </div>
  <div class="collapse-content">
    <table class="table table-zebra w-full">
      <!-- Transaction rows -->
    </table>
  </div>
</div>
```

#### **Transactions::FilterBarComponent** (NOT FilterStubComponent)
**Location**: `app/components/transactions/filter_bar_component.rb`

**ARCHITECT NOTE**: Don't call it "stub" - build it properly but with non-functional backend initially.

**Responsibilities**:
- Search input (DaisyUI form-control)
- Date range picker (using native `<input type="date">`)
- Type filter dropdown (Regular/Investment/Credit/Transfer/All)
- Amount threshold toggle (e.g., "Show large transactions only >$1000")
- "Clear Filters" button

**Implementation**: Form with GET method, params submitted to same route. Controller ignores filters during mock phase, but form is ready for live data.

#### **Transactions::SummaryCardComponent**
**Location**: `app/components/transactions/summary_card_component.rb`

**Responsibilities**:
- Overview stats (follows `NetWorth::BaseCardComponent` pattern)
- Total transactions, net amount, top category, avg transaction
- Monthly trend sparkline (optional: use simple SVG or defer to Phase 2)
- DaisyUI stat cards layout

**Pattern**: Use `<div class="stats stats-vertical lg:stats-horizontal shadow">`

### 4. View Templates Structure

**ARCHITECT PATTERN**: Follow existing view patterns from `app/views/portfolio/holdings/index.html.erb` and `app/views/net_worth/dashboard/show.html.erb`.

Each view will use **LayoutComponent** with consistent structure:

```erb
<%# app/views/transactions/regular.html.erb %>
<%= render LayoutComponent.new(title: "Transactions • Cash & Checking", current_user: current_user) do %>
  <div class="container mx-auto">
    
    <%# Hero Section - Summary Stats %>
    <div class="mb-6">
      <h1 class="text-3xl font-bold mb-2">Cash Transactions</h1>
      <%= render Transactions::SummaryCardComponent.new(transactions: @transactions) %>
    </div>
    
    <%# Turbo Frame for dynamic updates %>
    <%= turbo_frame_tag "transactions_grid" do %>
      <%= render Transactions::FilterBarComponent.new(
        search_term: params[:search_term],
        date_from: params[:date_from],
        date_to: params[:date_to],
        type_filter: params[:type_filter]
      ) %>
      
      <%= render Transactions::GridComponent.new(
        transactions: @transactions,
        total_count: @transactions.size,
        page: params[:page].to_i > 0 ? params[:page].to_i : 1,
        per_page: params[:per_page].presence || "25",
        sort: params[:sort].presence || "date",
        dir: params[:dir].presence || "desc"
      ) %>
    <% end %>
    
  </div>
<% end %>
```

**CRITICAL**: Remove "Static mock data for prototyping" disclaimer. From user perspective, this IS the transaction view. Mock vs live is implementation detail.

**Responsive Pattern**:
- Container: `container mx-auto px-4 lg:px-6`
- Cards: `bg-base-100 rounded-lg shadow p-6`
- Spacing: Consistent `mb-6` between sections
- Mobile-first: Stack cards vertically, use horizontal scroll for wide tables

### 5. Type-Specific Customizations

#### **Cash View** (PRD-TX-UI-01)
- Focus on depository accounts only
- Monthly spending patterns visualization
- Large transaction highlighting (> $1,000)
- Account balance stubs

#### **Investments View** (PRD-TX-UI-02)
- Security/ticker columns
- Trade vs income highlighting
- Portfolio context sidebar (mock)
- Wash sale risk flag display

#### **Credit View** (PRD-TX-UI-03)
- Pending/auth emphasis
- Utilization insights (mock calculations)
- Rewards/cashback indicators
- Payment due date stubs

#### **Transfers View** (PRD-TX-UI-04)
- Direction icons (in/out arrows)
- Monthly income pattern highlighting
- Recurring transfer detection (mock)
- Exclude non-transfer noise

#### **Summary View** (PRD-TX-UI-05)
- Aggregated cards (monthly totals, top categories)
- Pie chart stubs (Chart.js or DaisyUI progress)
- Top merchants/categories list
- Transfer income trends

## Implementation Sequence (REVISED BY ARCHITECT)

### Phase 1: Foundation & Infrastructure (2-3 days)
**Goal**: Build core data provider and component framework

**Tasks**:
1. ✅ Create `config/mock_transactions/` directory
2. ✅ Build `MockTransactionDataProvider` service with caching
3. ✅ Create `Transactions::RowComponent` (simplest component)
4. ✅ Create realistic `config/mock_transactions/cash.yml` (100+ transactions spanning 6 months)
5. ✅ Update `TransactionsController#regular` to use mock provider
6. ✅ Create basic `app/views/transactions/regular.html.erb` rendering raw table
7. ✅ RSpec tests: MockTransactionDataProvider, RowComponent

**Success Criteria**: `/transactions/regular` renders 100+ cash transactions in simple table

**Files**:
- `config/mock_transactions/cash.yml`
- `app/services/mock_transaction_data_provider.rb`
- `app/components/transactions/row_component.rb` + `.html.erb`
- `app/views/transactions/regular.html.erb`
- `spec/services/mock_transaction_data_provider_spec.rb`
- `spec/components/transactions/row_component_spec.rb`

---

### Phase 2: Rich Grid Components (3-4 days)
**Goal**: Build HoldingsGrid-equivalent components for transactions

**Tasks**:
1. ✅ Create `Transactions::GridComponent` with pagination, sorting UI
2. ✅ Create `Transactions::FilterBarComponent` with functional UI
3. ✅ Create `Transactions::MonthlyGroupComponent` with DaisyUI collapse
4. ✅ Create `Transactions::SummaryCardComponent` with stats
5. ✅ Update `regular.html.erb` to use full component stack
6. ✅ Add Turbo Frame integration for dynamic updates
7. ✅ Component specs for all new components

**Success Criteria**: 
- `/transactions/regular` has pagination, filters (UI only), monthly grouping
- Professional DaisyUI styling matching HoldingsGrid quality
- All components render without errors in isolation

**Files**:
- `app/components/transactions/grid_component.rb` + `.html.erb`
- `app/components/transactions/filter_bar_component.rb` + `.html.erb`
- `app/components/transactions/monthly_group_component.rb` + `.html.erb`
- `app/components/transactions/summary_card_component.rb` + `.html.erb`
- Component specs for each

---

### Phase 3: Investments View (2 days)
**Goal**: Leverage existing components for investment transactions

**Tasks**:
1. ✅ Create `config/mock_transactions/investments.yml` (50+ buy/sell/dividend transactions)
2. ✅ Update `TransactionsController#investment` to use mock provider
3. ✅ Create `app/views/transactions/investment.html.erb`
4. ✅ Add investment-specific columns to RowComponent (quantity, price, security name)
5. ✅ Add investment-specific insights (trade volume, dividend summary)
6. ✅ System test: verify investments render correctly

**Success Criteria**: `/transactions/investment` shows investment-specific fields

**Files**:
- `config/mock_transactions/investments.yml`
- `app/views/transactions/investment.html.erb`
- Updated `transactions/row_component.rb` with investment fields

---

### Phase 4: Credit & Transfers Views (2 days)
**Goal**: Complete the five view types

**Tasks**:
1. ✅ Create `config/mock_transactions/credit.yml` and `transfers.yml`
2. ✅ Add `TransactionsController#credit` and `#transfers` actions
3. ✅ Add routes to `config/routes.rb`
4. ✅ Create view templates (reusing components)
5. ✅ Add type-specific badges/styling in RowComponent
6. ✅ System tests for both routes

**Success Criteria**: All five transaction views accessible and functional

**Files**:
- `config/mock_transactions/credit.yml`
- `config/mock_transactions/transfers.yml`
- `app/views/transactions/credit.html.erb`
- `app/views/transactions/transfers.html.erb`
- Route additions in `config/routes.rb`

---

### Phase 5: Summary View & Polish (2 days)
**Goal**: Aggregated overview and final refinements

**Tasks**:
1. ✅ Create `config/mock_transactions/summary.yml` with aggregated stats
2. ✅ Build `TransactionsController#summary` action
3. ✅ Create dashboard-style summary view with cards and charts (DaisyUI stats)
4. ✅ Add navigation links between transaction views (tabs or sidebar)
5. ✅ Responsive testing (mobile/tablet/desktop)
6. ✅ Accessibility audit (ARIA labels, keyboard navigation)
7. ✅ Final polish: loading states, empty states, error states

**Success Criteria**: 
- `/transactions/summary` provides useful overview
- All views are mobile-friendly
- Navigation between views is intuitive

**Files**:
- `config/mock_transactions/summary.yml`
- `app/views/transactions/summary.html.erb`
- Navigation component/partial

---

## Total Timeline: 11-14 days (2-3 weeks)

## File Structure (REVISED)

```
config/mock_transactions/               # YAML configs (not lib/)
├── cash.yml                           # 50+ depository transactions
├── investments.yml                    # 50+ investment transactions
├── credit.yml                         # 50+ credit card transactions
├── transfers.yml                      # 50+ transfer transactions
└── summary.yml                        # Aggregated summary data

app/services/
└── mock_transaction_data_provider.rb  # Naming: *Provider suffix (pattern consistency)

app/controllers/transactions_controller.rb
# Update: regular, investment actions
# Add: credit, transfers, summary actions

app/views/transactions/
├── regular.html.erb                   # Update existing (no "mock_" prefix)
├── investment.html.erb                # Update existing
├── credit.html.erb                    # NEW
├── transfers.html.erb                 # NEW
└── summary.html.erb                   # NEW

app/components/transactions/           # Namespaced components
├── grid_component.rb                  # Primary orchestrator
├── grid_component.html.erb
├── row_component.rb                   # Single transaction row
├── row_component.html.erb
├── monthly_group_component.rb         # Month accordion/collapse
├── monthly_group_component.html.erb
├── filter_bar_component.rb            # Search/filters (functional UI)
├── filter_bar_component.html.erb
├── summary_card_component.rb          # Stats overview
└── summary_card_component.html.erb

config/routes.rb
# Update existing routes (no new mock routes):
# get "/transactions/regular" - already exists
# get "/transactions/investment" - already exists
# Add:
# get "/transactions/credit"
# get "/transactions/transfers"
# get "/transactions/summary"
```

**ARCHITECT NOTES**:
1. **No lib/mock_data/** - Use `config/` for YAML (project convention)
2. **No mock_ prefixes** in routes/views - Clean URLs from day one
3. **Namespace components** under `Transactions::` module (scalability)
4. **Pattern consistency** with `Portfolio::HoldingsGridComponent` approach
5. **Migration ready** - Same routes work for mock and live data

## Success Metrics

1. **Functionality**
   - All five static views render without database queries
   - Each view shows 50+ realistic mock transactions
   - Components are reusable and follow established patterns
   - Routes are accessible (200 OK responses)

2. **UI/UX Quality**
   - Matches DaisyUI business theme and existing styling
   - Responsive design (mobile-first)
   - Professional, minimalist aesthetic for HNW users (22-30 demographic)
   - Clear visual hierarchy and information density

3. **Code Quality**
   - ViewComponents follow existing patterns
   - YAML data is well-structured and realistic
   - Service class is testable and extensible
   - No breaking changes to existing functionality

4. **Future-Ready**
   - Easy transition from mock to live data
   - Components can be reused with real Transaction models
   - Routes can be consolidated into final transaction dashboard

## Architectural Risks & Mitigation

### CRITICAL RISKS IDENTIFIED BY ARCHITECT:

#### Risk 1: Mock Data Structure Divergence
**Issue**: Mock YAML structure might drift from actual Transaction model schema, causing painful migration to live data.

**Mitigation**:
- ✅ Use EXACT Transaction model field names in YAML
- ✅ Include all required fields: `transaction_id`, `date`, `amount`, `name`, `source`
- ✅ Use OpenStruct in provider to mimic ActiveRecord attribute access
- ✅ Test transition: Add controller flag `USE_MOCK_DATA = true` that swaps between `MockTransactionDataProvider.cash` and `Transaction.where(type: 'RegularTransaction')` without view changes

#### Risk 2: Component API Mismatch
**Issue**: Simple components now may not scale to complex live data needs (pagination, sorting, filtering).

**Mitigation**:
- ✅ Build `Transactions::GridComponent` with FULL feature set from day one (pagination, sort, filter params)
- ✅ Mock data provider returns paginated subset (slicing array)
- ✅ FilterBarComponent renders functional UI even if backend ignores params initially
- ✅ Use Turbo Frames for partial updates (works with mock and live data)

#### Risk 3: ViewComponent Overengineering
**Issue**: Creating too many granular components increases maintenance burden.

**Mitigation**:
- ✅ Limit to 5 core components (Grid, Row, MonthlyGroup, FilterBar, SummaryCard)
- ✅ Use partials for one-off type-specific UI (e.g., investment wash sale warning)
- ✅ Defer chart components to Phase 2 (use DaisyUI progress bars/stats initially)

#### Risk 4: Performance - YAML Parsing on Every Request
**Issue**: Loading 50+ transactions from YAML on every page load is inefficient.

**Mitigation**:
- ✅ Use Rails.cache.fetch in MockTransactionDataProvider:
  ```ruby
  def load_yaml
    Rails.cache.fetch("mock_transactions_#{type}", expires_in: 1.hour) do
      # YAML.safe_load_file logic
    end
  end
  ```
- ✅ Cache key invalidates when YAML file modified (use file mtime in cache key)
- ✅ Acceptable for prototyping; remove when switching to database

#### Risk 5: STI Type Confusion
**Issue**: Transaction STI types (InvestmentTransaction, CreditTransaction, RegularTransaction) might not align with route segmentation.

**Mitigation**:
- ✅ Regular route → RegularTransaction type (depository accounts)
- ✅ Investment route → InvestmentTransaction type
- ✅ Credit route → CreditTransaction type (credit cards, loans)
- ✅ Transfers route → Filter by `subtype` field (transfer, payroll, etc.) NOT by STI type
- ✅ Document in controller comments which STI type each route maps to

#### Risk 6: Testing Gaps
**Issue**: Mock data hard to test comprehensively without database integration.

**Mitigation**:
- ✅ RSpec unit tests for MockTransactionDataProvider (YAML loading, error handling)
- ✅ Component specs for each ViewComponent (render without errors, correct classes)
- ✅ Controller tests: verify @transactions populated, view renders
- ✅ System tests (Capybara): smoke test each route returns 200, key elements present
- ✅ NO integration tests between components and database yet (Phase 2)

### Additional Risk Mitigation:
- **Scope Creep**: ✅ No filtering/sorting logic in controllers during mock phase - just render arrays
- **Design Inconsistency**: ✅ Strict adherence to STYLE_GUIDE.md and existing component patterns
- **Breaking Changes**: ✅ No modifications to existing Transaction model or TransactionsController#index

## Next Steps

1. Begin Phase 1 implementation:
   - Create YAML structure and sample data
   - Build MockTransactionData service
   - Implement TransactionRowComponent
   - Create Cash view template

2. Review and iterate:
   - Get feedback on mock data realism
   - Validate UI patterns match project standards
   - Adjust component APIs as needed

3. Proceed through phases sequentially, with review checkpoints after each.

---

## ARCHITECT RECOMMENDATIONS

### ✅ Approved Architectural Decisions:
1. **Component Namespace**: `Transactions::` module prevents global namespace pollution
2. **Config Location**: YAML in `config/` matches project conventions
3. **Route Structure**: Clean URLs without "mock" prefix enables seamless live data transition
4. **Provider Pattern**: `*DataProvider` suffix aligns with `HoldingsGridDataProvider`
5. **DaisyUI Components**: Strict adherence to business theme ensures consistency
6. **Turbo Frames**: Future-proof for live data filtering/sorting without page reloads

### 🚨 Critical Implementation Notes:

#### Mock Data Realism
- Use diverse transaction types (groceries, utilities, subscriptions, large purchases)
- Include realistic merchant names from Transaction model's merchant lookup
- Span 6+ months to test monthly grouping
- Mix pending and posted transactions
- Include edge cases: $0.00 transactions, refunds (negative → positive), foreign currency

#### Component API Design
```ruby
# GOOD: Explicit params, nullable for flexibility
Transactions::GridComponent.new(
  transactions:, 
  total_count:, 
  page:, 
  per_page:, 
  sort:, 
  dir:,
  type_filter: nil,
  search_term: nil
)

# BAD: Implicit behavior, hard to test
Transactions::GridComponent.new(transactions:)
```

#### Migration Path to Live Data
Add controller feature flag for easy switching:
```ruby
class TransactionsController < ApplicationController
  USE_MOCK_DATA = ENV.fetch('TRANSACTIONS_USE_MOCK_DATA', 'true') == 'true'
  
  def regular
    @transactions = if USE_MOCK_DATA
      MockTransactionDataProvider.cash
    else
      Transaction.where(type: 'RegularTransaction')
                 .includes(:account)
                 .order(date: :desc)
                 .page(params[:page])
                 .per(params[:per_page] || 25)
    end
  end
end
```

### 📊 Success Metrics (Quantified)

**Code Quality**:
- ✅ 100% component test coverage (unit specs)
- ✅ Zero Rubocop violations in new files
- ✅ All components render in < 50ms (ViewComponent benchmark)

**UI/UX Quality**:
- ✅ Lighthouse accessibility score > 90
- ✅ Mobile responsive tested on 3 viewport sizes (375px, 768px, 1440px)
- ✅ All DaisyUI components use `data-theme="business"`

**Documentation**:
- ✅ Each component has YARD doc comments
- ✅ YAML files have header comments explaining structure
- ✅ README.md section added: "Transaction Views - Mock Data Setup"

### 🔮 Future Considerations (Post-Epic-6)

#### Phase 6: Live Data Integration (Separate Epic)
- Replace MockTransactionDataProvider with ActiveRecord queries
- Add real pagination via Kaminari/Pagy
- Implement server-side filtering and sorting
- Transaction detail modal/sidebar (click row → drawer opens)

#### Phase 7: Advanced Features (Separate Epic)
- Recurring transaction detection visualization
- Category spending trends (Chart.js integration)
- Export to CSV functionality
- Transaction search with Postgres full-text search
- Split/merge transaction UI for manual corrections

#### Performance Optimization
- Once live: Add database indexes on `transactions(date, type, account_id)`
- Implement fragment caching for monthly groups
- Use counter cache for account transaction counts

#### Analytics Integration
- Track which transaction views are most used (Ahoy/Plausible)
- Heatmap which columns users click most
- Identify if users prefer monthly vs list view

---

## ARCHITECTURAL APPROVAL CHECKLIST

Before implementation begins, confirm:
- [x] YAML location in `config/` not `lib/`
- [x] Component namespace `Transactions::`
- [x] No "mock" in route URLs
- [x] Provider pattern with caching
- [x] STI type alignment with routes documented
- [x] Turbo Frame integration planned
- [x] DaisyUI business theme enforced
- [x] Mobile-first responsive design
- [x] Test coverage requirements clear
- [x] Migration path to live data specified

---

*This REVISED plan aligns with Epic-6 goals while ensuring architectural consistency with existing patterns (HoldingsGrid, NetWorth components), scalability for future live data integration, and maintainability through clear component boundaries and comprehensive testing.*