### Epic 0: Immediate Quick Wins (Unblock Real Usage)

**Overview**  
Three ultra-small, zero-risk tasks that make the app feel alive and usable today—zero new models, zero external calls, pure UI polish. Removes the biggest friction points before any real user touches it.

**User Capabilities**
- Intern clicks retry and sees sync spin again instead of staring at red error.
- Connect button says exactly what it does—no confusion.
- Chat stays hidden until real data exists (no "ask me anything" tease on empty state).

**Fit into Big Picture**  
Gets us to "holy shit, it works with my real Schwab" in under 15 minutes of code—critical for momentum and early feedback.

**Potential PRD Table**  
| Priority | PRD Title                  | Scope                                      | Dependencies       | Suggested Branch              |
|----------|----------------------------|--------------------------------------------|--------------------|-------------------------------|
| 1        | Retry Button on Failed Sync| DaisyUI button → re-enqueue sync job       | Existing sync status UI | feature/epic0-retry-button    |
| 2        | Clear Plaid Connect Label  | Change text to “Add Bank or Brokerage”     | Plaid Link button  | feature/epic0-connect-label   |
| 3        | Gate Chat Until Accounts   | Hide chat route/component if PlaidItem.none? | Devise + PlaidItem | feature/epic0-gate-chat       |

### Epic 1: Rock-Solid Plaid Data Foundation

**Overview**  
Normalize, deduplicate, validate, and enrich every piece of data that comes from Plaid across investments, transactions, liabilities, and enrichment endpoints for JPMC, Schwab, Amex, and Stellar. This is the unbreakable layer—everything else (dashboards, advisor, curriculum) fails if this lies.

**User Capabilities**
- Interns see one clean position list—no duplicate Apple shares.
- Sync status + last-updated everywhere.
- Admins force re-sync or exclude accounts per child.
- Anomalies auto-flagged (negative balances, missing securities).

**Fit into Big Picture**  
Without this, the AI tutor hallucinates or gives wrong advice on real $20-50M portfolios—trust dies instantly.

**Potential PRD Table** (updated with your earlier notes)  
| Priority | PRD Title                          | Scope                                                                 | Dependencies                  | Suggested Branch                     |
|----------|------------------------------------|-----------------------------------------------------------------------|-------------------------------|--------------------------------------|
| 1        | Normalization & Deduplication      | Service to clean security IDs, names, dedupe positions/transactions  | Existing models               | feature/prd-1-normalization          |
| 2        | Account Extensions                 | Add `strategy` column + ensure balances sync                          | #1                            | feature/prd-1-account-extensions     |
| 3        | OtherIncome Model                  | User-scoped table: name, date, projected/accrued, amount, tax_rate   | User                          | feature/prd-1-other-income           |
| 4        | Identify Always-Null Plaid Fields  | Audit job → log fields we never get                                   | Plaid syncs                   | feature/prd-1-null-fields            |
| 5        | Remote Job Health Check            | Endpoint + admin view for 192.168.4.253 worker                        | Solid Queue                   | feature/prd-1-job-health             |
| 6        | Account Sharing/Exclusion          | Parent/admin UI + RLS to hide accounts per child                      | RLS setup                     | feature/prd-1-account-sharing        |
| 7        | Manual Re-Sync Controls            | Full/partial re-sync with retry logic                                 | #1-#6                         | feature/prd-1-manual-resync          |
| 8        | Enrichment Consistency             | Consistent /transactions/enrich calls                                 | Enrichment endpoint           | feature/prd-1-enrichment             |

### Epic 2: Daily FinancialSnapshotJob (Current Version from Repo)

**Overview**  
Nightly job (3am via Solid Queue recurring) aggregates current state into an encrypted JSON blob stored on the User—net worth, allocation buckets, key aggregates only. Explicitly no historical trends or period-over-period math here—that lives in filtered queries later.

**User Capabilities**
- Advisor always has instant context without hitting DB.
- Dashboards read one file instead of 10 queries.
- Exportable for offline review or human CFP.

**Fit into Big Picture**  
Turns expensive real-time calculations into cheap reads—essential for responsive chat and future Python simulators.

