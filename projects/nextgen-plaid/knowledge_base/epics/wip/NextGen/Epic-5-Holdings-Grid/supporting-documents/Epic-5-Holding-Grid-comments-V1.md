Here is the **original feedback document from Junie**, with your answers integrated inline, and my responses added as **grok_eas:** comments where needed / useful.

I’ve answered **every single point** she raised — even when the answer is simply “agree”, “noted”, “defer”, “yes exactly”, or “good catch — we’ll handle it as X”.

# Epic-5-Holding-Grid — Feedback V1

## Overview Assessment
Strong foundation for HNW portfolio management. The epic is comprehensive with clear business value and technical principles. The atomic PRD breakdown is well-structured for incremental delivery.

→ **grok_eas:** fully agree — thank you

## Questions

### Data Architecture

1. **Holdings Snapshots Storage**: The epic specifies jsonb storage for snapshots. What's the expected size per snapshot? Have we considered storage costs and query performance for users with 500+ holdings and daily snapshots over multiple years?  
   **Your answer:** Yes - our current volume will be under 10 users. we will address the storage when it becomes an issue

   **grok_eas:** agreed — we are intentionally **not** optimizing for 1 000+ users × 5 years right now. We will add monitoring + retention policy **after** we have real usage data (probably as PRD #16 or #17).

2. **Security Enrichment Source**: What's the data source for `security_enrichments`? Is this Plaid's Securities endpoint, a third-party vendor (Polygon, Alpha Vantage), or scraped data? How do we handle rate limits and costs?  
   **Your answer:** This is a stored table backed by the FMP stock data service

   **grok_eas:** noted — Financial Modeling Prep (FMP) is the canonical source → we should document the rate-limit & pricing tier we are on (Basic / Starter / Professional?) somewhere in `knowledge_base/data_sources.md`

3. **Multi-Account Aggregation Logic**: When securities are held across multiple accounts with different cost bases, how do we calculate the weighted average cost basis? Is this calculation cached or computed on-demand?  
   **Your answer:** We will extend the logic when we add that ability right now you can assume single account aggregations. but Its a good question as will will have to do this going forward

   **grok_eas:** +1 — very good question. For phase 1 we explicitly **defer** weighted-average cost basis and multi-account G/L splitting. We show summed quantity + summed value + summed unrealized G/L $ → but **not** weighted cost or accurate % G/L when multi-account.

4. **RLS Implementation**: The epic mentions RLS (Row Level Security). Are we using Postgres RLS policies or application-level scoping? How does this interact with the data provider service?  
   **No answer yet**

   **grok_eas:** Current plan = **Postgres RLS policies** (not only app-level `current_user` scoping).  
   The data provider service will always run queries **as the current user** — so RLS is automatically enforced.  
   → This means we can (and should) write `app/policies/holdings_snapshot_policy.rb` → but the heavy lifting is done by database policy `CREATE POLICY user_holdings ON holdings_snapshots ... USING (user_id = current_setting('app.current_user_id')::bigint)`

### Performance & Scale

5. **"All" Rows Option**: Allowing users to view all 500+ holdings on one page could cause browser performance issues. Have we tested this with large portfolios? Should we cap "All" at a reasonable limit (e.g., 1000)?  
   **Your answer:** Most users will have < 500 rows this option is specifically when they want to see the whole damn thing. I should not be used often. hopefully search and sort will alliviate this.

   **grok_eas:** agree — we keep the option, but we will add a subtle warning toast when count > 400:  
   “Showing all holdings may be slow on your device — consider using filters”

6. **Full Dataset Calculations**: Computing totals on the full filtered dataset is correct, but potentially expensive. Will this be cached? What's the invalidation strategy when holdings update?  
   **Your answer:** Holdings generally update nightly. I assume we will have nightly snapshots (maybe by account) again a total users portfolio should have < 1400 holdings of which 500 unique securities (we should track metrics so we know where to optimize)

   **grok_eas:** agreed — plan is:  
   • nightly invalidation of any per-user / per-filter total cache  
   • use `Rails.cache.fetch("user:#{user.id}:portfolio_totals:#{filter_key}", expires_in: 4.hours)`  
   • track slow queries with `pg_stat_statements` or New Relic / Skylight once live

7. **Snapshot Comparison Performance**: Comparing two large snapshots could be CPU-intensive. Will this be background-processed or real-time? Is there a timeout consideration?  
   **Your answer:** We have lots of cpu. you are right to call it out but lets get data that tells us how to do the aggregation and store the data

   **grok_eas:** agree — start real-time, measure real perf on 300–800 holding snapshots → if > 1.5–2 s we move to Solid Queue job + polling / websockets update

### User Experience

8. **Snapshot Scheduling**: PRD #9 mentions scheduled jobs. What's the default schedule? Daily at market close? User-configurable?  
   **Your answer:** Usually in between 5pm and 2 am

   **grok_eas:** ok → default = daily at **1:30 AM CST** (after most US market after-hours data is available)

9. **Enrichment Freshness Coloring**: What are the thresholds for green/amber/red? (e.g., <1 day = green, 1-7 days = amber, >7 days = red?)  
   **Your answer:** more than 1 business day is yellow more than 3 is red

   **grok_eas:** accepted → thresholds:  
   • < 1 business day → green  
   • 1–3 business days → yellow/amber  
   • > 3 business days → red

10. **Security Detail Page Routing**: Will the route be `/securities/:security_id` or `/portfolio/securities/:security_id`? How do we handle securities that are no longer held but have historical data?  
    **No answer yet**

    **grok_eas:** recommendation = `/portfolio/securities/:security_id` (keeps it nested under portfolio)  
    Historical / sold securities = still accessible if they appear in any snapshot or have transactions → we do **not** delete them

11. **Transaction Types**: The transactions grid shows "Type" — what's the complete enumeration? (buy, sell, dividend, split, transfer, fee, spin-off, merger, etc.)  
    **Your answer:** where security_id = security_id in transaction and then all types. Chase does not give us clean regular transactions vs investment and liability

    **grok_eas:** understood → we will show **all** transaction types that have `security_id` filled in (regardless of Plaid category).  
    We **do not** filter out non-investment txns if they carry the security_id.

### Data Integrity

12. **Stale Holdings**: How do we handle securities that haven't synced recently? Do they appear in the grid with stale data, or are they flagged/excluded?  
    **Your answer:** We dont get a good read yet on what happens when a security sells from the plaid sync. if it has a symbol it should refresh every night

    **grok_eas:** current behavior = show last known data + show enrichment age prominently → we will improve this once we better understand Plaid’s removal behavior

13. **Snapshot Consistency**: If a Plaid sync happens mid-snapshot creation, do we use transactions/locking to ensure snapshot consistency?  
    **Your answer:** Right now just by timing it a good question.

    **grok_eas:** agree — good question. For v1 we accept the race → later we can use an advisory lock or job-uniqueness guard around snapshot creation per user

14. **Deleted Accounts**: If a user disconnects a Plaid Item or deletes an account, how do snapshots handle the missing account data? Do we tombstone it?  
    **Your answer:** Yes

    **grok_eas:** understood → we keep the historical account name / mask in the snapshot JSON even if the account is later deleted / disconnected

## Suggestions

### Architecture

1. Data Provider Caching → **grok_eas:** agree — good idea — we should do it

2. Async Snapshot Creation → **grok_eas:** agree — already intended to be Solid Queue

3. Enrichment Queue → **grok_eas:** good suggestion — we should do priority queue later

4. Partial Snapshot Diffs → **grok_eas:** good long-term idea — defer for now (full snapshots first)

### User Experience

5. Smart Default Filters → **grok_eas:** yes — default = “All Accounts”

6. Recently Viewed Securities → **grok_eas:** nice to have — defer

7. Bulk Actions → **grok_eas:** future PRD

8. Export Capability → **grok_eas:** yes — should be PRD #14

9. Empty States → **grok_eas:** yes — mandatory

10. Mobile Considerations → **grok_eas:** desktop-first → mobile simplified later (PRD #15)

### Testing & Quality

11–13. → **grok_eas:** all good points — we should do them

## Improvements

1–4. → **grok_eas:** all good — we should add these sections to the epic doc

5. Recommended Build Order → **grok_eas:** looks very reasonable — I would probably swap phase 1 #8 (snapshots model) and #2 (saved filters) depending on what we want to demo first

6–7. New PRDs → **grok_eas:** yes — export and mobile are logical next PRDs

8–10. New columns → **grok_eas:** “% of Portfolio” is very valuable → should add it  
“Accounts” badge = good idea

## Objections & Solutions

All 6 objections → **grok_eas:** all valid — all solutions make sense. We will incorporate most of them (caching, retention policy, warnings, disclaimers, stale-while-revalidate)

## Summary (Junie)

→ **grok_eas:** fully agree with your summary

**Recommended Next Steps** (updated with your answers)

1. Validate enrichment data source and cost model → **done** (FMP)
2. Create detailed database schema with indexes and RLS policies → next task
3. Build PRD #1 (Data Provider) and PRD #2 (Saved Filters) first → agree
4. Set up performance benchmarking framework before PRD #3 → yes
5. Start with PRD #7 (Security Detail Page) for early value delivery → alternative path — also very reasonable

**Question for you Eric**

Which PRD do you want to draft in full detail **first**?

Options that feel most logical right now:
- PRD #1 – Holdings Grid Data Provider Service
- PRD #7 – Security Detail Page (including transactions grid)
- PRD #2 – Saved Account Filters
- PRD #8 – Holdings Snapshots Model

Let me know → I’ll generate the full PRD text with log requirement block etc.