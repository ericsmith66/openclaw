# PRD 5-14: Holdings Grid – Export & Reporting

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Add CSV export functionality for the current filtered holdings dataset, including all columns and full totals. For large datasets (>500 holdings), use async background job with email delivery.

## Requirements

### Functional
- **Export Button/Link** in grid header or footer:
  - Label: "Export CSV" (with download icon)
  - Position: top-right of grid, next to other controls
- **Synchronous Path** (count ≤ 500):
  - Downloads file immediately with full filtered set (not just visible page)
  - Columns match grid:
    - Symbol, Description, Asset Class
    - Price, Quantity, Value, Cost Basis
    - Unrealized G/L ($), Unrealized G/L (%)
    - Enrichment Updated, % of Portfolio
  - Include totals row at bottom
  - Filename: `holdings-export-{user_id}-{date}.csv` (e.g., `holdings-export-1-2026-02-04.csv`)
- **Asynchronous Path** (count > 500):
  - Show toast: "Export started. You'll receive an email with download link."
  - Enqueue ExportHoldingsJob
  - Job generates CSV, stores in ActiveStorage/S3 with 24h expiration
  - Email user with signed download URL
  - Show recent exports on snapshots management page (optional)
- **Comparison Mode**:
  - If comparison active: include Period Return (%) and Period Delta ($) columns
  - Otherwise: standard columns only
- **Snapshot Mode**:
  - If viewing snapshot: include snapshot name/date in filename and header row
  - Otherwise: mark as "live" export
- **Works with All Filters**:
  - Account filter, asset class, search, sort all apply to export

### Non-Functional
- Use Ruby CSV library (require 'csv')
- Server-side generation (avoid browser memory issues)
- Send as attachment via `send_data` (sync) or ActiveStorage URL (async)
- Async job: Solid Queue (ActiveJob) with 3 retries
- Email template: professional, includes download button with expiration notice

## Architectural Context
Add `#export` action in HoldingsController. Use HoldingsGridDataProvider to fetch full dataset (no pagination). Generate CSV in controller (sync) or job (async). ActiveStorage for temporary file storage. ActionMailer for email delivery.

## Routes

```ruby
# config/routes.rb
namespace :portfolio do
  resources :holdings, only: [:index] do
    collection do
      get :export
    end
  end
end
```

## Controller Implementation

```ruby
# app/controllers/portfolio/holdings_controller.rb
def export
  data_provider = build_data_provider(per_page: 'all')
  total_count = data_provider.total_count

  if total_count > 500
    # Async path
    ExportHoldingsJob.perform_later(
      user_id: current_user.id,
      params: export_params
    )

    flash[:notice] = "Export started. You'll receive an email with download link shortly."
    redirect_to portfolio_holdings_path
  else
    # Sync path
    csv_data = generate_csv(data_provider)

    send_data csv_data,
              type: 'text/csv; charset=utf-8; header=present',
              disposition: "attachment; filename=#{export_filename}"
  end
end

private

def generate_csv(data_provider)
  require 'csv'

  CSV.generate(headers: true) do |csv|
    # Header row
    csv << csv_headers(data_provider)

    # Data rows
    data_provider.holdings.each do |holding|
      csv << csv_row(holding, data_provider)
    end

    # Totals row
    csv << totals_row(data_provider)
  end
end

def csv_headers(data_provider)
  headers = [
    'Symbol',
    'Description',
    'Asset Class',
    'Price',
    'Quantity',
    'Value',
    'Cost Basis',
    'Unrealized G/L ($)',
    'Unrealized G/L (%)',
    'Enrichment Updated',
    '% of Portfolio'
  ]

  if data_provider.comparison_mode?
    headers += ['Period Return (%)', 'Period Delta ($)']
  end

  headers
end

def csv_row(holding, data_provider)
  row = [
    holding.ticker_symbol,
    holding.name,
    holding.asset_class,
    holding.price,
    holding.quantity,
    holding.market_value,
    holding.cost_basis,
    holding.unrealized_gain_loss,
    holding.unrealized_gain_loss_pct,
    holding.enriched_at&.strftime('%Y-%m-%d %H:%M'),
    holding.portfolio_percentage
  ]

  if data_provider.comparison_mode?
    delta = data_provider.comparison_data[holding.security_id]
    row += [delta[:return_pct], delta[:delta_value]]
  end

  row
end

def totals_row(data_provider)
  totals = data_provider.totals

  row = [
    'TOTAL',
    '', '', '', '',
    totals[:portfolio_value],
    totals[:total_cost_basis],
    totals[:total_gl_dollars],
    totals[:total_gl_pct],
    '', ''
  ]

  if data_provider.comparison_mode?
    row += [totals[:period_return_pct], totals[:period_delta_value]]
  end

  row
end

def export_filename
  snapshot_suffix = @snapshot_id.present? ? "-snapshot-#{@snapshot_id}" : "-live"
  "holdings-export-#{current_user.id}#{snapshot_suffix}-#{Date.today}.csv"
end

def export_params
  params.permit(:snapshot_id, :compare_to, :account_filter_id, :asset_class, :search, :sort, :dir)
end
```

