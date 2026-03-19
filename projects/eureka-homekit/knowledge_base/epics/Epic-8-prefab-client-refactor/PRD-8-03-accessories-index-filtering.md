<!--
  PRD Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/PRD-<N>-<XX>-<slug>.md

  This template is based on the structure used in Epic 4 PRDs, e.g.:
    knowledge_base/epics/wip/NextGen/Epic‑4/PRD‑4‑01‑saprun‑schema‑persona‑config.md
-->

#### PRD‑8‑03: Accessories Index Endpoint with Filtering (Optional)

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `{{source-document}}-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

While the bulk accessory endpoints enable fast filtering, there is currently no UI to browse accessories across the entire home with flexible filters. This optional PRD adds a new `/accessories` page that allows users to view all accessories, filter by reachability, room, category, manufacturer, and see summary stats—all leveraging the new PrefabClient bulk methods. This page serves as an "Accessory Explorer" for troubleshooting, inventory management, and quick status checks.

---

### Requirements

#### Functional

- Add `GET /accessories` route that accepts query parameters:
  - `home` (optional, defaults to first home)
  - `reachable` (`true`/`false`)
  - `room` (string)
  - `category` (string)
  - `manufacturer` (string)
- Create `AccessoriesController#index` action that:
  - Determines which home to query (params[:home] or first home)
  - Uses `PrefabClient.all_accessories` with permitted filters
  - Uses `PrefabClient.accessories_summary` for sidebar stats (optional)
  - Renders HTML view (or JSON API if `Accept: application/json`)
- Build filter UI with:
  - Dropdown for room selection (populated from summary or hard‑coded list)
  - Dropdown for category (from known categories or summary)
  - Dropdown for manufacturer (from summary or hard‑coded)
  - Toggle for reachable (all / reachable only / unreachable only)
  - "Apply Filters" button and "Clear" link
- Display filtered accessories in a table with columns: Name, Room, Category, Manufacturer, Reachable (icon), Actions (link to room/accessory detail)
- Provide empty state when no accessories match filters

#### Non-Functional

- **Performance**: Page load should be <1 second (bulk endpoints are ~30ms)
- **Responsive**: Works on mobile viewports (existing Tailwind responsive classes)
- **Accessibility**: WCAG 2.1 AA compliant (semantic HTML, ARIA labels)
- **Backward compatibility**: No changes to existing routes or controllers

#### Rails / Implementation Notes

- **Controller**: `app/controllers/accessories_controller.rb` (extend existing controller; currently only has `control` and `batch_control` actions)
- **Route**: Add `resources :accessories, only: [:index]` to `config/routes.rb` (or `get '/accessories', to: 'accessories#index'`)
- **View**: `app/views/accessories/index.html.erb` (follow existing layout patterns)
- **Components**: Consider creating `Accessories::FilterComponent` and `Accessories::TableComponent` (optional)
- **Filter population**: Use `PrefabClient.accessories_summary` to get unique rooms, categories, manufacturers; cache for 5 minutes
- **JSON API**: Respond to `format.json` with filtered accessory array

---

### Error Scenarios & Fallbacks

- **Prefab unavailable**: Show error message "Cannot load accessory data. Please try again later." with Retry button
- **No homes configured**: Display empty state with link to sync page
- **Filter dropdowns empty**: If summary endpoint fails, fall back to hard‑coded list of known categories/manufacturers (from documentation)
- **Large accessory count (1000+)**: Table should paginate or virtual scroll (optional). For MVP, display all (bulk endpoint is fast).

---

### Architectural Context

This PRD builds on PRD‑8‑01 (PrefabClient bulk endpoints) and adds a new UI surface. It is optional and can be deferred if accessory browsing is not a priority. The page is read‑only and does not affect any existing functionality.

**Key boundaries**:
- No changes to database models; all data fetched live from Prefab
- Filtering happens on Prefab side; we just pass query parameters
- The page is independent of existing room/accessory detail pages (though can link to them)

**Non‑goals**:
- Real‑time updates (page is static until refresh)
- Editing accessories or their characteristics (use existing control UI)
- Complex sorting, grouping, or export features (can be added later)
- Persistent saved filters

---

### Acceptance Criteria

- [ ] `GET /accessories` returns HTML page showing all accessories for the default home
- [ ] `GET /accessories?home=Waverly&reachable=false` shows only unreachable accessories
- [ ] Filter UI includes dropdowns for room, category, manufacturer (populated from summary)
- [ ] Reachable toggle works (all / reachable only / unreachable only)
- [ ] Empty state shown when no accessories match filters
- [ ] Table includes columns: Name, Room, Category, Manufacturer, Reachable (icon)
- [ ] Each accessory row links to its room detail page (or accessory detail if exists)
- [ ] Page works on mobile (stacked filters, scrollable table)
- [ ] `GET /accessories.json` returns JSON array of filtered accessories
- [ ] All existing `AccessoriesController` actions (`control`, `batch_control`) continue to work

---

### Test Cases

#### Unit (Minitest)

- `spec/controllers/accessories_controller_spec.rb` (new or extend):
  - `describe 'GET #index'` – success with no filters, each filter type, combined filters, empty result, JSON format
  - `describe 'filter parameter handling'` – ensures parameters are passed correctly to `PrefabClient`

#### Integration (Minitest)

- `spec/requests/accessories_spec.rb` (if created):
  - End‑to‑end request/response cycle with mocked `PrefabClient`

#### System / Smoke (Capybara)

- `spec/system/accessories_spec.rb` (optional):
  - Visit `/accessories`, see table
  - Apply filters, verify results update
  - Clear filters, return to full list
  - Mobile viewport test

---

### Manual Verification

1. Ensure Prefab running with home "Waverly" containing accessories.
2. Navigate to `/accessories` in browser.
3. Verify:
   - Page loads with a table of all accessories
   - Filter controls present (room dropdown, category dropdown, manufacturer dropdown, reachable toggle)
   - Dropdowns populated with values (e.g., rooms from summary)
4. Apply filters:
   - Select "Garage" from room dropdown, click Apply – only garage accessories shown
   - Select "Lightbulb" from category dropdown – only lightbulbs in garage shown
   - Toggle reachable to "Unreachable only" – only unreachable lightbulbs in garage shown
5. Clear filters, verify full list returns.
6. Test mobile responsiveness (resize browser).
7. Verify JSON API: `curl -H "Accept: application/json" "http://localhost:3000/accessories?reachable=false"`

**Expected**
- Page loads quickly (<1s)
- Filters work and reflect Prefab's filtering behavior
- Empty state appears when no matches
- JSON API returns proper JSON array

---

### Rollout / Deployment Notes

- No migrations or backfills required.
- Monitoring: Watch for errors in `AccessoriesController#index` (e.g., Prefab timeouts).
- Rollback: Remove route and controller action; no side effects.
- **Dependency**: Requires PRD‑8‑01 to be deployed first.