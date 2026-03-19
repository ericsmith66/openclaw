# PRD 5-13: Holdings Snapshots – Management UI

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Provide a simple interface for users to view, manually create, and delete their holdings snapshots.

## Requirements

### Functional
- **Route**: GET /portfolio/snapshots (nested under portfolio)
- **List Table**:
  - Columns:
    - Date/Time (formatted: "Feb 4, 2026 at 1:30 PM")
    - Name (editable inline or via modal)
    - Scope ("All Accounts" or "[Account Name]")
    - Type (badge: "Auto" / "Manual")
    - Holdings Count
    - Actions (View, Edit Name, Delete)
  - Sort: created_at descending (default)
  - Pagination: 25 per page (if many snapshots)
- **Create Button**: "Create Snapshot Now"
  - Modal or drawer: select scope (all accounts or specific account)
  - Optional: custom name input
  - Triggers CreateHoldingsSnapshotsJob with `force: true`
  - Shows success toast: "Snapshot created successfully"
  - Async: shows loading state while job processes
- **Delete Button** (per snapshot):
  - Confirmation modal: "Are you sure? This cannot be undone."
  - On confirm: destroys record
  - Shows success toast: "Snapshot deleted"
  - Removes row from table (Turbo Stream or reload)
- **Edit Name** (inline or modal):
  - Update snapshot.name
  - Save with validation
  - Shows success toast: "Snapshot renamed"
- **View Button**:
  - Navigates to holdings grid with `?snapshot_id=#{snapshot.id}`
  - Opens snapshot in grid view

### Non-Functional
- Scoped to current_user only (RLS enforced)
- Simple, professional DaisyUI table + buttons
- Success/error toasts for all actions (DaisyUI toast component)
- Responsive table (horizontal scroll on mobile)
- Uses Hotwire Turbo for smooth interactions
- No page reload on create/delete/edit (Turbo Streams)

## Architectural Context
SnapshotsController with actions:
- `index` — list user's snapshots
- `create` — trigger CreateHoldingsSnapshotsJob
- `update` — rename snapshot
- `destroy` — delete snapshot

Uses HoldingsSnapshot model. Solid Queue (ActiveJob) for async create. ViewComponents for table rows, create button/modal, delete confirmation modal.

## Routes

```ruby
# config/routes.rb
namespace :portfolio do
  resources :snapshots, only: [:index, :create, :update, :destroy] do
    member do
      get :view  # redirects to holdings grid with snapshot_id
    end
  end
end
```

## Controller Implementation

```ruby
# app/controllers/portfolio/snapshots_controller.rb
module Portfolio
  class SnapshotsController < ApplicationController
    before_action :set_snapshot, only: [:update, :destroy, :view]

    def index
      @snapshots = HoldingsSnapshot
        .by_user(current_user.id)
        .recent_first
        .page(params[:page])
        .per(25)
    end

    def create
      CreateHoldingsSnapshotsJob.perform_later(
        user_id: current_user.id,
        account_id: params[:account_id]&.to_i,
        name: params[:name],
        force: true
      )

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Snapshot creation started..." }
        format.html { redirect_to portfolio_snapshots_path, notice: "Snapshot creation started..." }
      end
    end

    def update
      if @snapshot.update(name: params[:name])
        respond_to do |format|
          format.turbo_stream { flash.now[:notice] = "Snapshot renamed successfully" }
          format.html { redirect_to portfolio_snapshots_path, notice: "Snapshot renamed" }
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @snapshot.destroy

      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Snapshot deleted" }
        format.html { redirect_to portfolio_snapshots_path, notice: "Snapshot deleted" }
      end
    end

    def view
      redirect_to portfolio_holdings_path(snapshot_id: @snapshot.id)
    end

    private

    def set_snapshot
      @snapshot = HoldingsSnapshot.by_user(current_user.id).find(params[:id])
    end
  end
end
```

## View Template Structure

```erb
<!-- app/views/portfolio/snapshots/index.html.erb -->
<div class="container mx-auto px-4 py-8">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold">Holdings Snapshots</h1>
    <%= button_to "Create Snapshot Now",
                  portfolio_snapshots_path,
                  method: :post,
                  class: "btn btn-primary",
                  data: { turbo_frame: "new_snapshot_modal" } %>
  </div>

  <% if @snapshots.any? %>
    <div class="overflow-x-auto">
      <table class="table table-zebra w-full">
        <thead>
          <tr>
            <th>Date/Time</th>
            <th>Name</th>
            <th>Scope</th>
            <th>Type</th>
            <th>Holdings</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= render @snapshots %>
        </tbody>
      </table>
    </div>

    <%= paginate @snapshots %>
  <% else %>
    <div class="alert alert-info">
      <p>No snapshots yet. Create your first snapshot to track portfolio changes over time.</p>
    </div>
  <% end %>
</div>
```

## Snapshot Row Component

