Here is a narrative draft of all 12 epics (including the new Epic 12 for general navigation and UI patterns). Each is presented in structured narrative form with:

- **Epic Overview**: A concise description of the epic's purpose.
- **User Capabilities**: What interns (primary users, young adults 22-30), financial advisors (AI-simulated or human), and admins can do.
- **Fit into Big Picture**: How it advances the vision of AI-driven financial education for HNW families (ending "shirtsleeves to shirtsleeves" cycle via practical, data-grounded curriculum on money, investing, taxes, trusts, philanthropy, etc.), while prioritizing Plaid sync stability before advanced UI.

At the end of each epic, I've included a **Potential PRD Table** — a high-level breakdown of atomic, implementable PRDs (in priority order within the epic) that Junie could tackle sequentially. These are scoped atomically per guidelines (one focused feature per PRD), with suggested branch naming and dependencies. No full PRDs generated yet — only when requested.

**Epic 1: Ensure Plaid Data is Consistent and Well Organized**  
**Epic Overview**: Establish reliable, normalized, and deduplicated data models and sync processes for Plaid products (investments, transactions, liabilities, enrichment) from JPMC, Schwab, Amex, and Stellar, with validation rules, error recovery, and consistent enrichment.  
**User Capabilities**: Interns view clean, deduplicated account/position/transaction views without duplicates or stale data; trigger manual re-syncs; see sync status and last-updated timestamps. Advisors (AI) query accurate underlying data. Admins monitor consistency logs and force re-normalization.  
**Fit into Big Picture**: Forms the unbreakable data foundation — without consistent Plaid sync, all downstream education (allocation analysis, tax planning, benchmarking) risks inaccuracy or hallucination, undermining trust in the AI tutor for real HNW scenarios.
** extend the account model to inclde a strategy field 
** Ensure balances for each account are retrieved when we sync
** add a table wich holds other income scoped to a user it should have name, date , projected vs accrude income, amount and tax suggested tax rate). the table is used in the fancial snapshow to ensure we have income from sources outside plaid account 
** identify fields that are always null in our plaid data
** ensure that we are retrieving plad data for investment/transactions 
** ensure that a job is running on 192.168.4.253 that will perform plaid job functions and that we have a health check for it in admin
** create a mechanism to the administrator and teh Parrent can share and exclude accounts from a give users ( childs ) scope .

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Data Normalization & Deduplication Service | Normalize Plaid responses (e.g., security IDs, account types); dedupe positions/transactions | Existing PlaidItem/Account/Position/Transaction models | feature/prd-1-normalization-service |
| 2 | Consistency Validation Job | Background job to detect anomalies (e.g., negative balances, mismatched totals) and log/alert | #1 | feature/prd-2-consistency-validation |
| 3 | Manual Re-Sync & Recovery Controls | Owner/intern-initiated full or partial re-sync with retry logic | Existing sync jobs | feature/prd-3-manual-resync |
| 4 | Enrichment Consistency Rules | Apply Plaid /transactions/enrich consistently; store derived fields | Plaid enrichment endpoint support | feature/prd-4-enrichment-rules |

**Epic 2: Build JSON Snapshots to Support Net Worth Dashboards**  
**Epic Overview**: Implement daily/periodic FinancialSnapshotJob that exports structured JSON blobs capturing net worth, period-over-period changes, asset allocation breakdowns, and key aggregates from synced Plaid data.  
**User Capabilities**: Interns download/export personal snapshots; advisors (AI) ingest snapshots as RAG context for queries; admins preview/validate snapshot generation.  
**Fit into Big Picture**: Turns raw syncs into portable, queryable financial context — essential for curriculum modules on net worth tracking, allocation drift, and historical performance without real-time computation overload.

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Daily FinancialSnapshotJob Skeleton | Job runs at 3am; aggregates net worth/allocation to JSON | Existing sync jobs | feature/prd-2-snapshot-job |
| 2 | Period Summary Calculations | Compute MoM/YoY changes, category totals | #1 | feature/prd-2-period-summaries |
| 3 | Asset Allocation Breakdown | Bucket by security type/class (equities, fixed income, etc.) | Plaid holdings data | feature/prd-2-allocation-breakdown |
| 4 | Snapshot Storage & Retrieval | Store JSON blobs encrypted; API/controller for access | PostgreSQL + attr_encrypted | feature/prd-2-snapshot-storage |