**Potential PRD Table** (lean version per latest repo file)  
| Priority | PRD Title                  | Scope                                           | Dependencies       | Suggested Branch                |
|----------|----------------------------|-------------------------------------------------|--------------------|---------------------------------|
| 1        | Snapshot Job Skeleton      | 3am recurring, aggregate to encrypted JSON      | Sync jobs          | feature/epic2-snapshot-job      |
| 2        | Core Aggregates            | Net worth, allocation %, account totals         | #1                 | feature/epic2-core-aggregates   |
| 3        | Storage & Retrieval API    | attr_encrypted blob, controller to serve latest | PostgreSQL         | feature/epic2-storage           |

### Epic 3: Net Worth Dashboard (Current Version from Repo)

**Overview**  
Professional, mobile-first dashboard that reads only from the latest FinancialSnapshot blob—no live Plaid calls, no calculations in the view. Hero card + allocation pie + top holdings table.

**User Capabilities**
- One glance: total NW + MoM arrow.
- Clean pie chart (static from blob).
- Mobile collapses to single column.

**Fit into Big Picture**  
First “aha” moment—intern sees their real money rendered beautifully, instantly trusts the system.

**Potential PRD Table**  
| Priority | PRD Title                  | Scope                                           | Dependencies       | Suggested Branch                |
|----------|----------------------------|-------------------------------------------------|--------------------|---------------------------------|
| 1        | Net Worth Hero Card        | Total + change arrow, from snapshot             | Epic 2             | feature/epic3-hero-card         |
| 2        | Allocation Pie (Static)    | DaisyUI + Chart.js pie from blob                | #1                 | feature/epic3-allocation-pie    |
| 3        | Dashboard Layout           | Sidebar stub, mobile-first, empty states        | Tailwind setup     | feature/epic3-layout            |

### Epic 4: AI Financial Advisor Chat

**Overview**  
Real-time ActionCable chat that injects the latest FinancialSnapshot JSON as context to local Ollama (Llama 3.1 70B/405B via AiFinancialAdvisor service). Grounded responses only—never guesses numbers.

**User Capabilities**
- Ask “What’s my tax drag?” → gets real answer from data.
- Ask “Why did NW drop?” → sees transaction list.
- Markdown + disclaimers rendered in bubbles.

**Fit into Big Picture**  
Core delivery of the entire vision—personal CFP simulation for the next generation.

**Potential PRD Table**  
| Priority | PRD Title                  | Scope                                           | Dependencies              | Suggested Branch                |
|----------|----------------------------|-------------------------------------------------|---------------------------|---------------------------------|
| 1        | Chat UI + ActionCable      | DaisyUI bubbles, real-time send/receive         | Hotwire                   | feature/epic4-chat-ui           |
| 2        | Context Injection Service   | Attach latest snapshot + static docs to prompt  | Epic 2                    | feature/epic4-context           |
| 3        | Response Rendering         | Markdown, charts via MMS, disclaimers           | #1                        | feature/epic4-rendering         |
| 4        | Channel Awareness          | Tag messages web vs text (for Epic 7/8)         | Epic 7/8                  | feature/epic4-channel           |

Here are detailed breakdowns for Epics 6–10, consistent with the style and depth used for 0–5. All draw from our established project direction (Plaid-first stability, snapshot reliance, Tailwind/DaisyUI/ViewComponent UI, local Ollama, privacy via attr_encrypted/RLS). No repo files appear committed yet for these specific epics' content (knowledge_base/epics/ exists but lacks visible per-epic md files for 6–10; recent reorganization focused on PRDs → completed and jobs data, with UI/admin touches like Solid Queue dashboard in commits ~13 hours ago). Planning remains chat-grounded.
**Epic 5: Date and Account Filtering on Net Worth Views**

**Overview**  
Adds interactive filters for time periods (e.g., last 3/6/12 months, custom range) and specific accounts/institutions (e.g., Schwab only, exclude Amex card) to dashboard views, queries, and snapshots. Backend dynamically subsets FinancialSnapshot data or re-filters historical aggregates without full re-syncs.

**User Capabilities**
- Intern selects date range or institutions → dashboard refreshes instantly with filtered NW total, allocation pie, and trends.
- Filters persist across sessions (stored on User or session).
- Advisor chat inherits filters for context-aware answers (e.g., "Schwab last 6 months shows drift").
- Clear/reset button; mobile dropdowns.

