# Epic: Enrichment for Unenriched Holdings with Focus on Tax Treatment, Income Generation, and Maturity Tracking

## Epic Overview
This epic focuses on enriching unenriched holdings (primarily cash equivalents, municipal bonds, and private credit/alts) to support HNW goals: tax-optimized income (e.g., federal/state exemptions for munis), predictable cash flow (e.g., coupon projections), and reinvestment planning (e.g., maturity alerts to avoid idle cash and preserve wealth). By parsing/adding fields like tax_exempt_status, coupon_rate, and maturity_date, we enable after-tax yield calcs and alerts, feeding into Python sims (e.g., Monte Carlo for reinvestment scenarios). Work is divided into atomic PRDs: easy (cash – pattern-based defaults), medium (private credit – link addition), hard (munis – parsing + optional lookups). Data goes into `fixed_incomes` table (extends holdings via has_one) for bond-specific fields, preserving Plaid sync safety. No UI in initial PRDs; final PRD adds optional admin UI for manual overrides. Total: 4 PRDs, implemented sequentially by Junie using Claude Sonnet 4.5 in RubyMine. Dependencies: Existing Plaid sync jobs; assumes `fixed_incomes` table exists (add migration if not).

## Division of Work
- **Easy Holdings (~70%, Cash/US Dollar)**: Pattern-match name/symbol (e.g., /Dollar|Cash/i) → set defaults (asset_class: 'cash', tax_exempt_status: 'fully_taxable', coupon_rate: 0.0, maturity_date: nil). Approach: Rule-based service method; no external calls/UI. High value: Quick tax/income flags without risk.
- **Medium Holdings (~5%, Private Credit/Alts)**: Match names like "HPS Corporate Lending Fund" → add external_report_url (manual or Ollama-assisted). Approach: Simple parse + field addition; defer deep lookups.
- **Hard Holdings (~25%, Munis)**: Parse name for issuer/coupon/maturity/state → infer tax_exempt_status (e.g., federal_exempt; in_state if Texas-issued). Approach: Regex parsing first; optional OpenFIGI/MSRB browse for CUSIP/tax confirmation if parse ambiguous. Manual overrides in final PRD.

## Atomic PRD 1: Easy Enrichment for Cash Holdings
### Overview
Add logic to classify and enrich cash holdings (~70 of ~100 unenriched) with tax/income/maturity defaults, preventing Plaid overwrites and enabling basic after-tax income views.

### Requirements
- Functional: In enrichment service (e.g., HoldingEnrichmentService), add method: if holding.name =~ /US Dollar|Cash/i || holding.is_cash_equivalent, set asset_class: 'cash', sector: 'Cash', industry: 'Currency', tax_exempt_status: 'fully_taxable' (enum), coupon_rate: 0.0, distribution_frequency: 'none', maturity_date: nil, expected_annual_income: 0.0 (computed as quantity * coupon_rate).
- Non-Functional: Run post-Plaid sync (hook into SyncHoldingsJob); preserve on future syncs via protected_fields array (e.g., attrs.except(:tax_exempt_status) if present).
- Architectural Context: Use Rails MVC; add columns to holdings: tax_exempt_status (string), coupon_rate (decimal), distribution_frequency (string), expected_annual_income (decimal). Migration: add_column :holdings, :tax_exempt_status, :string, default: 'unknown'. Service: app/services/holding_enrichment_service.rb. Use local Ollama via AiFinancialAdvisor for edge-case name matching if regex fails (e.g., prompt: "Is '[name]' a cash equivalent?").

### Acceptance Criteria
- Cash holding with name "US Dollar" auto-sets tax_exempt_status: 'fully_taxable', coupon_rate: 0.0.
- Non-cash (e.g., muni) skips this logic.
- Plaid sync updates market_value but preserves enriched tax_exempt_status.
- Computed expected_annual_income = 0 for cash.
- Rake task backfills existing ~70 cash holdings.

### Test Cases
- Unit: RSpec for HoldingEnrichmentService.enrich_cash(holding) → assert_changes holding.tax_exempt_status, from: 'unknown', to: 'fully_taxable'.
- Integration: VCR mock Plaid sync → enrich → assert preserved fields.
- Edge: Non-matching name → no change.

### Workflow
Junie: Pull from master, branch feature/prd-1-cash-enrichment. Use Claude Sonnet 4.5. Build plan: Questions? (e.g., confirm regex patterns). Commit green code only (rspec passing).

## Atomic PRD 2: Medium Enrichment for Private Credit/Alts
### Overview
Enrich ~5 private credit holdings (e.g., "HPS Corporate Lending Fund") with income-focused fields and report links, supporting tax treatment (ordinary income) and distribution projections.

