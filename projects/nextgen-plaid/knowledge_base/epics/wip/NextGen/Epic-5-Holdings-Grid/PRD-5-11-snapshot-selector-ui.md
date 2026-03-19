# PRD 5-11: Holdings Grid – Snapshot Selector & Historical View Mode

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Add UI controls to the holdings grid to select and display holdings as of a specific historical snapshot date (or latest live data), integrating with the data provider to load snapshot data instead of live holdings when selected.

## Requirements

### Functional
- **Dropdown Selector** in grid header (below account filter, above tabs):
  - Label: "View As Of:"
  - Options:
    - "Latest (live)" — default, shows current holdings
    - List of recent snapshots: "Daily 2026-02-04" (sorted descending by created_at)
  - Limit: show last 50 snapshots + "View all snapshots..." link to management page (PRD 5-13)
  - If no snapshots: show only "Latest (live)" with tooltip "No snapshots yet"
- **On Selection**:
  - Pass `snapshot_id` param to HoldingsController
  - DataProvider loads from snapshot JSON instead of live Holdings table
  - Preserve current filters (account_filter, asset_class, search, sort)
  - Reset to page 1
- **Historical View Indicator**:
  - When snapshot selected: show badge/label "Historical view as of [date/time]" above table
  - DaisyUI info alert (light blue) with timestamp
  - Include "Switch to live" link/button to quickly return to :live mode
- **Default**: "Latest (live)" selected on first visit
- **URL Param**: `?snapshot_id=123` for bookmarkable historical views

### Non-Functional
- Responsive dropdown (DaisyUI select, mobile-friendly)
- Use Turbo/Hotwire for seamless reload without full page refresh
- Handle no snapshots available gracefully (disable selector or show message)
- ViewComponent for selector and historical badge

## Architectural Context
Update HoldingsController to accept `snapshot_id` param and pass to DataProvider. ViewComponent for snapshot selector dropdown. DataProvider already handles :live vs snapshot_id logic (JSON parsing + filtering). Hotwire Turbo Frame wraps grid for smooth updates.

## Selector ViewComponent

```ruby
# app/components/snapshot_selector_component.rb
class SnapshotSelectorComponent < ViewComponent::Base
  def initialize(user:, selected_snapshot_id: nil)
    @user = user
    @selected_snapshot_id = selected_snapshot_id || :live
  end

  def snapshots
    @snapshots ||= HoldingsSnapshot
      .by_user(@user.id)
      .user_level
      .recent_first
      .limit(50)
  end

  def live_selected?
    @selected_snapshot_id == :live || @selected_snapshot_id.nil?
  end
end
```

## Selector View Template

```erb
<!-- app/components/snapshot_selector_component.html.erb -->
<div class="form-control">
  <label class="label">
    <span class="label-text font-semibold">View As Of:</span>
  </label>
  <select
    name="snapshot_id"
    class="select select-bordered w-full max-w-xs"
    data-action="change->holdings#changeSnapshot"
  >
    <option value="live" <%= 'selected' if live_selected? %>>
      📊 Latest (live)
    </option>

    <% if snapshots.any? %>
      <optgroup label="Recent Snapshots">
        <% snapshots.each do |snapshot| %>
          <option
            value="<%= snapshot.id %>"
            <%= 'selected' if @selected_snapshot_id == snapshot.id %>
          >
            📸 <%= snapshot.name %> (<%= time_ago_in_words(snapshot.created_at) %> ago)
          </option>
        <% end %>
      </optgroup>

      <option disabled>────────────</option>
      <option value="view_all">View all snapshots...</option>
    <% else %>
      <option disabled>No snapshots yet</option>
    <% end %>
  </select>
</div>

<% unless live_selected? %>
  <div class="alert alert-info mt-4">
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
    <span>
      Historical view as of <strong><%= selected_snapshot.name %></strong>
      (<%= selected_snapshot.created_at.strftime('%B %d, %Y at %l:%M %p') %>)
    </span>
    <div>
      <%= link_to "Switch to live", portfolio_holdings_path, class: "btn btn-sm btn-outline" %>
    </div>
  </div>
<% end %>
```

