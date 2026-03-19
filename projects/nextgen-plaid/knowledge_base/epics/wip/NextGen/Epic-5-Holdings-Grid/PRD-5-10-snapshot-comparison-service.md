# PRD 5-10: Holdings Snapshots – Comparison & Performance Calculation Service

## log requirements
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- in the log put detailed steps for human to manually test and what the expected results
- If asked to review please create a separate document called <prd-name>-feedback.md

## Overview
Build a service to compare two snapshots (or one snapshot vs current live) and compute performance metrics (period return %, value deltas, added/removed positions).

## Requirements

### Functional
- **HoldingsSnapshotComparator Service**:
  - Input: start_snapshot_id, end_snapshot_id (or :current for live)
  - Output: structured hash/JSON with overall metrics + per-security deltas
  - Metrics:
    - Overall: period_return_pct, delta_value ($), delta_pct (%)
    - Per-security: ticker, delta_qty, delta_value, return_pct, status (:added/:removed/:changed)
- **Simple Return Calculation**:
  - `period_return_pct = ((end_value - start_value) / start_value) * 100`
  - Per-security: `return_pct = ((end_value - start_value) / start_value) * 100`
- **Security Matching Logic**:
  - Primary: match by `security_id`
  - Fallback: match by `ticker_symbol` + `name` if security_id missing in one snapshot
  - Log mismatch for investigation (e.g., ticker changed due to corporate action)
- **Status Flags**:
  - `:added` — security in end but not in start
  - `:removed` — security in start but not in end
  - `:changed` — security in both, quantity or value changed
  - `:unchanged` — security in both, no change (optionally exclude from output)
- **Edge Case Handling**:
  - Start value = 0 → return_pct = "N/A" or "∞" (infinite)
  - Negative cost basis → show as-is with disclaimer
  - Positions moved between accounts → treated as removed from old + added to new
  - Division by zero → handle gracefully (N/A)

### Non-Functional
- Efficient Ruby comparison: O(n) via hashes (not nested loops)
- Real-time computation for v1 (no async)
- Monitor performance: if >2s for 500 holdings, add caching
  - Cache key: `"snapshot_comparison:v1:#{start_id}:#{end_id}:#{filter_hash}"`
  - TTL: 30 minutes
- Handles mismatched JSON structures gracefully (different schema versions)
- Structured error handling (snapshot not found, invalid data)

## Architectural Context
Plain service class: `app/services/holdings_snapshot_comparator.rb`. Fetches snapshots, parses JSON, builds hash maps for efficient comparison. For `:current`, calls HoldingsGridDataProvider in :live mode. Returns structured hash for controller/view consumption.

## Service Implementation

```ruby
# app/services/holdings_snapshot_comparator.rb
class HoldingsSnapshotComparator
  def initialize(start_snapshot_id:, end_snapshot_id:, user_id:)
    @start_snapshot_id = start_snapshot_id
    @end_snapshot_id = end_snapshot_id
    @user_id = user_id
  end

  def call
    start_holdings = fetch_holdings(@start_snapshot_id)
    end_holdings = fetch_holdings(@end_snapshot_id)

    overall_metrics = compute_overall_metrics(start_holdings, end_holdings)
    security_deltas = compute_security_deltas(start_holdings, end_holdings)

    {
      overall: overall_metrics,
      securities: security_deltas
    }
  end

  private

  def fetch_holdings(snapshot_id)
    if snapshot_id == :current
      fetch_live_holdings
    else
      fetch_snapshot_holdings(snapshot_id)
    end
  end

  def fetch_live_holdings
    provider = HoldingsGridDataProvider.new(user_id: @user_id, snapshot_id: :live, per_page: 'all')
    provider.holdings.index_by { |h| h.security_id || "#{h.ticker_symbol}_#{h.name}" }
  end

  def fetch_snapshot_holdings(snapshot_id)
    snapshot = HoldingsSnapshot.find(snapshot_id)
    holdings = snapshot.snapshot_data['holdings']
    holdings.index_by { |h| h['security_id'] || "#{h['ticker_symbol']}_#{h['name']}" }
  end

  def compute_overall_metrics(start_holdings, end_holdings)
    start_value = start_holdings.values.sum { |h| h['market_value'] || h[:market_value] }
    end_value = end_holdings.values.sum { |h| h['market_value'] || h[:market_value] }

    delta_value = end_value - start_value
    delta_pct = start_value.zero? ? nil : (delta_value / start_value * 100).round(2)
    period_return_pct = delta_pct

    {
      start_value: start_value,
      end_value: end_value,
      delta_value: delta_value,
      delta_pct: delta_pct,
      period_return_pct: period_return_pct
    }
  end

  def compute_security_deltas(start_holdings, end_holdings)
    all_keys = (start_holdings.keys + end_holdings.keys).uniq
    deltas = {}

    all_keys.each do |key|
      start_h = start_holdings[key]
      end_h = end_holdings[key]

      deltas[key] = if start_h && end_h
        compute_changed_delta(start_h, end_h)
      elsif end_h
        compute_added_delta(end_h)
      else
        compute_removed_delta(start_h)
      end
    end

    deltas
  end

  def compute_changed_delta(start_h, end_h)
    start_val = start_h['market_value'] || start_h[:market_value]
    end_val = end_h['market_value'] || end_h[:market_value]

    delta_qty = (end_h['quantity'] || end_h[:quantity]) - (start_h['quantity'] || start_h[:quantity])
    delta_value = end_val - start_val
    return_pct = start_val.zero? ? nil : ((end_val - start_val) / start_val * 100).round(2)

    {
      ticker: end_h['ticker_symbol'] || end_h[:ticker_symbol],
      status: :changed,
      delta_qty: delta_qty,
      delta_value: delta_value,
      return_pct: return_pct,
      start_value: start_val,
      end_value: end_val
    }
  end

  def compute_added_delta(end_h)
    {
      ticker: end_h['ticker_symbol'] || end_h[:ticker_symbol],
      status: :added,
      delta_qty: end_h['quantity'] || end_h[:quantity],
      delta_value: end_h['market_value'] || end_h[:market_value],
      return_pct: nil,
      start_value: 0,
      end_value: end_h['market_value'] || end_h[:market_value]
    }
  end

  def compute_removed_delta(start_h)
    {
      ticker: start_h['ticker_symbol'] || start_h[:ticker_symbol],
      status: :removed,
      delta_qty: -(start_h['quantity'] || start_h[:quantity]),
      delta_value: -(start_h['market_value'] || start_h[:market_value]),
      return_pct: nil,
      start_value: start_h['market_value'] || start_h[:market_value],
      end_value: 0
    }
  end
end
```

