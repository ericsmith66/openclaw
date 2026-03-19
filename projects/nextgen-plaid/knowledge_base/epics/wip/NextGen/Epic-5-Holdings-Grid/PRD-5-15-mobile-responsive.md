# PRD 5-15: Holdings Grid – Mobile Responsive View

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Make the holdings grid usable on mobile devices (phones and tablets) with a simplified, responsive layout while preserving core functionality. Full feature parity for v1, with optimizations for touch interactions.

## Requirements

### Functional
- **Horizontal Scroll** on table for wide columns
  - Table wrapped in scrollable container with touch-friendly scroll
  - Sticky first column (Symbol) remains visible while scrolling
- **Summary Cards**: stack vertically on small screens (sm: breakpoint)
  - 1 column on mobile (<640px)
  - 2 columns on tablet (640-1024px)
  - 3+ columns on desktop (>1024px)
- **Filter Controls**: collapsible into drawer or accordion
  - Mobile: filters collapse into "Filters" button → opens drawer
  - Drawer contains: saved account filter, asset class tabs, snapshot selector, comparison selector
  - Apply/Clear buttons in drawer
- **Table Interactions**:
  - Expandable rows work with touch (tap chevron to expand)
  - Sort headers work with tap
  - Pagination controls remain accessible
  - Per-page selector dropdown works on mobile
- **Touch-Friendly Elements**:
  - Buttons minimum 44×44px tap target (iOS HIG guidelines)
  - Adequate spacing between interactive elements
  - Dropdowns/selects use native mobile UI where possible
- **Navigation**:
  - Back button for security detail page prominent and accessible
  - Breadcrumbs collapse or hide on very small screens

### Non-Functional
- **Tailwind Responsive Classes**: sm:, md:, lg:, xl: breakpoints
- **DaisyUI Mobile Components**: drawer, collapse, modal work well on touch
- **Maintain Readability**:
  - Font sizes: minimum 14px for body text
  - Padding: comfortable touch targets
  - No tiny text or cramped layouts
- **Performance**: no mobile-specific JS bundles needed, same codebase
- **Testing**: test at breakpoints 375px, 768px, 1024px, 1440px

## Architectural Context
Update grid view with responsive Tailwind/DaisyUI utilities. No new controller logic — purely view-level CSS changes. Optional: mobile-specific ViewComponent variants for complex components. Use DaisyUI drawer component for filter collapse. Stimulus controllers for drawer open/close interactions.

## Responsive Breakpoints

```css
/* Tailwind default breakpoints */
sm: 640px   /* tablet portrait */
md: 768px   /* tablet landscape */
lg: 1024px  /* desktop */
xl: 1280px  /* large desktop */
```

## Key Responsive Patterns

### Summary Cards Stack

```erb
<!-- Desktop: 4 columns, Tablet: 2 columns, Mobile: 1 column -->
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
  <%= render @summary_cards %>
</div>
```

### Table Horizontal Scroll

```erb
<div class="overflow-x-auto -mx-4 sm:mx-0">
  <table class="table table-zebra w-full">
    <!-- Sticky first column on mobile -->
    <thead>
      <tr>
        <th class="sticky left-0 bg-base-100 z-10">Symbol</th>
        <th>Description</th>
        <!-- ... other columns -->
      </tr>
    </thead>
    <tbody>
      <% @holdings.each do |holding| %>
        <tr>
          <td class="sticky left-0 bg-base-100 font-bold">
            <%= holding.ticker_symbol %>
          </td>
          <td><%= holding.name %></td>
          <!-- ... -->
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

### Filter Drawer (Mobile)

```erb
<!-- Mobile: filters in drawer -->
<div class="lg:hidden">
  <label for="filters-drawer" class="btn btn-primary drawer-button">
    <svg class="w-5 h-5 mr-2"><!-- filter icon --></svg>
    Filters
  </label>
</div>

<div class="drawer drawer-end">
  <input id="filters-drawer" type="checkbox" class="drawer-toggle" />

  <div class="drawer-side z-50">
    <label for="filters-drawer" class="drawer-overlay"></label>

    <div class="menu p-4 w-80 bg-base-100 h-full">
      <h2 class="text-xl font-bold mb-4">Filters</h2>

      <!-- Account Filter Selector -->
      <%= render SavedAccountFilterSelectorComponent.new(user: current_user) %>

      <!-- Asset Class Tabs (vertical on mobile) -->
      <div class="tabs tabs-boxed tabs-vertical mt-4">
        <%= render AssetClassTabsComponent.new(selected: @asset_class) %>
      </div>

      <!-- Snapshot Selector -->
      <%= render SnapshotSelectorComponent.new(user: current_user, selected_snapshot_id: @snapshot_id) %>

      <!-- Comparison Selector -->
      <%= render ComparisonSelectorComponent.new(user: current_user, selected_snapshot_id: @snapshot_id, compare_to: @compare_to) %>

      <div class="mt-6 flex gap-2">
        <button class="btn btn-primary flex-1" data-action="click->filters#apply">Apply</button>
        <button class="btn btn-ghost flex-1" data-action="click->filters#clear">Clear</button>
      </div>
    </div>
  </div>