## Controller Changes

```ruby
# app/controllers/holdings_controller.rb
def index
  @snapshot_id = params[:snapshot_id]&.to_sym == :live ? :live : params[:snapshot_id]&.to_i

  @data_provider = HoldingsGridDataProvider.new(
    user_id: current_user.id,
    snapshot_id: @snapshot_id || :live,
    account_filter_id: params[:account_filter_id],
    asset_class: params[:asset_class],
    search_term: params[:search],
    sort_column: params[:sort],
    sort_direction: params[:dir],
    page: params[:page] || 1,
    per_page: params[:per_page] || 50
  )

  @holdings = @data_provider.holdings
  @totals = @data_provider.totals
  @total_count = @data_provider.total_count
end
```

## Acceptance Criteria
- Dropdown lists recent snapshots + "Latest (live)"
- Selecting a snapshot reloads grid with matching historical data
- Historical view badge appears when snapshot selected
- "Switch to live" link returns to current holdings
- Filters and sort persist across snapshot changes
- Live mode (default) shows current holdings correctly
- Empty snapshot list shows graceful message
- "View all snapshots" navigates to management page
- URL params allow bookmarking specific snapshot view
- Turbo/Hotwire provides smooth transitions (no full page reload)

## Test Cases
- **Controller**:
  - snapshot_id param → correct data provider call
  - No snapshot_id → defaults to :live
  - Invalid snapshot_id → graceful error or redirect
- **ViewComponent**:
  - Selector renders options correctly
  - Active snapshot highlighted in dropdown
  - Live selected by default
  - Historical badge shows when snapshot selected
- **Capybara**:
  - Select past date → verify table reflects snapshot data
  - Verify totals match snapshot (not live)
  - Click "Switch to live" → returns to current holdings
  - Navigate with URL param `?snapshot_id=123` → loads correct snapshot
  - Apply filter while in snapshot mode → filter applies to snapshot data
- **Edge**:
  - No snapshots created → dropdown shows only "Latest (live)"
  - Switch back to live → verify live data loads
  - Snapshot with missing securities → handled gracefully
  - >50 snapshots → only 50 shown in dropdown

## Manual Testing Steps
1. Load holdings grid → verify "Latest (live)" selected
2. Verify dropdown shows recent snapshots (if any exist)
3. Select "Daily 2026-01-28" → verify:
   - Grid reloads with historical data
   - Historical badge appears with timestamp
   - Totals reflect snapshot values (not current)
4. Apply account filter while in snapshot → verify filter works
5. Sort by value → verify sort applies to snapshot data
6. Click "Switch to live" → verify returns to current holdings
7. Navigate to `/portfolio/holdings?snapshot_id=123` → verify loads snapshot
8. Click "View all snapshots..." → navigates to management page
9. Test with no snapshots: verify dropdown shows appropriate message
10. Mobile: verify dropdown responsive, badge stacks correctly

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-11-snapshot-selector-ui`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-02 (Data provider handles snapshot loading)
- PRD 5-03 (Core table structure)
- PRD 5-08 (HoldingsSnapshot model)
- PRD 5-09 (Snapshots exist to select)

## Blocked By
- PRD 5-09 must be complete (snapshots must exist)

## Blocks
- PRD 5-12 (Comparison mode builds on snapshot selector)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-08: Holdings Snapshots Model](./PRD-5-08-holdings-snapshots-model.md)
- [PRD 5-09: Snapshot Creation](./PRD-5-09-snapshot-creation-service.md)
- [Feedback V2 - Snapshot Selector](./Epic-5-Holding-Grid-feedback-V2.md#prd-11-snapshot-selector)
