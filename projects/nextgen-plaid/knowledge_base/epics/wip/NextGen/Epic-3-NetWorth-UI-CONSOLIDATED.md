**Epic 3: Net Worth Dashboard Polish & Components**

**Epic Overview**  
Build out the polished Net Worth dashboard UI by integrating real components into the scaffolded layout from Epic 2 (PRD-2-00 wireframe + PRD-2-09 dashboard layout). Replace placeholders with functional views: hero summary card, asset allocation pie/bar, sector weights table, performance chart (chartkick), holdings summary table, transactions summary cards, export button, and refresh/sync widget. All components consume FinancialSnapshot JSON blobs (from Epic 2) and respect POC refactoring guidance: existing UI (holdings/transactions/etc.) is disposable — break, rename, or replace freely to achieve clean, consistent design per style guide. By the end of this epic, the entire Net Worth section is fully navigable, data-driven, and visually professional.

**User Capabilities**  
Users see a cohesive Net Worth dashboard with real-time summaries, breakdowns, trends, and interaction (refresh, export). Owners/admins preview via Mission Control stub.

**Fit into Big Picture**  
Delivers the visual "aha" moment for HNW users: aggregated wealth + insights grounding the AI tutor curriculum (allocation drift, performance, reinvestment). Builds directly on Epic 2 snapshots without real-time computation overload.

**PRD Summary Table** (Epic 3 – 9 PRDs)

| Priority | PRD Title                                      | Scope                                      | Dependencies                          | Suggested Branch                     | Notes |
|----------|------------------------------------------------|--------------------------------------------|---------------------------------------|--------------------------------------|-------|
| 10       | Net Worth Summary Card Component               | Hero card: total NW + day/30d deltas ($ + %) | Epic 2 (PRD-2-00 wireframe + PRD-2-09 layout) | feature/prd-3-10-nw-summary-card     | First real component replacement |
| 11       | Asset Allocation View                          | Pie/bar chart + tooltips (percent + value) | PRD-3-10                              | feature/prd-3-11-allocation-view     | Uses asset_allocation JSON |
| 12       | Sector Weights View                            | Bar/table display (percent + value)        | PRD-3-11                              | feature/prd-3-12-sector-weights      | Uses sector_weights JSON |
| 13       | Performance Placeholder View                   | Chartkick line chart (on-demand snapshot query) | PRD-3-12                          | feature/prd-3-13-performance-view    | Historical trend (last 30 days) |
| 14       | Holdings Summary View                          | Top holdings table + Turbo expand          | PRD-3-13                              | feature/prd-3-14-holdings-summary    | Expand to full list |
| 15       | Transactions Summary View                      | Monthly income/expenses cards              | PRD-3-14                              | feature/prd-3-15-transactions-summary| Summary stats + link to full list |
| 16       | Snapshot Export Button                         | Dropdown (JSON/CSV) on dashboard           | PRD-3-15                              | feature/prd-3-16-export-button       | Ties to Epic 2 export API |
| 17       | Refresh Snapshot / Sync Status Widget          | Refresh button + badge + rate limit + Turbo feedback | PRD-3-16                        | feature/prd-3-17-refresh-widget      | Async update |
| 18       | Final Dashboard Polish & Breadcrumbs           | Breadcrumbs, mobile tweaks, empty states, QA | PRD-3-17                          | feature/prd-3-18-final-polish        | Cleanup & consistency pass |

**Key Guidance for All PRDs in Epic 3**
- All existing UI code (POC dashboard, holdings, transactions, etc.) is disposable — refactor/break/replace freely to fit the new layout/sidebar pattern.
- Components land into nested `NetWorth::*` routes from Epic 2.
- Use FinancialSnapshot.latest_for_user(current_user).data for all data access.
- Follow `knowledge_base/style_guide.md` and `knowledge_base/templates/` strictly.

This Epic 3 is self-contained, depends only on Epic 2 completion, and focuses purely on UI polish/components. Ready to add to knowledge base — let me know if you want any tweaks before handing off to Junie.