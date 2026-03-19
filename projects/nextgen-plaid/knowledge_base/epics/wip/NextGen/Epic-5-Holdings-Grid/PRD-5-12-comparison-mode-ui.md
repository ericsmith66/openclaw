# PRD 5-12: Holdings Grid – Comparison Mode UI & Visual Diffs

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Add a "Compare to" selector in the grid header that triggers comparison mode, displaying period return %, value deltas, and visual highlighting (added/removed/changed rows) using data from the HoldingsSnapshotComparator service.

## Requirements

### Functional
- **Secondary Dropdown**: "Compare to" (appears below snapshot selector)
  - Label: "Compare to:"
  - Options:
    - "None" (default) — single view, no comparison
    - "Current (live)" — compare snapshot to latest holdings
    - List of snapshot dates (exclude currently selected snapshot)
  - Only enabled when a snapshot is selected (disabled in live mode with tooltip: "Select a snapshot first")
- **When Comparison Active**:
  - Call HoldingsSnapshotComparator with start (selected snapshot) and end (compare_to)
  - Add comparison columns to table:
    - Period Return (%)
    - Period Delta Value ($)
  - Apply row visual highlighting:
    - **Added** (green tint): `bg-green-50 border-l-4 border-green-500`
    - **Removed** (red tint + strikethrough): `bg-red-50 border-l-4 border-red-500 opacity-60`
    - **Changed** (amber/yellow highlight on changed cells): `bg-amber-50`
  - Summary section adds:
    - "Period Return: +12.5%" (green/red)
    - "Period Delta: +$25,000" (green/red)
  - Show comparison info badge: "Comparing [Start Date] → [End Date]"
- **Toggle to Exit Comparison**:
  - "Clear comparison" button or select "None" in dropdown
  - Returns to single snapshot view
- **Comparison works with filters**: Account/asset filters apply to both snapshots

### Non-Functional
- Real-time comparison computation for v1 (monitor performance)
- Cache comparison results for 30 minutes if >500 holdings
  - Cache key: `snapshot_comparison:v1:#{start_id}:#{end_id}:#{filter_hash}`
- Clear visual distinction between added/removed/changed
- Responsive: extra columns scroll horizontally on mobile if needed
- DaisyUI color utilities for consistent styling

## Architectural Context
Extend HoldingsController to handle `compare_to` param. Call HoldingsSnapshotComparator service, merge diff data into view. Use ViewComponent for:
- Comparison selector dropdown
- Diff columns (Period Return, Delta Value)
- Row highlighting classes
Use Stimulus controller for interactive comparison toggle.

## Visual Styling

```css
/* Added rows */
.holding-row-added {
  @apply bg-green-50 border-l-4 border-green-500;
}

/* Removed rows */
.holding-row-removed {
  @apply bg-red-50 border-l-4 border-red-500 opacity-60 line-through;
}

/* Changed cells */
.holding-cell-changed {
  @apply bg-amber-50 font-semibold;
}

/* Period return column */
.period-return-positive {
  @apply text-green-600 font-bold;
}

.period-return-negative {
  @apply text-red-600 font-bold;
}
```

## Controller Changes

```ruby
# app/controllers/holdings_controller.rb
def index
  @snapshot_id = parse_snapshot_id(params[:snapshot_id])
  @compare_to = parse_snapshot_id(params[:compare_to])

  @data_provider = HoldingsGridDataProvider.new(
    user_id: current_user.id,
    snapshot_id: @snapshot_id || :live,
    # ... other params
  )

  if @compare_to && @snapshot_id != :live
    @comparison = HoldingsSnapshotComparator.new(
      start_snapshot_id: @snapshot_id,
      end_snapshot_id: @compare_to,
      user_id: current_user.id
    ).call
  end

  # ... rest of index action
end
```

## Comparison Selector ViewComponent

```ruby
# app/components/comparison_selector_component.rb
class ComparisonSelectorComponent < ViewComponent::Base
  def initialize(user:, selected_snapshot_id:, compare_to: nil)
    @user = user
    @selected_snapshot_id = selected_snapshot_id
    @compare_to = compare_to
  end

  def available_snapshots
    scope = HoldingsSnapshot.by_user(@user.id).user_level.recent_first.limit(50)

    # Exclude currently selected snapshot
    scope = scope.where.not(id: @selected_snapshot_id) if @selected_snapshot_id.present? && @selected_snapshot_id != :live

    scope
  end

  def comparison_enabled?
    @selected_snapshot_id.present? && @selected_snapshot_id != :live
  end
end
```