## Output Structure

```json
{
  "overall": {
    "start_value": 250000.00,
    "end_value": 275000.00,
    "delta_value": 25000.00,
    "delta_pct": 10.0,
    "period_return_pct": 10.0
  },
  "securities": {
    "abc123": {
      "ticker": "AAPL",
      "status": "changed",
      "delta_qty": 10,
      "delta_value": 1500.00,
      "return_pct": 12.5,
      "start_value": 12000.00,
      "end_value": 13500.00
    },
    "xyz789": {
      "ticker": "TSLA",
      "status": "added",
      "delta_qty": 50,
      "delta_value": 10000.00,
      "return_pct": null,
      "start_value": 0,
      "end_value": 10000.00
    },
    "def456": {
      "ticker": "GE",
      "status": "removed",
      "delta_qty": -100,
      "delta_value": -5000.00,
      "return_pct": null,
      "start_value": 5000.00,
      "end_value": 0
    }
  }
}
```

## Acceptance Criteria
- Compares two snapshots accurately (return %, deltas)
- Snapshot vs :current (live) works correctly
- Correctly flags securities as added/removed/changed
- Overall metrics calculate correctly
- Per-security deltas match expected values
- Output structure is consistent and valid
- Performance acceptable: <2s for 500 holdings
- Handles edge cases: zero start value, negative cost basis, missing fields
- Logs warnings for unmatched securities (ticker changes)

## Test Cases
- **Service**:
  - Setup fixtures: two snapshots with known holdings
  - Assert overall: period_return_pct, delta_value, delta_pct
  - Assert per-security: added, removed, changed flags
  - Verify return_pct calculations
- **Edge cases**:
  - No overlap (all added or removed)
  - Only added positions
  - Only removed positions
  - Quantity change but no value change (price adjusted)
  - Zero start value → return_pct nil
  - Negative cost basis → handle gracefully
  - Snapshot vs live comparison
- **Integration**:
  - Call with real snapshot IDs
  - Verify output structure matches expected
- **Performance**:
  - Benchmark with 500 holdings → assert <2s

## Manual Testing Steps
1. Create two snapshots for same user, 7 days apart
2. Between snapshots:
   - Add new holdings (buy TSLA)
   - Remove holdings (sell GE)
   - Change quantity (buy more AAPL)
3. Rails console: run comparator
   ```ruby
   comparator = HoldingsSnapshotComparator.new(
     start_snapshot_id: snapshot1.id,
     end_snapshot_id: snapshot2.id,
     user_id: 1
   )
   result = comparator.call
   ```
4. Verify overall metrics: period_return_pct, delta_value
5. Verify per-security:
   - AAPL: status = :changed, delta_qty > 0
   - TSLA: status = :added
   - GE: status = :removed
6. Test snapshot vs :current (live)
7. Test with zero start value security → verify return_pct nil
8. Test with 500 holdings → verify completes in <2s
9. Check logs for any warnings (unmatched securities)

## Workflow
Junie: Use Claude Sonnet 4.5 or equivalent. Pull from master, branch `feature/prd-5-10-snapshot-comparison-service`. Ask questions/plan in log. Commit green code only.

## Dependencies
- PRD 5-02 (Data provider service for live holdings)
- PRD 5-08 (HoldingsSnapshot model)

## Blocked By
- PRD 5-08 must be complete

## Blocks
- PRD 5-12 (Comparison mode UI uses this service)

## Related Documentation
- [Epic Overview](./0000-overview-epic-5.md)
- [PRD 5-08: Holdings Snapshots Model](./PRD-5-08-holdings-snapshots-model.md)
- [Feedback V2 - Snapshot Comparison](./Epic-5-Holding-Grid-feedback-V2.md#prd-10-snapshot-comparison)
