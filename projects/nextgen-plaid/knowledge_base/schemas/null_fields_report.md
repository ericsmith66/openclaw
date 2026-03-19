# Null Fields Report

Generated at: 2026-02-01T05:00:00Z

This report scans Accounts, Holdings, Transactions, Liabilities (stored on Accounts), and Balance Snapshots for null fields, grouped by Plaid institution_id.

---

## Institution: UNKNOWN

### Accounts

- Total rows: 12

| Field | Null Count | Null % | Pattern |
| --- | ---: | ---: | --- |
| `credit_limit` | 12 | 100.0% | always null |
| `holder_category` | 12 | 100.0% | always null |

### Holdings

- Total rows: 41

| Field | Null Count | Null % | Pattern |
| --- | ---: | ---: | --- |
| `maturity_date` | 41 | 100.0% | always null |
| `disclaimers` | 41 | 100.0% | always null |
| `vested_value` | 41 | 100.0% | always null |
| `isin` | 41 | 100.0% | always null |
| `cusip` | 41 | 100.0% | always null |
| `source_institution` | 41 | 100.0% | always null |
| `import_timestamp` | 41 | 100.0% | always null |
| `unrealized_gl` | 41 | 100.0% | always null |
| `acquisition_date` | 41 | 100.0% | always null |
| `ytm` | 41 | 100.0% | always null |
| `proxy_security_id` | 40 | 97.56% | mostly null |
| `asset_class_derived_at` | 14 | 34.15% |  |
| `asset_class` | 14 | 34.15% |  |
| `asset_class_source` | 14 | 34.15% |  |
| `industry` | 11 | 26.83% |  |
| `market_identifier_code` | 11 | 26.83% |  |
| `cost_basis` | 11 | 26.83% |  |
| `subtype` | 11 | 26.83% |  |
| `close_price` | 1 | 2.44% |  |
| `close_price_as_of` | 1 | 2.44% |  |
| `ticker_symbol` | 1 | 2.44% |  |
| `symbol` | 1 | 2.44% |  |

### Transactions

- Total rows: 661

| Field | Null Count | Null % | Pattern |
| --- | ---: | ---: | --- |
| `personal_finance_category_label` | 661 | 100.0% | always null |
| `merchant_name` | 661 | 100.0% | always null |
| `payment_channel` | 661 | 100.0% | always null |
| `category` | 661 | 100.0% | always null |
| `cusip` | 661 | 100.0% | always null |
| `ticker` | 661 | 100.0% | always null |
| `quantity` | 661 | 100.0% | always null |
| `cost_usd` | 661 | 100.0% | always null |
| `income_usd` | 661 | 100.0% | always null |
| `tran_code` | 661 | 100.0% | always null |
| `import_timestamp` | 661 | 100.0% | always null |
| `source_institution` | 661 | 100.0% | always null |
| `dedupe_key` | 661 | 100.0% | always null |
| `pending_transaction_id` | 661 | 100.0% | always null |
| `account_owner` | 661 | 100.0% | always null |
| `unofficial_currency_code` | 661 | 100.0% | always null |
| `check_number` | 661 | 100.0% | always null |
| `datetime` | 661 | 100.0% | always null |
| `authorized_date` | 661 | 100.0% | always null |
| `authorized_datetime` | 661 | 100.0% | always null |
| `original_description` | 661 | 100.0% | always null |
| `logo_url` | 661 | 100.0% | always null |
| `website` | 661 | 100.0% | always null |
| `merchant_entity_id` | 661 | 100.0% | always null |
| `transaction_type` | 661 | 100.0% | always null |
| `transaction_code` | 661 | 100.0% | always null |
| `personal_finance_category_icon_url` | 661 | 100.0% | always null |
| `personal_finance_category_confidence_level` | 661 | 100.0% | always null |
| `location` | 661 | 100.0% | always null |
| `payment_meta` | 661 | 100.0% | always null |
| `counterparties` | 661 | 100.0% | always null |
| `dedupe_fingerprint` | 661 | 100.0% | always null |
| `merchant_id` | 661 | 100.0% | always null |
| `personal_finance_category_id` | 661 | 100.0% | always null |
| `transaction_code_id` | 661 | 100.0% | always null |
| `deleted_at` | 661 | 100.0% | always null |
| `dividend_type` | 523 | 79.12% |  |

### Liabilities (Accounts)

- Total rows: 0
- No rows to analyze.

### Balance Snapshots

- Total rows: 60

| Field | Null Count | Null % | Pattern |
| --- | ---: | ---: | --- |
| `limit` | 60 | 100.0% | always null |
| `apr_percentage` | 60 | 100.0% | always null |
| `min_payment_amount` | 60 | 100.0% | always null |
| `next_payment_due_date` | 60 | 100.0% | always null |