**Epic 3: Build the UI for Net Worth Dashboards**  
**Epic Overview**: Create clean, professional dashboard pages showing net worth summary, breakdowns, and trends using Tailwind + DaisyUI + ViewComponent.  
**User Capabilities**: Interns view aggregated and categorized net worth; see high-level metrics/cards.  
**Fit into Big Picture**: Provides the first visual "aha" moment for interns engaging with their real financial data, grounding abstract education in personal context.

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Net Worth Summary Card Component | Hero card with total NW + change | Epic 2 snapshots | feature/prd-3-nw-summary-card |
| 2 | Allocation Pie/Bar View | Static breakdown display | #1 + allocation data | feature/prd-3-allocation-view |
| 3 | Dashboard Layout & Navigation Stub | Main dashboard route with sidebar stub | Devise + Tailwind setup | feature/prd-3-dashboard-layout |

**Epic 4: Build the Chat Page for the Financial Advisor**  
**Epic Overview**: Develop a dedicated chat interface that feeds local Ollama (AiFinancialAdvisor) with snapshot context for grounded, curriculum-aligned responses.  
**User Capabilities**: Interns ask natural-language questions about their finances; receive data-backed answers.  
**Fit into Big Picture**: Core delivery mechanism for AI tutor — simulates CFP interactions on investing, taxes, philanthropy using personal data.

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Chat Page UI + WebSocket | Real-time chat with DaisyUI bubbles | ActionCable setup | feature/prd-4-chat-ui |
| 2 | Context Injection Service | Attach latest snapshot to Ollama prompts | Epic 2 | feature/prd-4-context-injection |
| 3 | Advisor Response Rendering | Markdown + disclaimers in chat | #1 | feature/prd-4-response-render |

**Epic 5: Incorporate Filtering by Date and Account into Net Worth**  
**Epic Overview**: Add interactive filters for time periods and accounts/institutions on dashboard views.  
**User Capabilities**: Interns slice data (e.g., "Schwab last 6 months"); refresh views dynamically.  
**Fit into Big Picture**: Enables targeted analysis for curriculum exercises (e.g., seasonal tax impacts, institution-specific performance).

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Date Range Filter Component | Dropdown/calendar picker | Epic 3 UI | feature/prd-5-date-filter |
| 2 | Account/Institution Selector | Multi-select dropdown | Account model | feature/prd-5-account-filter |
| 3 | Filtered Snapshot Query | Backend service to subset JSON | Epic 2 | feature/prd-5-filtered-query |

**Epic 6: Incorporate Charting into Net Worth Dashboard and Financial Advisor**  
**Epic Overview**: Embed lightweight charts (Chart.js) for trends, allocation, and performance visuals in dashboard and chat embeds.  
**User Capabilities**: Interns see interactive charts; chat can reference/embed visuals.  
**Fit into Big Picture**: Makes financial concepts visual and memorable, supporting education on trends and risk.

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Net Worth Trend Line Chart | Historical NW over time | Epic 5 filters | feature/prd-6-trend-chart |
| 2 | Allocation Pie Chart | Dynamic pie from allocation data | Epic 2 | feature/prd-6-pie-chart |
| 3 | Chart Embed in Chat | Render chart images/JSON in responses | Epic 4 | feature/prd-6-chat-embed |

**Epic 7: Incorporate Notification System into NextGen Plaid**  
**Epic Overview**: Build in-app (toast) and optional email/SMS notifications for sync events, insights, or alerts.  
**User Capabilities**: Interns receive proactive updates (e.g., "Sync complete", "Allocation drift detected").  
**Fit into Big Picture**: Keeps interns engaged between sessions, reinforcing timely financial awareness.

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | In-App Toast Notification Service | Rails + Hotwire for toasts | Existing dashboard | feature/prd-7-inapp-toasts |
| 2 | Notification Preferences Model | User opt-in/out | Devise User | feature/prd-7-preferences |
| 3 | Sync Completion Alerts | Trigger on job finish | Plaid sync jobs | feature/prd-7-sync-alerts |