```erb
<!-- app/views/portfolio/snapshots/_holdings_snapshot.html.erb -->
<tr id="<%= dom_id(holdings_snapshot) %>">
  <td>
    <%= holdings_snapshot.created_at.strftime('%b %d, %Y at %l:%M %p') %>
  </td>
  <td>
    <span class="font-semibold"><%= holdings_snapshot.name %></span>
  </td>
  <td>
    <% if holdings_snapshot.account_id %>
      <%= holdings_snapshot.account.name %> (...<%= holdings_snapshot.account.mask %>)
    <% else %>
      <span class="badge badge-primary">All Accounts</span>
    <% end %>
  </td>
  <td>
    <% if holdings_snapshot.name&.start_with?('Daily') %>
      <span class="badge badge-info">Auto</span>
    <% else %>
      <span class="badge badge-accent">Manual</span>
    <% end %>
  </td>
  <td>
    <%= holdings_snapshot.snapshot_data['holdings'].size %> positions
  </td>
  <td>
    <div class="flex gap-2">
      <%= link_to "View", view_portfolio_snapshot_path(holdings_snapshot), class: "btn btn-sm btn-outline" %>

      <%= button_to "Delete",
                    portfolio_snapshot_path(holdings_snapshot),
                    method: :delete,
                    form: { data: { turbo_confirm: "Are you sure? This cannot be undone." } },
                    class: "btn btn-sm btn-error btn-outline" %>
    </div>
  </td>
</tr>
```

## Create Snapshot Modal

```erb
<!-- app/views/portfolio/snapshots/_new_modal.html.erb -->
<dialog id="new_snapshot_modal" class="modal">
  <div class="modal-box">
    <h3 class="font-bold text-lg">Create New Snapshot</h3>

    <%= form_with url: portfolio_snapshots_path, method: :post, class: "py-4" do |f| %>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Scope</span>
        </label>
        <%= f.select :account_id,
                     options_for_select([['All Accounts', nil]] + current_user.accounts.pluck(:name, :id)),
                     {},
                     class: "select select-bordered w-full" %>
      </div>

      <div class="form-control mt-4">
        <label class="label">
          <span class="label-text">Custom Name (optional)</span>
        </label>
        <%= f.text_field :name,
                         placeholder: "Leave blank for auto-generated name",
                         class: "input input-bordered w-full" %>
      </div>

      <div class="modal-action">
        <button type="button" class="btn" onclick="new_snapshot_modal.close()">Cancel</button>
        <%= f.submit "Create Snapshot", class: "btn btn-primary" %>
      </div>
    <% end %>
  </div>
  <form method="dialog" class="modal-backdrop">
    <button>close</button>
  </form>
</dialog>
```

## Acceptance Criteria
- List shows all user's snapshots sorted by date descending
- Table displays: date, name, scope, type, holdings count
- "Create Snapshot Now" button opens modal
- Create modal allows selecting scope (all accounts or specific)
- Create triggers async job, shows success toast
- New snapshot appears in list (via Turbo Stream or reload)
- Delete button shows confirmation modal
- Delete removes snapshot and updates table
- Edit name (inline or modal) updates snapshot.name
- View button navigates to holdings grid with snapshot loaded
- Pagination works if >25 snapshots
- No access to other users' snapshots (RLS enforced)
- Responsive table (scrolls horizontally on mobile)

## Test Cases
- **Controller**:
  - CRUD actions work correctly
  - Authorization: only current_user's snapshots accessible
  - Create enqueues Solid Queue (ActiveJob) job
  - Destroy removes record
  - Update changes name
- **View**:
  - Table renders all columns correctly
  - Badges show auto/manual type
  - Scope shows "All Accounts" or account name
  - Actions buttons present
- **Capybara**:
  - Click "Create Snapshot" → modal opens
  - Fill form → submit → job enqueued, toast appears
  - Click "Delete" → confirmation modal → confirm → snapshot removed
  - Click "View" → redirects to holdings grid with snapshot_id
  - Edit name → verify update persists
- **Edge**:
  - No snapshots (empty state with helpful message)
  - Create fails (toast error message)
  - Delete last snapshot → shows empty state
  - Pagination with 50+ snapshots

## Manual Testing Steps
1. Navigate to /portfolio/snapshots
2. Verify list shows existing snapshots (if any)
3. Click "Create Snapshot Now" → modal opens
4. Select "All Accounts" scope, leave name blank → submit
5. Verify success toast: "Snapshot creation started..."
6. Wait for job to complete → refresh page → verify new snapshot in list
7. Verify snapshot shows:
   - Current date/time
   - Auto-generated name "Daily 2026-02-04"
   - "All Accounts" scope
   - "Auto" or "Manual" badge
   - Correct holdings count
8. Click "View" → verify navigates to holdings grid with snapshot loaded
9. Back to snapshots page → click "Delete" on a snapshot
10. Verify confirmation modal → click "Confirm"
11. Verify snapshot removed from list, success toast shown
12. Create snapshot with custom name → verify name persists
13. Test with >25 snapshots → verify pagination works
14. Mobile: verify table scrolls horizontally, buttons remain accessible

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-13-snapshot-management-ui`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-08 (HoldingsSnapshot model)
- PRD 5-09 (CreateHoldingsSnapshotsJob)

## Blocked By
- PRD 5-09 must be complete

## Blocks
- None (standalone management interface)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-08: Holdings Snapshots Model](./PRD-5-08-holdings-snapshots-model.md)
- [PRD 5-09: Snapshot Creation Service](./PRD-5-09-snapshot-creation-service.md)