</div>

<!-- Desktop: filters inline -->
<div class="hidden lg:block">
  <!-- Regular filter UI as before -->
</div>
```

### Pagination Mobile

```erb
<div class="flex flex-col sm:flex-row justify-between items-center gap-4 mt-6">
  <!-- Showing X-Y of Z -->
  <div class="text-sm text-base-content/70">
    Showing <%= @page_start %>–<%= @page_end %> of <%= @total_count %> holdings
  </div>

  <!-- Pagination controls (stack on mobile) -->
  <div class="flex flex-col sm:flex-row items-center gap-4">
    <!-- Per-page selector -->
    <select name="per_page" class="select select-bordered select-sm w-full sm:w-auto">
      <%= options_for_select([25, 50, 100, 500, 'All'], @per_page) %>
    </select>

    <!-- Page buttons -->
    <div class="btn-group">
      <%= paginate @holdings, theme: 'daisy' %>
    </div>
  </div>
</div>
```

## Touch Target Sizing

```css
/* Ensure minimum 44×44px tap targets */
.btn-sm {
  @apply min-h-[44px] min-w-[44px];
}

.table th, .table td {
  @apply py-3 px-2 sm:px-4;  /* More padding on desktop */
}
```

## Acceptance Criteria
- Grid usable on mobile (tested at 375–768px widths)
- Horizontal scroll works smoothly on table
- Sticky first column (Symbol) remains visible while scrolling
- Summary cards stack vertically on mobile, 2-col on tablet
- Filters collapse into drawer on mobile (<1024px)
- All interactive elements (expand, sort, pagination) functional on touch
- Touch targets minimum 44×44px (iOS guidelines)
- Per-page selector dropdown works on mobile
- Security detail page responsive (sections stack, table scrolls)
- Snapshot/comparison selectors work in mobile drawer
- Font sizes readable (minimum 14px)
- No horizontal overflow (except intentional table scroll)

## Test Cases
- **View**:
  - Responsive classes applied correctly
  - Drawer opens/closes on mobile
  - Summary cards use correct grid cols
- **Capybara** (with viewport resize):
  - Set viewport to 375px → verify layout changes
  - Tap "Filters" button → drawer opens
  - Tap sort header → table sorts
  - Tap pagination → page changes
  - Horizontal scroll on table → verify works
- **Manual Device Testing**:
  - Test on real iPhone/Android (scroll, tap expand, change per-page)
  - Test on tablet (verify 2-col cards, inline filters if space)
  - Rotate device → verify layout adapts
- **Edge**:
  - Very small screen (320px iPhone SE)
  - Very large screen (1440px+ desktop)
  - Many columns → horizontal scroll required
  - Long security names → truncate with ellipsis

## Manual Testing Steps
1. **Desktop** (1440px):
   - Load holdings grid → verify 4-column summary cards
   - Verify filters inline (not drawer)
   - Verify table fits without scroll
2. **Tablet** (768px):
   - Resize browser to 768px
   - Verify summary cards: 2 columns
   - Verify filters: still inline or drawer depending on breakpoint
   - Verify table: horizontal scroll available
3. **Mobile** (375px):
   - Resize to 375px (iPhone SE)
   - Verify summary cards: 1 column, stacked
   - Verify "Filters" button appears
   - Tap "Filters" → drawer opens from right
   - Verify all filter controls in drawer
   - Tap "Apply" → drawer closes, grid updates
   - Verify table: horizontal scroll works smoothly
   - Verify sticky first column (Symbol) remains visible while scrolling
   - Tap chevron on multi-account row → expands correctly
   - Tap sort header → sorts
   - Tap pagination "Next" → page changes
   - Select "100" from per-page dropdown → updates
4. **Security Detail Page** (mobile):
   - Navigate to security detail on mobile
   - Verify sections stack vertically
   - Verify transactions table scrolls horizontally
   - Verify back button prominent and tappable
5. **Real Device** (if available):
   - Test on iPhone/Android
   - Verify touch interactions smooth (no need to zoom)
   - Verify dropdowns use native mobile UI
   - Verify no layout shift or jank

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-15-mobile-responsive`. Ask questions/plan in log. Commit green code only.

## Dependencies
- All previous PRDs (1-14) — this is polish/refinement on existing UI

## Blocked By
- PRD 5-03 (Core table)
- PRD 5-04 (Filters)
- PRD 5-11 (Snapshot selector)

## Blocks
- None (final polish PRD)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [Feedback V2 - Mobile](./Epic-5-Holding-Grid-feedback-V2.md#prd-15-mobile)
- [Tailwind Responsive Design](https://tailwindcss.com/docs/responsive-design)
- [DaisyUI Drawer Component](https://daisyui.com/components/drawer/)