---

## Institution: ins_56

### Accounts

- Total rows: 27

| Field | Null Count | Null % | Pattern |
| --- | ---: | ---: | --- |
| `official_name` | 27 | 100.0% | always null |
| `credit_limit` | 27 | 100.0% | always null |
| `holder_category` | 27 | 100.0% | always null |

### Holdings

- Total rows: 1439

| Field | Null Count | Null % | Pattern |
| --- | ---: | ---: | --- |
| `proxy_security_id` | 1439 | 100.0% | always null |
| `ticker_symbol` | 1439 | 100.0% | always null |
| `market_identifier_code` | 1439 | 100.0% | always null |
| `iso_currency_code` | 1439 | 100.0% | always null |
| `vested_value` | 1439 | 100.0% | always null |
| `isin` | 1439 | 100.0% | always null |
| `cusip` | 1439 | 100.0% | always null |
| `subtype` | 1439 | 100.0% | always null |
| `unrealized_gl` | 1439 | 100.0% | always null |
| `acquisition_date` | 1439 | 100.0% | always null |
| `ytm` | 1439 | 100.0% | always null |
| `maturity_date` | 1439 | 100.0% | always null |
| `disclaimers` | 1439 | 100.0% | always null |
| `import_timestamp` | 1439 | 100.0% | always null |
| `source_institution` | 1439 | 100.0% | always null |
| `close_price` | 1439 | 100.0% | always null |
| `close_price_as_of` | 1439 | 100.0% | always null |
| `symbol` | 90 | 6.25% |  |
| `industry` | 90 | 6.25% |  |
| `cost_basis` | 29 | 2.02% |  |

### Transactions

- Total rows: 9007

| Field | Null Count | Null % | Pattern |
| --- | ---: | ---: | --- |
| `payment_meta` | 9007 | 100.0% | always null |
| `personal_finance_category_icon_url` | 9007 | 100.0% | always null |
| `personal_finance_category_confidence_level` | 9007 | 100.0% | always null |
| `location` | 9007 | 100.0% | always null |
| `category` | 9007 | 100.0% | always null |
| `dedupe_fingerprint` | 9007 | 100.0% | always null |
| `merchant_id` | 9007 | 100.0% | always null |
| `personal_finance_category_id` | 9007 | 100.0% | always null |
| `transaction_code_id` | 9007 | 100.0% | always null |
| `deleted_at` | 9007 | 100.0% | always null |
| `investment_transaction_id` | 9007 | 100.0% | always null |
| `security_id` | 9007 | 100.0% | always null |
| `cusip` | 9007 | 100.0% | always null |
| `ticker` | 9007 | 100.0% | always null |
| `quantity` | 9007 | 100.0% | always null |
| `cost_usd` | 9007 | 100.0% | always null |
| `income_usd` | 9007 | 100.0% | always null |
| `tran_code` | 9007 | 100.0% | always null |
| `import_timestamp` | 9007 | 100.0% | always null |
| `source_institution` | 9007 | 100.0% | always null |
| `dedupe_key` | 9007 | 100.0% | always null |
| `pending_transaction_id` | 9007 | 100.0% | always null |
| `account_owner` | 9007 | 100.0% | always null |
| `unofficial_currency_code` | 9007 | 100.0% | always null |
| `check_number` | 9007 | 100.0% | always null |
| `datetime` | 9007 | 100.0% | always null |
| `authorized_date` | 9007 | 100.0% | always null |
| `authorized_datetime` | 9007 | 100.0% | always null |
| `original_description` | 9007 | 100.0% | always null |
| `merchant_entity_id` | 9007 | 100.0% | always null |
| `transaction_type` | 9007 | 100.0% | always null |
| `transaction_code` | 9007 | 100.0% | always null |
| `counterparties` | 9005 | 99.98% | mostly null |
| `investment_type` | 8751 | 97.16% | mostly null |
| `dividend_type` | 8751 | 97.16% | mostly null |
| `logo_url` | 8104 | 89.97% |  |
| `website` | 7997 | 88.79% |  |
| `merchant_name` | 7262 | 80.63% |  |
| `payment_channel` | 7262 | 80.63% |  |
| `personal_finance_category_label` | 7262 | 80.63% |  |
| `fees` | 1745 | 19.37% |  |
| `price` | 1745 | 19.37% |  |
| `subtype` | 1745 | 19.37% |  |

### Liabilities (Accounts)

- Total rows: 2

| Field | Null Count | Null % | Pattern |
| --- | ---: | ---: | --- |
| (none) | 0 | 0% | |

### Balance Snapshots

- Total rows: 0
- No rows to analyze.