**Fit into Big Picture**  
Enables targeted analysis for curriculum exercises like seasonal tax impacts, institution performance, or "what if I exclude credit cards"—makes personal data actionable without overwhelming the full view.

**Architectural Context**
- Rails MVC: Filters in controller params → service subsets JSON snapshot or queries with scopes.
- PostgreSQL: RLS for user scoping; attr_encrypted on snapshots.
- Dependencies: Epic 2 (snapshots), Epic 3 (dashboard).
- UI: DaisyUI dropdowns + calendar picker; ViewComponent filter bar.
- Privacy: Local filtering only; no external calls.

**Log Requirements**  
Junie read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` before starting.

**PRD Summary (Atomic Breakdown)**  
| Priority | PRD Title                        | Scope (one focused feature)                                   | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|---------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Date Range Filter Component      | UI: presets (last 30/90/180/365, YTD, custom) + calendar picker | Epic 3 UI                 | feature/epic5-date-filter-ui         |
| 2        | Account/Institution Multi-Select | UI: dropdown of linked accounts/institutions; multi-select    | Account model, Epic 1     | feature/epic5-account-selector       |
| 3        | Filter Persistence & Defaults    | Store in User preferences jsonb; apply on load                | User model                | feature/epic5-persistence-defaults   |
| 4        | Filtered Snapshot Query Service  | Backend service: subset JSON (NW, allocation, totals) by params | Epic 2 snapshots          | feature/epic5-filtered-query-service |
| 5        | Dashboard Filter Integration     | Apply filters to hero card/pie/trends; reset button           | #1–4                      | feature/epic5-dashboard-apply        |
| 6        | Chat Context Injection           | Add current filters to Ollama prompt                          | Epic 4                    | feature/epic5-chat-context           |

**Acceptance Criteria (for whole Epic)**
- Filters visible on dashboard top bar; apply changes visible in <1s.
- "Schwab only" excludes other accounts from totals/pie.
- "Last 90 days" shows correct subset NW/change.
- Filters persist after logout/login.
- Chat prompt logs include filter context.
- Reset returns to full view.
- Mobile: filters usable without overflow.
- No unnecessary DB hits or re-syncs.

**Developer Guidance**
- Start with PRD 1 (UI component) – mock data first.
- Claude Sonnet 4.5 default for any spec questions.
- Workflow: pull master → new branch → plan/ask questions → green commits only.


Want the full markdown block for insertion, or move to Epic 6 / another? Or start a specific PRD from here?
### Epic 6: Charting Integration (Dashboard & Advisor)

**Overview**  
Embed lightweight, interactive Chart.js visualizations (trend lines, allocation pies/bars, performance breakdowns) directly into the net worth dashboard and advisor chat responses, always sourced from FinancialSnapshot blobs. Makes abstract financial concepts tangible and supports curriculum on trends, allocation drift, and risk without real-time heavy lifting.

**User Capabilities**
- Interns see dynamic net worth trend over selected date range (from filtered snapshot).
- Allocation pie updates on account filter change.
- Advisor can reference/embed mini-charts in responses (e.g., "Your tech exposure is 42%—here's the pie").
- Mobile-responsive; no overwhelming animations.

**Fit into Big Picture**  
Visuals anchor education—young adults remember charts better than numbers, grounding AI advice in personal data for deeper engagement on investing/tax risk.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Chartkick + Chart.js Setup       | Gem install, basic line/pie helpers, asset pipeline integration      | Tailwind/DaisyUI          | feature/epic6-chartkick-setup        |
| 2        | Net Worth Trend Line             | Historical NW series from snapshot (filtered by date/account)         | Epic 2, Epic 5            | feature/epic6-trend-line             |
| 3        | Allocation Pie/Bar               | Static breakdown buckets (equities/fixed income/etc.) from snapshot   | Epic 2                    | feature/epic6-allocation-visual      |
| 4        | Chat Chart Embed                 | Advisor response includes chart JSON → frontend renders or MMS image  | Epic 4, Epic 7/8          | feature/epic6-chat-embed             |
| 5        | Mobile Responsiveness & Themes   | Ensure charts adapt (resize, dark mode support)                       | Epic 12                   | feature/epic6-responsive             |

### Epic 7: Notification System

**Overview**  
Build a unified, low-friction notification layer starting with in-app DaisyUI toasts, with opt-in outbound SMS/MMS via Twilio for sync events, insights, and proactive alerts. Channel-aware (web vs text) and respects quiet hours/preferences stored on User.

**User Capabilities**
- Instant toast on sync complete/fail, big deposit, allocation drift >10%.
- Settings toggle: in-app only / +text (collect cell number with validation).
- Advisor can push messages (text or MMS chart).
- Inbound text routes to chat queue for advisor response.

**Fit into Big Picture**  
Proactive nudges keep interns engaged between sessions—reinforces timely habits without requiring app opens, fitting mobile-first young adult behavior.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Notification Model + Preferences | Notification model, user.cell + jsonb preferences (in_app/sms/quiet)  | User, phony gem           | feature/epic7-model-preferences      |
| 2        | In-App Toast Delivery            | Turbo Stream + DaisyUI toast component for web channel                | Hotwire                   | feature/epic7-web-toasts             |
| 3        | Twilio Outbound (SMS/MMS)        | Service object, buy/use 713 number, send text or image URL            | twilio-ruby, human Twilio setup | feature/epic7-twilio-outbound        |
| 4        | Channel-Aware Queue & Routing    | Stamp channel on messages; advisor logic branches (embed vs MMS)      | Epic 4                    | feature/epic7-channel-routing        |
| 5        | Inbound Text Webhook             | Twilio webhook → create message record → route to advisor queue       | #3                        | feature/epic7-inbound-text           |
| 6        | Opt-In, Quiet Hours & Consent    | Form for number/verification, cron to mute SMS during quiet hours     | #1                        | feature/epic7-consent-hours          |

### Epic 8: Inbound/Outbound Text Capabilities

**Overview**  
Extend advisor interaction to mobile via Twilio MMS (preferred for charts/images) and SMS fallback, fully integrated with chat context and notification system. Inbound texts trigger advisor responses; outbound supports quick alerts or follow-ups.

**User Capabilities**
- Text "What's my NW?" → advisor replies with number or MMS snapshot/chart.
- Receive proactive MMS on maturity or drift.
- Opt-in flow ensures consent; "STOP" unsubscribes.
- Seamless handoff: long threads push "Open app for full view".

**Fit into Big Picture**  
Mobile extension matches how 22–30-year-olds actually engage—quick texts for on-the-go questions/alerts, keeping education accessible beyond desktop.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Twilio Number & MMS Config       | Buy/configure 713 local number, enable MMS in Messaging Service       | Human Twilio setup        | feature/epic8-twilio-config          |
| 2        | Inbound Webhook & Parsing        | Receive → verify signature → create Message record (channel: text)    | twilio-ruby               | feature/epic8-inbound-webhook        |
| 3        | Outbound Advisor Responses       | From chat queue: send SMS text or MMS image/chart                     | Epic 4, Epic 7            | feature/epic8-outbound-advisor       |
| 4        | Consent & Opt-Out Flow           | Initial "yes" flag, handle STOP/HELP keywords                         | User model                | feature/epic8-consent-optout         |
| 5        | Fallback & Rate Limiting         | Queue outbound if rate-limited; SMS fallback if MMS fails             | #1                        | feature/epic8-fallback-limits        |

### Epic 9: JPMC Quarterly Meeting Review Page

**Overview**  
Dedicated page with structured prompts/questions tailored to JPMC accounts (benchmarking, fees/taxes, allocation review, performance vs goals). Auto-populates from snapshots/transactions for prep.

**User Capabilities**
- Intern loads page → sees pre-filled answers (e.g., "Fees this quarter: $4,200").
- Advisor generates narrative responses to fixed questions via Ollama.
- Export/print for actual meeting.
- Flags anomalies (high fees, drift).

**Fit into Big Picture**  
Simulates real HNW quarterly rituals—prepares interns for banker meetings with data confidence, bridging education to real-world action.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Quarterly Review Page Layout     | ViewComponent form + sections for questions/responses                 | Epic 3, Epic 12           | feature/epic9-review-layout          |
| 2        | JPMC-Specific Data Filtering     | Snapshot query filtered to JPMC PlaidItems/accounts                   | Epic 2, Epic 5            | feature/epic9-jpmc-filter            |
| 3        | Prompt-Based Auto-Answers        | Ollama generates responses to predefined questions using snapshot     | Epic 4                    | feature/epic9-prompt-answers         |
| 4        | Export & Print Support           | PDF export or printable view (Prawn or browser print)                 | #1                        | feature/epic9-export                 |

### Epic 10: Admin & Mission Control Reorganization

**Overview**  
Revamp admin dashboard/Mission Control into a unified, modern cockpit with real-time sync monitoring, user stats, health metrics, and quick actions. Consolidates scattered views for efficient ops.

**User Capabilities**
- Admins see sync success/failure rates, last run times, anomalies.
- User list with linked accounts, last login, notification prefs.
- Quick buttons: force sync, exclude account, view logs.
- Solid Queue dashboard integration for job health.

**Fit into Big Picture**  
Scales internship program ops with privacy/control—admins spot issues fast without digging through logs.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Admin Sidebar & Navigation       | Unified menu with role-based links (Pundit if needed)                 | Epic 12                   | feature/epic10-admin-sidebar         |
| 2        | Sync Monitoring Table            | Real-time table: PlaidItem status, last sync, errors                  | Plaid sync jobs           | feature/epic10-sync-table            |
| 3        | User & Data Health Dashboard     | Aggregated stats (accounts linked, NW coverage, anomalies)            | Epic 1, Epic 2            | feature/epic10-health-dashboard      |
| 4        | Solid Queue Admin Integration    | Embed/iframe Solid Queue dashboard in admin                           | Solid Queue gem           | feature/epic10-solid-queue           |
| 5        | Quick Actions & Logs             | Buttons for re-sync/exclude; searchable logs view                     | #2                        | feature/epic10-actions-logs          |

### Epic 11: Task Management System (Kanban Board)

**Overview**  
Simple Kanban-style board integrated with advisor chat for natural-language task creation, assignment, update, and tracking. Tasks are stored as artifacts (type: task) with status columns (To Do, Doing, Done) for curriculum delivery.

**User Capabilities**
- Advisor says “Assign Monte Carlo on portfolio” → task card appears on board.
- Intern drags cards, adds comments/blockers.
- Progress auto-updates (e.g., sync complete → 100%).
- Advisor closes via chat; notifications on changes.

**Fit into Big Picture**  
Structures education as actionable steps—turns AI suggestions into trackable homework, building discipline for HNW habits.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Task Artifact Model & Status     | Artifact type: task; status enum (To Do/Doing/Done); parent_id link  | Artifacts table           | feature/epic11-task-model            |
| 2        | Kanban Board UI                  | ViewComponent columns + drag/drop (Stimulus + Hotwire)                | Epic 12                   | feature/epic11-kanban-ui             |
| 3        | Natural Language Task Creation   | Parse chat → create/update task artifact                              | Epic 4                    | feature/epic11-nl-commands           |
| 4        | Assignment & Notifications       | Assign to user; toast/SMS on change                                   | Epic 7                    | feature/epic11-assignment-notifs     |
| 5        | Progress & Commenting            | Auto-progress from jobs; rich comments (ActionText)                   | #1                        | feature/epic11-progress-comments     |

### Epic 12: General Navigation and UI Patterns

**Overview**  
Establishes app-wide consistent navigation (sidebar/topbar), UI components (cards, modals, buttons), and responsive rules using Tailwind + DaisyUI + ViewComponent. Professional, adult-oriented design—no kid-friendly elements.

**User Capabilities**
- Role-based sidebar (intern vs admin vs parent).
- Consistent cards/modals/buttons across pages.
- Mobile-first: collapses gracefully.
- Dark mode basics and empty/error states.

**Fit into Big Picture**  
Reduces cognitive load for financial novices—makes the app feel reliable and trustworthy for sustained engagement.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Global Layout & Sidebar          | App shell + role-based menu (Devise current_user)                     | Devise                    | feature/epic12-global-layout         |
| 2        | Standard Component Library       | ViewComponents for cards, modals, buttons, tables                     | Tailwind/DaisyUI          | feature/epic12-component-lib         |
| 3        | Responsive & Theming Rules       | Mobile-first, dark mode toggle, breakpoints                           | #1                        | feature/epic12-responsive-theming    |
| 4        | Empty-State & Error Patterns     | Reusable empty states, error toasts, 404 page                         | #2                        | feature/epic12-empty-error           |

### Epic 13: Multi-Source Income Projection Engine

**Overview**  
Nightly job projects 12-month cash flow from dividends (FMP), bond coupons/maturities (parsed + FMP), and manual private credit yields, tax-adjusted and stored in snapshots. Broken out by category (dividends/bonds/credit) with monthly runway.

**User Capabilities**
- Dashboard shows projected monthly total + breakdown.
- Advisor references “Dividends cover mortgage, bonds mature in Q2”.
- Flags low buffer vs expenses.
- Manual overrides for private credit.

**Fit into Big Picture**  
Gives forward visibility on recurring income—critical for curriculum on cash flow, taxes, and planning to avoid "shirtsleeves" traps.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Dividend Forecast (FMP)          | Nightly /historical-dividend + analyst growth; multiply shares        | FMP API, Epic 2           | feature/epic13-dividend-forecast     |
| 2        | Bond Coupon & Maturity Projection| Parse desc/CUSIP; FMP lookup; bucket by type (Treasury/muni/corp)     | Security model            | feature/epic13-bond-projection       |
| 3        | Private Credit Manual Yield      | Add field to Position; flat projection                                | Position model            | feature/epic13-private-credit        |
| 4        | Snapshot Integration & Tax Adjust| Rollup to monthly fields + effective rate from User                   | Epic 2                    | feature/epic13-snapshot-rollup       |
| 5        | Advisor Flags & Runway           | Low buffer alert; 5% safety margin                                    | Epic 4                    | feature/epic13-advisor-flags         |

### Epic 14: Quarterly Estimated Tax Planner

**Overview**  
Estimator ingests prior-year return (manual key lines or simple parse) and projects quarterly payments based on current income projections, avoiding safe-harbor overpayment. Flags brackets, conversions, or due dates.

**User Capabilities**
- Upload/enter return → see "Pay $87K by April 15".
- Advisor warns "You're under—skip July?"
- Tracks actual vs projected.
- No IRS API—local only.

**Fit into Big Picture**  
Prevents tax surprises for HNW families—educates on timing and brackets, tying to income projections for real-world planning.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Tax Return Upload & Key Lines    | Form for manual entry (AGI, tax, cap gains); optional simple parse    | User model                | feature/epic14-return-upload         |
| 2        | Quarterly Projection Calc        | Apply brackets to income from Epic 13; split into 4 payments          | Epic 13                   | feature/epic14-quarterly-calc        |
| 3        | Dashboard/Advisor Integration    | Display due dates + flags; advisor references in chat                 | Epic 3, Epic 4            | feature/epic14-integration           |
| 4        | Safe-Harbor vs Actual Toggle     | Option to override with last-year safe-harbor                         | #2                        | feature/epic14-safe-harbor           |

### Epic 15: Real-Time Stock Lookup via FMP

**Overview**  
On-demand /quote endpoint lookup in chat or dashboard for live price, target, volume on any holding ticker. Cached 30 seconds per user; rate-limited.

**User Capabilities**
- Chat “AAPL price?” → instant quote.
- Advisor pulls live for context (“AAPL up 2% today”).
- No nightly wait—feels responsive.

**Fit into Big Picture**  
Provides immediate market context for advisor responses—enhances trust without relying on stale syncs.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | FMP Stock Quote Service          | HTTP client to /quote/{ticker}; cache 30s                             | FMP API                   | feature/epic15-fmp-service           |
| 2        | Chat & Dashboard Integration     | Input field or command → display price/target                         | Epic 4, Epic 3            | feature/epic15-integration           |
| 3        | Rate Limiting & Error Handling   | Per-user throttle; fallback to last sync price                        | #1                        | feature/epic15-limits-errors         |

Ready for 16–18 next? Or prioritize any PRD here?

### Epic 16: Market News Feed

**Overview**  
Pulls hourly market news headlines from RSS (e.g., Reuters, Alpha Vantage) or API, summarizes to one-sentence via Ollama, and displays as a small top-right card on the dashboard. Provides light real-world context without deep analysis—advisor can reference it for grounded responses.

**User Capabilities**
- Dashboard shows one-line summary: "Fed held rates—bonds up 8 bps."
- Advisor pulls from feed in chat: "Markets dipped on Powell comments."
- Updates every hour via background job; no push notifications.
- Dismissable or hidden if quiet mode on.

**Fit into Big Picture**  
Gives advisor non-hallucinated market pulse—helps explain portfolio moves or advise on timing without external searches.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | RSS/Feedjira Integration         | Gem install, nightly/hourly job to fetch Reuters or Alpha Vantage RSS | feedjira gem              | feature/epic16-feed-fetch            |
| 2        | Ollama Summary Service           | One-sentence summary prompt; cache in DB or snapshot                  | Local Ollama              | feature/epic16-ollama-summary        |
| 3        | Dashboard News Card              | DaisyUI card top-right; auto-refresh or on load                       | Epic 3, Epic 12           | feature/epic16-news-card             |
| 4        | Advisor Reference Hook           | Feed context injected into chat prompts if relevant                   | Epic 4                    | feature/epic16-advisor-hook          |

### Epic 17: Agentic PRD Drafter – Spike

**Overview**  
Tests if local Llama (default: Claude Sonnet 4.5 fallback) can draft usable atomic PRDs from natural goals using artifacts, context hints, and minimal RAG (chat history + templates + schema). Starts with epic artifact → decompose → one or few child PRDs; human approves.

**User Capabilities**
- Say “add retry button” → agent creates epic artifact with context_hint.
- Spawns 1-3 PRD drafts (markdown) with title, scope, branch.
- Self-checks against 7 questions (goal, deps, models, atomicity, etc.).
- Verdict: "usable" or "decompose further".

**Fit into Big Picture**  
Proves scalable PRD generation—reduces manual refinement, speeds feature delivery while keeping human in loop for quality.

**Potential PRD Table** (spike-focused)  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Minimal RAG Researcher           | Script/service: pull chat + schema + templates based on goal keywords | Ollama                    | spike/epic17-prd1-rag-researcher     |
| 2        | Epic Artifact Creation           | Create artifact (type: epic) with context_hint JSONB                  | Artifacts table           | spike/epic17-prd2-epic-artifact      |
| 3        | Decompose & Draft Loop           | Answer 7 questions → generate 1-3 PRD markdowns                       | #1, #2                    | spike/epic17-prd3-decompose-draft    |
| 4        | Validation & Output              | Self-check hallucinations; output drafts for human review             | #3                        | spike/epic17-prd4-validate-output    |
| 5        | Test on Retry Button             | End-to-end spike run on "retry sync button" story                     | Existing sync UI          | spike/epic17-prd5-test-case          |

**Developer Note**: Use Claude Sonnet 4.5 as default for drafting accuracy; switch to Grok 4.1 if hallucination spikes.

### Epic 18: Natural-Language Epic Creation via Agent Hub

**Overview**  
Enables in-chat command "create epic: X" → stores as artifact (type: epic) with context_hint JSONB and summary_prds array. Auto-spawns linked child PRD artifacts; epics become top-level context vehicle for decomposition.

**User Capabilities**
- Type goal → get epic artifact + child PRDs.
- Context_hint auto-filled (vision, assumptions, deps).
- PRDs inherit parent hint for grounded drafts.
- Hierarchy visible in admin or console.

**Fit into Big Picture**  
Makes goal intake agentic—epics structure the backlog, PRDs stay atomic; scales curriculum/feature dev without manual files.

**Potential PRD Table**  
| Priority | PRD Title                        | Scope                                                                 | Dependencies              | Suggested Branch                     |
|----------|----------------------------------|-----------------------------------------------------------------------|---------------------------|--------------------------------------|
| 1        | Epic Artifact & Context Hint     | Migration: add context_hint jsonb; service to create from prompt      | Artifacts table           | feature/epic18-epic-artifact         |
| 2        | Summary PRDs Array               | Decompose goal → store short sentences in content.summary_prds        | #1                        | feature/epic18-summary-prds          |
| 3        | Child PRD Artifact Spawning      | Auto-create prd artifacts with parent_id and inherited hint           | #1                        | feature/epic18-child-spawn           |
| 4        | Context Inheritance in Generation| PRD draft prompt includes parent context_hint                         | Ollama                    | feature/epic18-inheritance           |
| 5        | Hub Command & UI Stub            | Chat command parser; basic list view of epics/PRDs                    | Epic 4                    | feature/epic18-hub-command           |

Ready for next steps? Want to prioritize any (e.g., spike Epic 17 first) or review repo for updates?
