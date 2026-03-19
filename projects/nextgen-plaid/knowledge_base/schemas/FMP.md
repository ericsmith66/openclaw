### Proposed `security_enrichment.data` (`jsonb`) structure

I don’t have enough context here to know what your app currently stores in `security_enrichment.data`, but if you want a clean, extensible structure for enrichment results (from multiple providers, partial updates, and auditability), this is a solid baseline.

#### High-level shape
- Top-level keys are stable: `version`, `as_of`, `provider`, `identifiers`, `profile`, `classification`, `trading`, `fundamentals`, `risk`, `raw`.
- Store **normalized fields** (what your app reads) plus a **`raw`** blob for the provider payload.

```json
{
  "version": 1,
  "as_of": "2026-01-20T20:00:00Z",
  "provider": {
    "name": "polygon",
    "request_id": "req_123",
    "fetched_at": "2026-01-20T20:00:00Z",
    "confidence": 0.92
  },
  "identifiers": {
    "symbol": "AAPL",
    "name": "Apple Inc.",
    "ticker": "AAPL",
    "exchange": "NASDAQ",
    "mic": "XNAS",
    "figi": "BBG000B9XRY4",
    "composite_figi": "BBG000B9XRY4",
    "isin": "US0378331005",
    "cusip": "037833100",
    "cik": "0000320193",
    "lei": null
  },
  "profile": {
    "website": "https://www.apple.com",
    "description": "...",
    "logo_url": "https://...",
    "country": "US",
    "currency": "USD",
    "employee_count": 161000
  },
  "classification": {
    "security_type": "equity",
    "asset_class": "stock",
    "sector": "Technology",
    "industry": "Consumer Electronics",
    "gics": {
      "sector": "Information Technology",
      "industry_group": "Technology Hardware & Equipment",
      "industry": "Technology Hardware, Storage & Peripherals",
      "sub_industry": "Technology Hardware, Storage & Peripherals"
    }
  },
  "trading": {
    "is_listed": true,
    "is_active": true,
    "primary_exchange": "NASDAQ",
    "last_trade_at": "2026-01-20T20:00:00Z",
    "market_cap": 3000000000000,
    "shares_outstanding": 15500000000
  },
  "fundamentals": {
    "pe_ttm": 28.4,
    "dividend_yield": 0.005,
    "eps_ttm": 6.12,
    "beta": 1.24
  },
  "risk": {
    "volatility_30d": null,
    "drawdown_1y": null
  },
  "quality": {
    "missing_fields": ["risk.volatility_30d"],
    "warnings": []
  },
  "raw": {
    "provider_payload": {}
  }
}
```

### Notes / conventions
- Use ISO-8601 strings for timestamps (UTC) to keep JSON portable.
- Keep numeric fields as numbers (not strings) so you can query with Postgres JSON operators if needed.
- Put anything provider-specific under `raw.provider_payload` so normalized keys remain consistent across providers.
- Add `version` so you can evolve the structure without breaking old rows.

### If you want the *actual* structure in your repo
If you paste the `SecurityEnrichment` model (or the migration that adds the `data` column), I can tell you exactly what keys your app expects today (and align the JSONB structure to it).