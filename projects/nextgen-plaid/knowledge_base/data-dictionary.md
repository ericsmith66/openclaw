# Data Dictionary

This document defines shared schemas and conventions for structured fields (especially `jsonb`) used across the application.

## Table: `saved_account_filters`

### Column: `criteria` (`jsonb`)

The `criteria` payload defines how the application should scope accounts/holdings when a saved filter is selected.

#### Schema (v1)

```json
{
  "account_ids": [1, 2, 3],
  "institution_ids": ["ins_123", "ins_456"],
  "ownership_types": ["Individual", "Trust"],
  "asset_strategy": ["growth", "income"],
  "trust_code": ["TR001"],
  "holder_category": ["parent", "kid"]
}
```

#### Keys

- `account_ids` (optional)
  - Array of either:
    - internal `accounts.id` integers
    - Plaid `accounts.account_id` strings
- `institution_ids` (optional)
  - Array of Plaid institution ids (`plaid_items.institution_id`).
- `ownership_types` (optional)
  - Array of values from `ownership_lookups.ownership_type`.
  - Current allowed values: `Individual`, `Trust`, `Other`.
- `asset_strategy` (optional)
  - String or array of strings matching `accounts.asset_strategy`.
- `trust_code` (optional)
  - String or array of strings matching `accounts.trust_code`.
- `holder_category` (optional)
  - String or array of strings matching `accounts.holder_category`.

#### Notes

- A saved filter must include at least one of the keys above.
- When multiple keys are provided, the filter is interpreted as an `AND` across criteria.
