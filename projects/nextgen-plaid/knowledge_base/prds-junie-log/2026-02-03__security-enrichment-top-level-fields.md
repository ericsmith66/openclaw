### Context

Observed that `SecurityEnrichment` top-level columns (e.g., `roe`, `roa`, `beta`, `market_cap`) were not being populated even though the values existed in the stored `data` payload.

### Root cause

The column extraction logic in `HoldingsEnrichmentJob` only read snake_case string keys (e.g., `data["market_cap"]`). In practice, some payloads can arrive with:

- symbol keys (e.g., `:market_cap`)
- camelCase keys (e.g., `:marketCap`, `:returnOnEquity`)

In those cases, the values would remain present in `data` but the top-level database columns would remain `NULL`.

### Changes made

- Updated `app/jobs/holdings_enrichment_job.rb` to use `with_indifferent_access` and to accept both snake_case and camelCase key variants for column mapping.
- Added a regression test covering camelCase/symbolized payload keys.

### Files changed

- `app/jobs/holdings_enrichment_job.rb`
- `app/services/fmp_enricher_service.rb`
- `test/jobs/holdings_enrichment_job_test.rb`

### Commands run

```sh
RAILS_ENV=test bin/rails test test/jobs/holdings_enrichment_job_test.rb
RAILS_ENV=test bin/rails db:migrate
bin/rails db:migrate
bin/rails security_enrichments:reenrich_all LIMIT=1
```

### Test results

- `4 runs, 23 assertions, 0 failures, 0 errors, 0 skips`

### Operational notes

- Removed the 7-day skip so `HoldingsEnrichmentJob` will always re-enrich.
- Added `security_enrichments.symbol` and a rake task to re-enrich all existing rows:
  - `bin/rails security_enrichments:reenrich_all`
  - Optional: `LIMIT=... OFFSET=...` for batching.

### Manual verification

- Ran `bin/rails security_enrichments:reenrich_all LIMIT=1` successfully (verified the task runs end-to-end after applying the migration in development).

### Follow-up (beta + debt_to_equity)

Observed that some payloads contain:

- `raw_response.profile[0].beta`
- `raw_response.ratios[0].debtToEquityRatio`

But our extractor was only looking for `beta` in `key-metrics`/`quote` and `debtEquityRatio` in `ratios`, so those values could be missed.

Changes:

- Updated `app/services/fmp_enricher_service.rb` to extract `beta` from `profile` as a fallback.
- Updated `app/services/fmp_enricher_service.rb` to extract `debt_to_equity` from `ratios.debtToEquityRatio` (and keep support for `debtEquityRatio`).
- Updated `app/jobs/holdings_enrichment_job.rb` column mapping to accept `debtToEquityRatio` as well.
- Added regression test: `test/services/fmp_enricher_service_test.rb`.

Commands run:

```sh
RAILS_ENV=test bin/rails test test/services/fmp_enricher_service_test.rb test/jobs/holdings_enrichment_job_test.rb

# Backfill existing rows from already-stored raw_response (no external API calls)
RAILS_ENV=test bin/rails db:migrate
bin/rails db:migrate
```

### Manual verification

- Verified backfill populated missing columns in dev:

  ```rb
  SecurityEnrichment.where(beta: nil).count # => 0
  SecurityEnrichment.where(debt_to_equity: nil).count # => 0
  ```

### Follow-up (pe_ratio)

Observed that `security_enrichments.pe_ratio` was blank for all rows. The stored payloads do contain PE, but under a different key:

- `data["raw_response"]["ratios"][0]["priceToEarningsRatio"]`

Fixes:

- Updated `app/services/fmp_enricher_service.rb` to extract `pe_ratio` from `ratios.priceToEarningsRatio` (plus fallbacks like `priceEarningsRatio`, `peRatio`, `pe`, and `quote.pe`).
- Updated `app/jobs/holdings_enrichment_job.rb` column mapping to accept those alternate PE keys when persisting top-level columns.
- Added non-destructive backfill migration `db/migrate/20260203141000_backfill_pe_ratio_from_raw_response.rb` to populate missing `pe_ratio` from already-stored `raw_response`.

Commands run:

```sh
RAILS_ENV=test bin/rails db:migrate
bin/rails db:migrate
RAILS_ENV=test bin/rails test test/services/fmp_enricher_service_test.rb test/jobs/holdings_enrichment_job_test.rb
```

Verification (dev):

```rb
SecurityEnrichment.where(pe_ratio: nil).count # => 0
```