## Comparison Columns in Table

```erb
<!-- Add these columns when @comparison present -->
<% if @comparison %>
  <th class="sortable">
    Period Return (%)
    <%= sort_indicator(:period_return_pct) %>
  </th>
  <th class="sortable">
    Period Delta ($)
    <%= sort_indicator(:period_delta_value) %>
  </th>
<% end %>

<!-- In row loop -->
<% @holdings.each do |holding| %>
  <% delta = @comparison&.dig(:securities, holding.security_id) %>
  <tr class="<%= row_comparison_class(delta) %>">
    <!-- ... standard columns ... -->

    <% if @comparison %>
      <td class="<%= period_return_class(delta[:return_pct]) %>">
        <%= format_percentage(delta[:return_pct]) %>
      </td>
      <td class="<%= period_delta_class(delta[:delta_value]) %>">
        <%= format_currency(delta[:delta_value]) %>
      </td>
    <% end %>
  </tr>
<% end %>
```

## Helper Methods

```ruby
# app/helpers/holdings_helper.rb
def row_comparison_class(delta)
  return '' unless delta

  case delta[:status]
  when :added then 'holding-row-added'
  when :removed then 'holding-row-removed'
  when :changed then ''
  else ''
  end
end

def period_return_class(return_pct)
  return '' unless return_pct

  return_pct > 0 ? 'period-return-positive' : 'period-return-negative'
end

def period_delta_class(delta_value)
  return '' unless delta_value

  delta_value > 0 ? 'text-green-600' : 'text-red-600'
end
```

## Acceptance Criteria
- Comparison mode activates when "Compare to" snapshot selected
- Comparison columns (Period Return %, Period Delta $) appear
- Rows highlight correctly:
  - Green tint for added securities
  - Red tint + strikethrough for removed securities
  - Amber cells for changed values
- Summary cards show period metrics (return %, delta $)
- "Clear comparison" button returns to single view
- Comparison disabled in live mode (with helpful tooltip)
- Works with account/asset filters
- URL params preserve comparison state for bookmarking
- Performance acceptable: <2s for comparison computation

## Test Cases
- **Service Integration**:
  - Mock HoldingsSnapshotComparator output
  - Assert diff columns populated with correct values
- **View**:
  - Correct CSS classes applied to rows/cells
  - Comparison columns render when active
  - Dropdown disabled in live mode
- **Capybara**:
  - Select snapshot → select compare_to → verify highlights & extra columns
  - Verify summary shows period return and delta
  - Click "Clear comparison" → columns disappear
  - Apply filter during comparison → verify both datasets filtered
- **Edge**:
  - No changes between snapshots (no highlights)
  - Only added positions (all green)
  - Only removed positions (all red)
  - Snapshot vs live comparison
  - >500 holdings → verify caching kicks in

## Manual Testing Steps
1. Load holdings grid, select "Daily 2026-01-28" snapshot
2. Verify "Compare to" dropdown enabled
3. Select "Current (live)" from compare dropdown
4. Verify:
   - Two new columns appear: Period Return (%), Period Delta ($)
   - Added securities have green tint
   - Removed securities have red tint + strikethrough
   - Changed securities have normal row, but changed cells highlighted amber
   - Summary shows "Period Return: +8.5%" in green
   - Summary shows "Period Delta: +$18,000" in green
5. Sort by Period Return % descending → verify order
6. Apply asset class filter "Stocks & ETFs" → verify comparison updates
7. Click "Clear comparison" → verify returns to single snapshot view
8. Try enabling comparison while in live mode → verify disabled with tooltip
9. Bookmark URL with comparison params → reload → verify state preserved
10. Mobile: verify comparison columns scroll horizontally
11. Test with 500+ holdings → verify completion time <2s

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-12-comparison-mode-ui`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-03 (Core table structure)
- PRD 5-10 (Snapshot comparison service)
- PRD 5-11 (Snapshot selector UI)

## Blocked By
- PRD 5-11 must be complete

## Blocks
- None (final snapshot feature)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-10: Snapshot Comparison Service](./PRD-5-10-snapshot-comparison-service.md)
- [PRD 5-11: Snapshot Selector UI](./PRD-5-11-snapshot-selector-ui.md)
- [Feedback V2 - Comparison Mode](./Epic-5-Holding-Grid-feedback-V2.md#prd-12-comparison-mode)