**Epic 8: Incorporate Inbound and Outbound Text Capabilities into NextGen**  
**Epic Overview**: Add advisor-aware SMS (Twilio or similar) for quick queries/alerts, integrated with chat context.  
**User Capabilities**: Interns text questions; receive responses or alerts via SMS.  
**Fit into Big Picture**: Extends education to mobile, fitting young adults' habits for on-the-go learning.

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | SMS Inbound Webhook | Receive texts → route to chat | Twilio setup (human step) | feature/prd-8-sms-inbound |
| 2 | Outbound Advisor Response | Send chat answers via SMS | Epic 4 + #1 | feature/prd-8-outbound |
| 3 | Opt-In & Consent Flow | User settings for SMS | Devise | feature/prd-8-consent |

**Epic 9: Build a Page for Review of Quarterly Meeting for JPMC**  
**Epic Overview**: Dedicated page with structured prompts/questions for JPMC accounts (benchmarking, taxes/fees, allocation review).  
**User Capabilities**: Interns/advisors generate answers/reports from data.  
**Fit into Big Picture**: Targets real HNW quarterly rituals, simulating advisor prep with personal data.

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Quarterly Review Page Layout | Form + response sections | Epic 3 UI patterns | feature/prd-9-review-layout |
| 2 | JPMC-Specific Data Pull | Filter snapshots for JPMC | Epic 5 filters | feature/prd-9-jpmc-pull |
| 3 | Prompt-Based Question Answers | Ollama-generated responses to fixed questions | Epic 4 chat | feature/prd-9-prompt-answers |

**Epic 10: Reorganize Our Admin Pages and Mission Control**  
**Epic Overview**: Consolidate and modernize admin/Mission Control views for better oversight of users, syncs, and health.  
**User Capabilities**: Admins monitor everything efficiently; trigger actions.  
**Fit into Big Picture**: Enables scalable internship program ops with privacy and control.

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Sidebar & Navigation Restructure | Unified admin menu | Epic 12 | feature/prd-10-admin-sidebar |
| 2 | Enhanced Sync Monitoring Table | Real-time sync logs | Existing Mission Control | feature/prd-10-sync-table |
| 3 | User & Data Health Dashboard | Aggregated stats | All prior sync epics | feature/prd-10-health-dash |

**Epic 11: Create a Task Management System**  
**Epic Overview**: Simple Kanban-style board with agent-aware natural language task creation/update/close via advisor chat.  
**User Capabilities**: Advisors assign educational tasks; interns track progress.  
**Fit into Big Picture**: Structures curriculum delivery as actionable tasks (e.g., "Run Monte Carlo on portfolio").

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Task Model & Kanban UI | Basic board with columns | ViewComponent | feature/prd-11-task-model-ui |
| 2 | Natural Language Task Commands | Parse chat → create/update tasks | Epic 4 | feature/prd-11-nl-commands |
| 3 | Task Assignment & Notifications | Link to users; notify on changes | Epic 7 | feature/prd-11-assignment |

**Epic 12: General Navigation and UI Patterns**  
**Epic Overview**: Define and implement consistent app-wide navigation (sidebar, topbar), UI components (cards, modals, buttons), and responsive patterns using Tailwind/DaisyUI/ViewComponent for a polished, professional feel.  
**User Capabilities**: Interns/admins navigate intuitively across dashboards, chat, tasks, admin; consistent styling and mobile responsiveness.  
**Fit into Big Picture**: Reduces cognitive load for financial novices, making the entire educational experience feel reliable and adult-oriented — critical for sustained engagement.

**Potential PRD Table**  
| Priority | PRD Title | Scope | Dependencies | Suggested Branch |
|----------|-----------|-------|--------------|------------------|
| 1 | Global Layout & Sidebar Component | App shell with role-based menu | Devise | feature/prd-12-global-layout |
| 2 | Standard UI Component Library | Cards, modals, buttons, tables via ViewComponent | Tailwind/DaisyUI | feature/prd-12-component-lib |
| 3 | Responsive & Theming Rules | Mobile-first + dark mode basics | #1 + #2 | feature/prd-12-responsive-theming |
| 4 | Empty-State & Error Patterns | Consistent handling across pages | All UI epics | feature/prd-12-empty-error |

Next steps? Which epic (or specific PRD within one) should we flesh out first with a full atomic PRD? Or refine priorities/dependencies? Let me know how you'd like to iterate.