## Async Export Job

```ruby
# app/jobs/export_holdings_job.rb
class ExportHoldingsJob < ApplicationJob
  queue_as :default

  # Solid Queue uses ActiveJob retry semantics.
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(user_id:, params:)
    user = User.find(user_id)

    data_provider = HoldingsGridDataProvider.new(
      user_id: user_id,
      snapshot_id: params[:snapshot_id],
      compare_to: params[:compare_to],
      account_filter_id: params[:account_filter_id],
      asset_class: params[:asset_class],
      search_term: params[:search],
      sort_column: params[:sort],
      sort_direction: params[:dir],
      per_page: 'all'
    )

    csv_data = HoldingsExportService.new(data_provider).generate_csv

    # Store in ActiveStorage with 24h expiration
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(csv_data),
      filename: export_filename(user, params),
      content_type: 'text/csv'
    )

    # Generate signed URL (expires in 24h)
    download_url = Rails.application.routes.url_helpers.rails_blob_url(blob, disposition: 'attachment')

    # Send email
    HoldingsExportMailer.export_ready(user, download_url).deliver_later

    # Schedule blob deletion after 24h
    DeleteExportBlobJob.set(wait: 24.hours).perform_later(blob.id)
  end

  private

  def export_filename(user, params)
    snapshot_suffix = params[:snapshot_id].present? ? "-snapshot-#{params[:snapshot_id]}" : "-live"
    "holdings-export-#{user.id}#{snapshot_suffix}-#{Date.today}.csv"
  end
end
```

## Mailer

```ruby
# app/mailers/holdings_export_mailer.rb
class HoldingsExportMailer < ApplicationMailer
  def export_ready(user, download_url)
    @user = user
    @download_url = download_url

    mail(
      to: user.email,
      subject: "Your holdings export is ready"
    )
  end
end
```

## Email Template

```erb
<!-- app/views/holdings_export_mailer/export_ready.html.erb -->
<h2>Your Holdings Export is Ready</h2>

<p>Hi <%= @user.first_name %>,</p>

<p>Your holdings export has been generated and is ready for download.</p>

<p style="margin: 20px 0;">
  <%= link_to "Download CSV Export",
              @download_url,
              class: "button",
              style: "background-color: #6366F1; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;" %>
</p>

<p><strong>Note:</strong> This download link will expire in 24 hours.</p>

<p>If you have any questions, please contact support.</p>

<p>Best regards,<br>The Team</p>
```

## Acceptance Criteria
- Export button triggers download of full filtered dataset
- CSV contains all visible columns + totals row
- Columns and formatting match grid display
- Snapshot mode exports historical data
- Comparison mode includes delta columns
- Filename includes user ID, date, snapshot indicator
- Large exports (>500 rows) use async path
- Async: email sent with signed download URL
- Download URL expires after 24h
- File cleanup job removes blob after 24h
- All filters (account, asset, search, sort) apply to export
- Empty dataset produces CSV with headers only

## Test Cases
- **Controller**:
  - Export action sends correct CSV data (sync path)
  - Count > 500 → enqueues job, redirects with notice
- **CSV Generation**:
  - Headers match expected columns
  - Rows contain correct data
  - Totals row calculates correctly
  - Comparison columns included when active
- **Job**:
  - Generates CSV correctly
  - Creates ActiveStorage blob
  - Sends email with download URL
  - Schedules cleanup job
- **Integration**:
  - Apply filter → export → verify CSV matches filtered view
  - Snapshot mode → export → verify data from snapshot
  - Comparison mode → export → verify delta columns present
- **Edge**:
  - Empty dataset (headers only)
  - Very large set (1000+ rows, async path)
  - Special characters in holdings (escaped correctly)
  - Export timeout (Heroku 30s limit) → uses async

## Manual Testing Steps
1. Load holdings grid with 50 holdings
2. Apply account filter "Trust Accounts"
3. Click "Export CSV" button
4. Verify immediate download
5. Open CSV file → verify:
   - Headers match grid columns
   - 50 data rows (filtered set)
   - Totals row at bottom with correct sums
   - Filename includes date and "-live"
6. Load snapshot view, click export
7. Verify filename includes "-snapshot-123"
8. Activate comparison mode, export
9. Verify CSV includes Period Return (%) and Period Delta ($) columns
10. Test async path: create user with 600 holdings
11. Click export → verify toast "Export started..."
12. Check email → verify received within 2 minutes
13. Click download link → verify CSV downloads
14. Wait 24h → verify link expired and blob deleted
15. Test with empty filter (zero results) → verify CSV with headers only

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-14-holdings-export-csv`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-02 (Data provider service)
- PRD 5-03 (Core table structure defines columns)

## Blocked By
- PRD 5-03 must be complete

## Blocks
- None (standalone export feature)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-02: Data Provider Service](./PRD-5-02-data-provider-service.md)
- [Feedback V2 - Export](./Epic-5-Holding-Grid-feedback-V2.md#prd-14-export)