### Requirements
- Functional: In HoldingEnrichmentService, match names (e.g., /Fund|Trust|LLC/i && !muni_pattern) → set asset_class: 'alternative', sector: 'Private Credit', tax_exempt_status: 'fully_taxable', distribution_frequency: 'monthly' or 'quarterly' (parse or default), expected_annual_income: quantity * estimated_yield (default 0.10 if unknown). Add external_report_url: string (e.g., Ollama prompt: "Latest quarterly report URL for [name]").
- Non-Functional: Ollama integration for URL suggestion (local Llama 3.1 70B); protect fields from Plaid overwrites.
- Architectural Context: Add columns to holdings: external_report_url (string), estimated_yield (decimal). Service method: enrich_private(holding). No UI yet.

### Acceptance Criteria
- Private holding sets tax_exempt_status: 'fully_taxable', external_report_url present (e.g., EDGAR link).
- Expected_annual_income computed >0.
- Ollama call logged if used.
- Sync preserves URL.
- Backfill rake for ~5 holdings.

### Test Cases
- Unit: Mock Ollama response → assert holding.external_report_url == 'https://sec.gov/...'.
- Integration: Full enrich flow → no overwrite on mock sync.

### Workflow
Junie: Branch feature/prd-2-private-enrichment. Plan: Questions? Commit green.

## Atomic PRD 3: Hard Enrichment for Municipal Bonds via Parsing
### Overview
Parse ~25 muni names for tax/income/maturity data, inferring exemptions and enabling reinvestment alerts without external lookups initially.

### Requirements
- Functional: In HoldingEnrichmentService, match muni patterns (e.g., /Cnty|St|Nc|Tx\s*\d+%\s*\d{2}\/\d{2}\/\d{2}/) → parse_issuer (string before %), coupon_rate (e.g., 5.0), maturity_date (Date from MM/DD/YY), state_code (e.g., 'TX' from name). Set asset_class: 'fixed_income', sector: 'Municipal Bond', industry: 'Government/Local', tax_exempt_status: 'federal_exempt' (or 'fully_exempt' if state_code == 'TX'), in_state_indicator: (state_code == 'TX'), distribution_frequency: 'semi_annual', expected_annual_income: market_value * coupon_rate, years_to_maturity: ((maturity_date - Date.today)/365).to_i, is_near_maturity: years_to_maturity <=1.
- Non-Functional: Regex-based parsing; fallback to 'unknown' if fail; protect from overwrites.
- Architectural Context: Extend fixed_incomes table (has_one :fixed_income from Holding) with parsed_issuer (string), state_code (string), in_state_indicator (boolean), years_to_maturity (integer), is_near_maturity (boolean). Migration: add these to fixed_incomes. Computed fields as after_save callbacks.

### Acceptance Criteria
- Muni name "Charlotte Nc Wtr & Swr 5% 07/01/36" → coupon_rate: 5.0, maturity_date: '2036-07-01', tax_exempt_status: 'federal_exempt' (or fully if NC=TX? Wait, NC≠TX → federal only).
- Texas muni → in_state_indicator: true, tax_exempt_status: 'fully_exempt'.
- Expected_annual_income >0.
- Non-muni skips.
- Backfill rake for ~25 munis.

### Test Cases
- Unit: RSpec for parse_muni_name(name) → hash assertions.
- Integration: Enrich → sync → preserved parsed fields.

### Workflow
Junie: Branch feature/prd-3-muni-parsing. Plan: Questions? (e.g., refine regex). Commit green.

## Atomic PRD 4: Optional Lookups, Alerts, and Manual UI for Hard Cases
### Overview
Add external lookups for ambiguous munis, maturity alerts, and admin UI for manual steps (e.g., CUSIP entry, URL overrides), completing enrichment.

### Requirements
- Functional: In service, if parse ambiguous (e.g., maturity nil), use browse_page tool (e.g., url: 'https://emma.msrb.org/Search/Search.aspx', instructions: "Search for [parsed_issuer] [coupon_rate]% maturing [maturity_date]; return CUSIP and tax details"). Update cusip, tax_exempt_status. Add MaturityAlertJob (daily Sidekiq): query fixed_incomes.is_near_maturity → notify user (in-app or log for now). UI: Admin-only form at /admin/holdings/:id/enrich (ViewComponent) for manual edits (e.g., tax_exempt_status dropdown, external_report_url input).
- Non-Functional: Limit lookups to 5/day (manual trigger); UI protected by admin auth (Devise scope).
- Architectural Context: New controller: Admin::EnrichmentsController; component: app/components/admin/enrichment_form_component.rb (Tailwind/DaisyUI). Job: app/jobs/maturity_alert_job.rb.

### Acceptance Criteria
- Ambiguous muni → browse_page call → updated cusip.
- Job runs → alerts for maturities <1 year.
- UI: Form saves manual tax_exempt_status without overwriting Plaid fields.
- Protected: Non-admin → 403.
- Manual step: UI accommodates all remaining hard cases.

### Test Cases
- Unit: Mock browse_page → assert cusip updated.
- Integration: Capybara for UI form submission.
- Job: assert_performed_with for alerts.

### Workflow
Junie: Branch feature/prd-4-lookups-alerts-ui. Plan: Questions? Commit green.

Next steps: Implement PRD 1 first? Questions on divisions (e.g., adjust % estimates)?