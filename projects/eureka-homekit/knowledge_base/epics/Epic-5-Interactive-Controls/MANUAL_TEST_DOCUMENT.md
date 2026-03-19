# Epic 5: Manual Test Document

**Version:** 1.1  
**Date:** 2026-02-15  
**Epic:** Interactive HomeKit Device Controls & Scene Management  
**Test Environment:** Rails 8.1, Ruby 3.3, PostgreSQL, Prefab Proxy  

---

## ⚠️ QUICK START: Where to Begin Testing

### 1. Start Services
```bash
# Terminal 1: Start Rails server
bin/rails server

# Terminal 2: Start Prefab proxy (required for control commands)
# Follow instructions in project README or Prefab documentation
```

### 2. Primary Test URLs
Open your browser and navigate to:

- **Dashboard**: http://localhost:3000/
- **Scenes Management**: http://localhost:3000/scenes
- **Favorites Dashboard**: http://localhost:3000/favorites
- **Room Controls**: http://localhost:3000/rooms (select any room)

### 3. First Things to Verify

#### Can you see the UI components?

**On Scenes Page (`/scenes`):**
- ✅ Grid of scene cards with emoji icons
- ✅ Blue "Execute" button on each scene
- ✅ Filter dropdowns (by home, search)

**On Favorites Page (`/favorites`):**
- ✅ Grid of favorite accessories (may be empty initially)
- ✅ Star buttons on control cards
- ✅ Empty state message if no favorites: "No favorites yet"

**On Room Page (`/rooms/:id`):**
- ✅ "Controls" section heading
- ✅ Individual control cards for each accessory (lights, locks, thermostats, etc.)
- ✅ Batch control toolbar (if 2+ controllable accessories)
- ✅ Star buttons (top-right corner of each control card)

#### Where is the Navigation Menu?
Look for the **left sidebar** with menu items:
- 🏠 Dashboard
- 📐 Floorplan
- 🏠 All Homes
- ▶️ **Scenes** ← Click here to test scenes
- ⭐ **Favorites** ← Click here to test favorites

### 4. Quick Smoke Test (5 minutes)

1. **Test Scene Execution:**
   - Go to http://localhost:3000/scenes
   - Click any "Execute" button
   - **Expected**: Loading spinner → Green success toast

2. **Test Light Control:**
   - Go to http://localhost:3000/rooms (select a room with lights)
   - Toggle any light switch
   - **Expected**: Immediate toggle + Green success toast

3. **Test Favorites:**
   - On a room page, click a star button (⭐) on any control card
   - Go to http://localhost:3000/favorites
   - **Expected**: Starred accessory appears in favorites grid

4. **Test Batch Control:**
   - On a room page with 2+ accessories
   - Check 2+ checkboxes
   - Click "Turn On"
   - **Expected**: Progress indicator → Success toast

**If all 4 pass**: Proceed to full test suite below.  
**If any fail**: Check Prefab proxy connection, database seed data, and Rails logs.

---

## Table of Contents

1. [Test Objectives](#1-test-objectives)
2. [Test Prerequisites](#2-test-prerequisites)
3. [Test Execution Plan](#3-test-execution-plan)
4. [Component Test Cases](#4-component-test-cases)
5. [Controller Test Cases](#5-controller-test-cases)
6. [Scene Management Test Cases](#6-scene-management-test-cases)
7. [Batch Control Test Cases](#7-batch-control-test-cases)
8. [Favorites Test Cases](#8-favorites-test-cases)
9. [Cross-Cutting Concerns](#9-cross-cutting-concerns)
10. [Manual Smoke Test Checklist](#10-manual-smoke-test-checklist)
11. [Test Reporting](#11-test-reporting)

---

## 1. Test Objectives

### Primary Goals

- ✅ Verify all control components render and function correctly
- ✅ Confirm API endpoints accept control commands and return proper responses
- ✅ Validate optimistic UI updates and rollback on error
- ✅ Test confirmation modals for security-critical actions (locks, garage doors)
- ✅ Verify Toast notification system for feedback
- ✅ Confirm debounced sliders and controls (no API spam)
- ✅ Test offline accessory handling (disabled state, badges)
- ✅ Validate audit logging to `ControlEvent` table
- ✅ Verify rate limiting (10 req/sec/IP)
- ✅ Test scene execution and favorites persistence

### Acceptance Criteria

- All test cases pass with 100% success rate
- No JavaScript console errors
- No Rails log errors (warnings acceptable)
- All controls complete within 500ms latency (measured via Prefab proxy)
- Zero N+1 queries in any view
- All interactive elements keyboard accessible
- Mobile touch targets ≥ 44x44px

---

## 2. Test Prerequisites

### Required Services

| Service | URL | Status Check |
|---------|-----|-------------|
| Rails server | http://localhost:3000 | `rails server` |
| Prefab proxy | http://localhost:8080 | `curl http://localhost:8080/homes` (should return JSON) |
| PostgreSQL | localhost:5432 | `psql -U eureka -d eureka_development` |

### Database Setup

```bash
# Ensure schema is current
bin/rails db:schema:load

# Seed test data (if available)
bin/rails db:seed
```

### Browser Requirements

- **Chrome/Firefox/Edge:** Latest stable version (for DevTools)
- **Mobile:** iOS Safari / Android Chrome (for responsive testing)

### Test Credentials

- No authentication required (single-user assumption per Epic 5 spec)

---

## 2A. Test URLs & Navigation Paths

### Primary Test URLs

| Feature | URL | Description |
|---------|-----|-------------|
| **Scenes** | `http://localhost:3000/scenes` | Scene management and execution |
| **Favorites** | `http://localhost:3000/favorites` | Favorites dashboard with inline controls |
| **Room Controls** | `http://localhost:3000/rooms/:id` | Room detail page with all device controls |
| **Dashboard** | `http://localhost:3000/` | Home dashboard (link to rooms) |

### Navigation Instructions

#### To Access Scenes:
1. Start at `http://localhost:3000/`
2. Click **"Scenes"** in the left sidebar (play icon ▶️)
3. **Expected View:**
   - Breadcrumb: Dashboard → Scenes
   - Filter dropdowns: "All Homes" + Search bar
   - Grid of scene cards with:
     - Scene name and emoji icon
     - Accessories count (e.g., "3 accessories")
     - "Last executed" timestamp
     - Blue "Execute" button

#### To Access Favorites:
1. Start at `http://localhost:3000/`
2. Click **"Favorites"** in the left sidebar (star icon ⭐)
3. **Expected View:**
   - Breadcrumb: Dashboard → Favorites
   - Heading: "Favorites"
   - Subheading: "Quick access to your starred accessories. Drag to reorder."
   - Grid of favorite accessories with inline controls
   - Empty state if no favorites: "No favorites yet" message

#### To Access Room Controls:
1. Start at `http://localhost:3000/`
2. Click **"Dashboard"** in left sidebar or navigate to **"Rooms"** → **"All Rooms"**
3. Click any room card (e.g., "Living Room")
4. **Expected View:**
   - Breadcrumb: Eureka → Rooms → [Room Name]
   - Room name with icon
   - "Controls" section with:
     - Batch control toolbar (if 2+ controllable accessories)
     - Individual control cards for each accessory
     - Star button (top-right of each control card) for favoriting

### UI Components Checklist

#### Scene Management (`/scenes`)
- [ ] `Scenes::ListComponent` renders grid of scenes
- [ ] `Scenes::CardComponent` shows each scene with:
  - [ ] Emoji icon (heuristic-based)
  - [ ] Scene name
  - [ ] Accessories count
  - [ ] "Last executed" timestamp
  - [ ] Blue "Execute" button
- [ ] Filter dropdown: "All Homes" selector
- [ ] Search bar: "Search scenes..." input
- [ ] Empty state: "No scenes configured" message (if no scenes)

#### Favorites Dashboard (`/favorites`)
- [ ] `Dashboards::FavoritesComponent` renders favorites grid
- [ ] Each favorite shows:
  - [ ] Accessory name
  - [ ] Appropriate control component (light, lock, etc.)
  - [ ] Star button (filled, for un-favoriting)
- [ ] Drag-to-reorder functionality (if implemented)
- [ ] Empty state: "No controllable accessories" or "No favorites yet" (with ⭐ emoji)

#### Room Controls (`/rooms/:id`)
- [ ] `Rooms::DetailComponent` wraps all controls
- [ ] `Controls::BatchControlComponent` toolbar (if 2+ accessories):
  - [ ] Checkboxes for multi-select
  - [ ] "Turn On" / "Turn Off" batch buttons
  - [ ] Selection count badge
- [ ] `Controls::AccessoryControlComponent` (dispatcher) renders for each accessory:
  - [ ] `Controls::LightControlComponent` (if light)
    - [ ] Toggle switch
    - [ ] Brightness slider
    - [ ] Color picker button
  - [ ] `Controls::LockControlComponent` (if lock)
    - [ ] Lock/Unlock buttons
    - [ ] Confirmation modal on unlock
  - [ ] `Controls::ThermostatControlComponent` (if thermostat)
    - [ ] Temperature slider
    - [ ] +/- increment buttons
    - [ ] Mode selector (Heat/Cool/Auto/Off)
  - [ ] `Controls::SwitchControlComponent` (if switch)
    - [ ] Toggle switch
  - [ ] `Controls::OutletControlComponent` (if outlet)
    - [ ] Toggle switch
  - [ ] `Controls::FanControlComponent` (if fan)
    - [ ] Speed slider
    - [ ] Direction toggle (if supported)
    - [ ] Oscillation toggle (if supported)
  - [ ] `Controls::BlindControlComponent` (if blind)
    - [ ] Position slider
    - [ ] Quick action buttons (0%, 50%, 100%)
    - [ ] Tilt slider (if supported)
  - [ ] `Controls::GarageDoorControlComponent` (if garage door)
    - [ ] Open/Close buttons
    - [ ] Confirmation modal on both actions
    - [ ] Obstruction warning (if detected)
- [ ] Star button (top-right of each control) for favoriting
- [ ] Offline badge (if accessory offline)

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/accessories/control` | POST | Control individual accessory |
| `/accessories/batch_control` | POST | Batch control multiple accessories |
| `/scenes/:id/execute` | POST | Execute a scene |
| `/favorites/toggle` | POST | Star/unstar an accessory |
| `/favorites/reorder` | PATCH | Reorder favorites (drag-and-drop) |

---

## 3. Test Execution Plan

### Phase 1: Component Testing (2-3 hours)

Run each component test in isolation using the Rails console and browser verification.

| Component | Test Focus | Time Estimate |
|-----------|-----------|---------------|
| LightControlComponent | Toggle, brightness, color | 30 min |
| SwitchControlComponent | On/off toggle | 15 min |
| OutletControlComponent | On/off toggle | 15 min |
| ThermostatControlComponent | Temp slider, mode, units | 30 min |
| LockControlComponent | Unlock with confirmation | 30 min |
| FanControlComponent | Speed, direction, oscillation | 30 min |
| BlindControlComponent | Position, tilt, quick actions | 30 min |
| GarageDoorControlComponent | Open/close with confirmation | 30 min |

### Phase 2: Controller Testing (1-2 hours)

| Controller | Test Focus | Time Estimate |
|-----------|-----------|---------------|
| AccessoriesController | Control endpoint, batch_control | 30 min |
| ScenesController | Index, show, execute | 30 min |
| FavoritesController | Index, toggle, reorder | 30 min |

### Phase 3: System Flow Testing (2-3 hours)

| Flow | Test Focus | Time Estimate |
|------|-----------|---------------|
| Scene execution | Navigation, filtering, execute | 30 min |
| Light control flow | Toggle, brightness, color picker | 30 min |
| Lock control flow | Unlock confirmation, rollback | 30 min |
| Batch control flow | Select, batch action, progress | 30 min |
| Favorites flow | Star, reorder, persist | 30 min |

### Phase 4: Cross-Cutting Tests (1 hour)

| Concern | Test Focus | Time Estimate |
|---------|-----------|---------------|
| Rate limiting | 10 req/sec/IP enforcement | 15 min |
| Offline handling | Disabled states, badges | 15 min |
| Toast notifications | Success/error display | 15 min |
| Keyboard navigation | Tab, Enter, Escape | 15 min |

---

## 4. Component Test Cases

### 4.1 LightControlComponent

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| LC-01 | Toggle light on/off | 1. Click toggle switch | ✅ Accessory turns on/off, toast appears |
| LC-02 | Adjust brightness slider | 1. Drag brightness slider to 50% | ✅ Value updates after 300ms debounce, API call made |
| LC-03 | Open color picker | 1. Click color picker button | ✅ Modal opens with hue/saturation controls |
| LC-04 | Set color from picker | 1. Select a color in picker | ✅ Color applied, toast confirms |
| LC-05 | Control offline light | 1. Simulate offline accessory (no sensors) | ✅ Toggle disabled (opacity-50), offline badge visible |

**Console Verification:**
```bash
# Check for JavaScript errors
# Open DevTools > Console and verify no errors on interaction
```

**API Verification:**
```bash
# Verify correct endpoint called
# DevTools > Network > Filter: /accessories/control > Inspect Request
```

---

### 4.2 SwitchControlComponent

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| SC-01 | Toggle switch on/off | 1. Click toggle | ✅ Optimistic update, rollback on error |
| SC-02 | Control offline switch | 1. Simulate offline accessory | ✅ Toggle disabled + offline badge |

**Debounce Verification:**
- Toggle should respond immediately (200ms debounce for switches)

---

### 4.3 OutletControlComponent

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| OC-01 | Toggle outlet on/off | 1. Click toggle | ✅ Optimistic update, rollback on error |
| OC-02 | Control offline outlet | 1. Simulate offline accessory | ✅ Toggle disabled + offline badge |

---

### 4.4 ThermostatControlComponent

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| TC-01 | Adjust target temperature | 1. Drag temp slider | ✅ Value updates after 500ms debounce |
| TC-02 | Click +/- increment buttons | 1. Click +1° or -1° | ✅ Temp changes by 1°, API call made |
| TC-03 | Change climate mode | 1. Select Heat/Cool/Auto/Off | ✅ Mode changes, API call made |
| TC-04 | Toggle °C/°F units | 1. Click unit toggle | ✅ Display updates, API call made (if supported by Prefab) |
| TC-05 | Control offline thermostat | 1. Simulate offline accessory | ✅ All controls disabled + offline badge |

**Temperature Conversion Verification:**
- Celsius/ Fahrenheit conversion should be accurate
- Example: 72°F = 22.2°C, 22°C = 71.6°F

---

### 4.5 LockControlComponent

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| LK-01 | Click unlock | 1. Click unlock button | ✅ Confirmation modal appears |
| LK-02 | Cancel modal | 1. Click cancel button | ✅ Modal closes, no API call, no state change |
| LK-03 | Confirm unlock | 1. Click confirm button | ✅ Lock unlocks, toast confirms, `ControlEvent` logged |
| LK-04 | Click lock | 1. Click lock button | ✅ Locks immediately (no confirmation needed) |
| LK-05 | Control offline lock | 1. Simulate offline accessory | ✅ Controls disabled + offline badge |

**Audit Log Verification:**
```ruby
# In Rails console:
ControlEvent.where(characteristic: 'LockTargetState').last
# Should show: user_ip, accessory_uuid, characteristic, old_value, new_value, success
```

---

### 4.6 FanControlComponent

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| FC-01 | Toggle fan on/off | 1. Click toggle | ✅ Speed slider appears/disappears |
| FC-02 | Adjust speed | 1. Drag speed slider | ✅ Value updates after 300ms debounce |
| FC-03 | Toggle direction | 1. Click direction button (if supported) | ✅ Direction changes, API call made |
| FC-04 | Toggle oscillation | 1. Click oscillation button (if supported) | ✅ Oscillation toggles, API call made |
| FC-05 | Control offline fan | 1. Simulate offline accessory | ✅ All controls disabled + offline badge |

**Feature Detection:**
- Speed slider should only appear when `Rotation Speed` characteristic is present
- Direction/oscillation buttons should only appear if supported

---

### 4.7 BlindControlComponent

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| BL-01 | Drag position slider | 1. Drag to 50% | ✅ Position updates after 300ms debounce |
| BL-02 | Click 0% (closed) quick action | 1. Click "Close" button | ✅ Blind closes immediately |
| BL-03 | Click 100% (open) quick action | 1. Click "Open" button | ✅ Blind opens immediately |
| BL-04 | Click 50% quick action | 1. Click "50%" button | ✅ Blind moves to 50% |
| BL-05 | Tilt angle (if supported) | 1. Drag tilt slider | ✅ Tilt changes, API call made |
| BL-06 | Control offline blind | 1. Simulate offline accessory | ✅ All controls disabled + offline badge |

---

### 4.8 GarageDoorControlComponent

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| GD-01 | Click open | 1. Click open button | ✅ Confirmation modal appears |
| GD-02 | Cancel modal | 1. Click cancel | ✅ Modal closes, no action |
| GD-03 | Confirm open | 1. Click confirm | ✅ Door opens, toast confirms, `ControlEvent` logged |
| GD-04 | Click close | 1. Click close button | ✅ Confirmation modal appears (both open/close require confirm) |
| GD-05 | Confirm close | 1. Click confirm | ✅ Door closes, toast confirms |
| GD-06 | Obstruction detected | 1. Simulate obstruction | ✅ Open/close disabled, warning banner visible |

**Security Verification:**
- BOTH open and close actions require confirmation modal

---

### 4.9 Shared Components

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| SH-01 | ConfirmationModalComponent | 1. Trigger modal (lock unlock) | ✅ Native `<dialog>` element, keyboard accessible |
| SH-02 | Toast notification (success) | 1. Perform successful control | ✅ Green toast appears, auto-dismisses after 3s |
| SH-03 | Toast notification (error) | 1. Perform control with Prefab offline | ✅ Red toast appears, auto-dismisses after 5s |

**Toast Verification:**
- Custom event: `window.dispatchEvent(new CustomEvent('toast:show', { detail: { message, type, duration } }))`

---

## 5. Controller Test Cases

### 5.1 AccessoriesController

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| AC-01 | POST /accessories/control (success) | 1. Toggle a light | ✅ HTTP 200, JSON: `{ success: true, value: ... }` |
| AC-02 | POST /accessories/control (error) | 1. Control offline accessory | ✅ HTTP 422, JSON: `{ success: false, error: "..." }` |
| AC-03 | POST /accessories/control (invalid characteristic) | 1. Send invalid characteristic | ✅ HTTP 422, JSON: `{ success: false, error: "..." }` |
| AC-04 | POST /accessories/control (missing params) | 1. Send partial params | ✅ HTTP 400, JSON: `{ success: false, error: "..." }` |
| AC-05 | POST /accessories/batch_control | 1. Send array of 3 accessories | ✅ HTTP 200, JSON: `{ success: true, results: [...] }` |
| AC-06 | POST /accessories/batch_control (1 failure) | 1. Send 2 valid + 1 offline | ✅ HTTP 200, 2 success + 1 failure in results |

**API Response Verification:**
```json
// Success
{ "success": true, "value": 1, "latency_ms": 450 }

// Error
{ "success": false, "error": "Connection refused", "offline": true }
```

**Rate Limiting Verification:**
- Make 11 rapid requests in 1 second
- 11th request should return HTTP 429: `{ success: false, error: "Rate limit exceeded" }`

---

### 5.2 ScenesController

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| SC-01 | GET /scenes (success) | 1. Navigate to /scenes | ✅ HTTP 200, scene grid renders |
| SC-02 | GET /scenes?home_id=X | 1. Filter by home | ✅ Only scenes for home X shown |
| SC-03 | GET /scenes?search=X | 1. Search by name | ✅ Only matching scenes shown |
| SC-04 | GET /scenes/:id | 1. Click a scene card | ✅ Scene detail page with execute button |
| SC-05 | POST /scenes/:id/execute (success) | 1. Click execute button | ✅ Spinner, success toast, `ControlEvent` logged |
| SC-06 | POST /scenes/:id/execute (Prefab offline) | 1. Simulate offline Prefab | ✅ Error toast, no `ControlEvent` created |
| SC-07 | GET /scenes (N+1 verification) | 1. Load scenes page | ✅ No N+1 queries in Rails log |

**Rails Log Verification:**
```bash
# In Rails console or log file, verify eager loading:
Scene.includes(:home, :accessories).where(...)
```

---

### 5.3 FavoritesController

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| FC-01 | GET /favorites (success) | 1. Navigate to /favorites | ✅ HTTP 200, favorite accessories render |
| FC-02 | GET /favorites (empty) | 1. No favorites yet | ✅ "No favorites yet" empty state shown |
| FC-03 | POST /favorites/toggle | 1. Click star button | ✅ Star fills, API call made |
| FC-04 | POST /favorites/toggle (unstar) | 1. Click filled star | ✅ Star empties, API call made |
| FC-05 | POST /favorites/reorder | 1. Drag to reorder | ✅ Order persists (if implemented) |
| FC-06 | GET /favorites (persist across reload) | 1. Refresh page | ✅ Favorites still visible |

---

## 6. Scene Management Test Cases

### 6.1 Navigation & Filtering

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| SM-01 | Navigate to /scenes | 1. Click "Scenes" in navigation | ✅ Scenes grid loads |
| SM-02 | Filter by home | 1. Select home from dropdown (if implemented) | ✅ Only scenes for selected home shown |
| SM-03 | Search by name | 1. Type partial name in search | ✅ Results filter in real-time (if implemented) |
| SM-04 | View scene details | 1. Click scene card | ✅ Scene detail page opens |

### 6.2 Scene Execution

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| SE-01 | Execute scene | 1. Click execute button | ✅ Spinner, success toast, `ControlEvent` logged |
| SE-02 | Cancel execution | 1. Cancel before completion | ✅ No `ControlEvent` created |
| SE-03 | Execute offline | 1. Simulate Prefab offline | ✅ Error toast, no `ControlEvent` |

**Audit Log Verification:**
```ruby
# Verify scene execution logged:
ControlEvent.where(characteristic: 'SceneActivation').last
```

---

## 7. Batch Control Test Cases

### 7.1 Selection & Toolbar

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| BC-01 | Select multiple accessories | 1. Click checkboxes on 3+ accessories | ✅ Toolbar appears with count badge |
| BC-02 | Select all | 1. Click "Select All" checkbox | ✅ All accessories selected |
| BC-03 | Deselect all | 1. Click "Deselect All" | ✅ All checkboxes unchecked |
| BC-04 | Deselect one | 1. Uncheck one accessory | ✅ Count badge updates |

### 7.2 Batch Actions

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| BA-01 | Turn on batch | 1. Click "Turn On" in toolbar | ✅ Progress indicator, success/error per accessory |
| BA-02 | Turn off batch | 1. Click "Turn Off" in toolbar | ✅ Progress indicator, success/error per accessory |
| BA-03 | Batch with 1 failure | 1. Select 2 valid + 1 offline | ✅ 2 success + 1 error in results |
| BA-04 | Batch offline accessories only | 1. Select 2 offline accessories | ✅ All show offline error |

**UI Feedback:**
- Progress indicator: "Controlling 3 accessories..."
- Success: "2/3 accessories updated"
- Error: "1 accessory failed (offline)"

---

## 8. Favorites Test Cases

### 8.1 Star/Unstar

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| FS-01 | Star an accessory | 1. Click star button on any accessory | ✅ Star fills, API call made |
| FS-02 | Unstar an accessory | 1. Click filled star | ✅ Star empties, API call made |
| FS-03 | Navigate to favorites page | 1. Click "Favorites" in nav | ✅ Only starred accessories shown |

### 8.2 Reordering (if implemented)

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| FR-01 | Drag to reorder | 1. Drag accessory card up/down | ✅ Order persists on page reload |

**Persistence Verification:**
- Refresh page after reordering
- Verify new order matches what you set

---

## 9. Cross-Cutting Concerns

### 9.1 Rate Limiting

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| RL-01 | 10 requests in 1 second | 1. Make 10 rapid toggle actions | ✅ All succeed |
| RL-02 | 11th request in 1 second | 1. Make 11th request | ✅ HTTP 429: `{ success: false, error: "Rate limit exceeded" }` |
| RL-03 | Wait 1 second, then request | 1. Wait 1s, then toggle | ✅ Request succeeds |

**Test Script:**
```javascript
// In browser console (11 rapid requests):
for (let i = 0; i < 11; i++) {
  fetch('/accessories/control', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ accessory_id: 'test-uuid', characteristic: 'On', value: 1 })
  }).then(r => console.log(i, r.status));
}
```

---

### 9.2 Offline Handling

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| OH-01 | Accessory offline (no sensors) | 1. Simulate accessory with no sensors | ✅ All controls disabled (opacity-50 + cursor-not-allowed) |
| OH-02 | Prefab proxy offline | 1. Stop Prefab proxy | ✅ Toast error, rollback UI, `ControlEvent` marked failed |

**Rails Log Verification:**
```bash
# Should see:
Rails.logger.error "Connection refused to Prefab proxy"
```

---

### 9.3 Toast Notifications

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| TN-01 | Success toast | 1. Perform successful control | ✅ Green toast, auto-dismiss after 3s |
| TN-02 | Error toast | 1. Perform control with Prefab offline | ✅ Red toast, auto-dismiss after 5s |
| TN-03 | Toast stacking | 1. Trigger 2 errors rapidly | ✅ Toasts queue (not overwrite) |

---

### 9.4 Keyboard Navigation

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| KN-01 | Tab through controls | 1. Press Tab repeatedly | ✅ Focus rings visible on all interactive elements |
| KN-02 | Activate with Enter | 1. Focus toggle, press Enter | ✅ Toggle activates |
| KN-03 | Close modal with Escape | 1. Press Escape in modal | ✅ Modal closes |
| KN-04 | Arrow keys on slider | 1. Focus slider, press Arrow Right | ✅ Value increases (if supported by slider) |

---

### 9.5 Mobile Responsiveness

| TC ID | Test Case | Steps | Expected Result |
|-------|-----------|-------|----------------|
| MR-01 | Touch target size | 1. Inspect on mobile | ✅ All interactive elements ≥ 44x44px |
| MR-02 | Slider on mobile | 1. Drag slider on mobile | ✅ Works with touch swipe |
| MR-03 | Grid layout (mobile) | 1. View on mobile | ✅ 1 column layout |

**Chrome DevTools Mobile Emulation:**
- iPhone 14 Pro: 393x852
- Pixel 7: 412x915

---

## 10. Manual Smoke Test Checklist

**Test with a live Prefab proxy (required for full coverage)**

### Navigation Verification
- [ ] Open `http://localhost:3000/` — verify dashboard loads
- [ ] Click "Scenes" in left sidebar — verify redirects to `/scenes`
- [ ] Click "Favorites" in left sidebar — verify redirects to `/favorites`
- [ ] Navigate to "Rooms" → Click any room — verify controls section visible

### Scene Management
- [ ] Navigate to `http://localhost:3000/scenes` — verify scene grid loads with scene cards
- [ ] Verify each scene card shows: emoji icon, scene name, accessories count, "Last executed" timestamp, blue "Execute" button
- [ ] Filter by home using dropdown — verify results narrow to selected home
- [ ] Search by name in search bar — verify matching scenes shown
- [ ] Click Execute on a scene — verify loading spinner appears, then success toast ("Scene executed successfully")
- [ ] Execute scene when Prefab offline — verify error toast appears (red, with error message)
- [ ] Open Rails console: `ControlEvent.where(characteristic: 'SceneActivation').last` — verify scene execution logged with `success: true`

### Light Controls (on Room Page)
- [ ] Navigate to a room with lights: `http://localhost:3000/rooms/:id` (replace `:id` with actual room ID)
- [ ] Locate a light control card in the "Controls" section
- [ ] Verify light control card shows:
  - [ ] Accessory name (e.g., "Living Room Lamp")
  - [ ] Toggle switch
  - [ ] Brightness slider (if dimmable)
  - [ ] Color picker button (if color-capable)
  - [ ] Star button (top-right corner)
- [ ] Toggle a light ON — verify:
  - [ ] Toggle switch animates immediately (optimistic update)
  - [ ] Green success toast appears: "Living Room Lamp turned on"
  - [ ] No JavaScript console errors
- [ ] Toggle OFF — verify optimistic update + toast
- [ ] Simulate error (stop Prefab proxy) and toggle — verify:
  - [ ] UI rolls back to previous state
  - [ ] Red error toast appears with error message
- [ ] Drag brightness slider — verify:
  - [ ] Value updates smoothly
  - [ ] After 300ms debounce, API call made (check DevTools Network tab)
  - [ ] Toast confirms brightness change
- [ ] Click color picker button — verify:
  - [ ] Modal/dialog opens with hue and saturation controls
  - [ ] Select a color
  - [ ] Color applies to light
  - [ ] Toast confirms color change
- [ ] Control offline light (no sensors) — verify:
  - [ ] Toggle switch disabled (opacity-50, cursor-not-allowed)
  - [ ] "Offline" badge visible
  - [ ] Brightness slider disabled

### Switch/Outlet
- [ ] Toggle switch on/off — verify optimistic update
- [ ] Control offline outlet — verify disabled + offline badge

### Thermostat
- [ ] Adjust target temp via slider — verify debounced update
- [ ] Click +/- buttons — verify 1° increment
- [ ] Change mode (Heat/Cool/Auto/Off) — verify API call
- [ ] Toggle °C/°F — verify display updates

### Lock
- [ ] Click Unlock — verify confirmation modal appears
- [ ] Cancel modal — verify no action
- [ ] Confirm unlock — verify state change + audit log
- [ ] Click Lock — verify no confirmation needed + immediate lock

### Fan
- [ ] Toggle on — verify speed slider appears
- [ ] Adjust speed — verify debounced update
- [ ] Toggle direction (if supported) — verify change

### Blind
- [ ] Drag position slider — verify update
- [ ] Click "50%" quick action — verify position
- [ ] Click Open / Close — verify endpoints
- [ ] Adjust tilt (if supported)

### Garage Door
- [ ] Click Open — verify confirmation modal for BOTH open and close
- [ ] Verify obstruction warning when `Obstruction Detected` is true
- [ ] Verify all 5 states display correctly

### Batch Controls (on Room Page)
- [ ] Navigate to a room with 2+ controllable accessories: `http://localhost:3000/rooms/:id`
- [ ] Verify batch control toolbar appears at top of "Controls" section
- [ ] Verify toolbar shows:
  - [ ] "Select All" checkbox (in toolbar header)
  - [ ] Individual checkboxes on each control card
  - [ ] Action buttons: "Turn On", "Turn Off" (initially disabled)
- [ ] Click individual checkboxes on 3+ accessories — verify:
  - [ ] Checkboxes fill/check when clicked
  - [ ] Toolbar shows selection count badge (e.g., "3 selected")
  - [ ] Action buttons become enabled (blue/primary color)
- [ ] Click "Select All" checkbox in toolbar — verify:
  - [ ] All accessory checkboxes check
  - [ ] Count badge updates to show all accessories selected
- [ ] Click "Deselect All" or uncheck "Select All" — verify:
  - [ ] All checkboxes uncheck
  - [ ] Action buttons become disabled
- [ ] Select 3 accessories and click "Turn On" batch action — verify:
  - [ ] Progress indicator appears: "Controlling 3 accessories..."
  - [ ] Loading spinner visible
  - [ ] After completion, success toast: "3/3 accessories updated" (or "2/3 accessories updated" if 1 failed)
  - [ ] API call to `POST /accessories/batch_control` (check DevTools Network tab)
  - [ ] Checkboxes automatically uncheck after completion
- [ ] Test batch with 1 offline accessory:
  - [ ] Select 2 online + 1 offline accessory
  - [ ] Click "Turn On"
  - [ ] Verify progress indicator
  - [ ] Verify toast: "2/3 accessories updated" (or similar partial success message)
  - [ ] Verify 2 success toasts for online accessories, 1 error toast for offline
- [ ] Open Rails console: `ControlEvent.where(characteristic: 'On').last(3)` — verify 3 control events logged (2 success, 1 failure)
- [ ] Verify individual failure doesn't stop entire batch (all 3 accessories attempted, not just first 2)

### Favorites
- [ ] Navigate to a room page: `http://localhost:3000/rooms/:id`
- [ ] Locate the star button (top-right corner of any control card)
- [ ] Click star button — verify:
  - [ ] Star icon fills (becomes solid/yellow)
  - [ ] Green toast: "[Accessory Name] added to favorites"
  - [ ] API call to `POST /favorites/toggle` (check DevTools Network tab)
- [ ] Navigate to favorites page: `http://localhost:3000/favorites`
- [ ] Verify favorites page shows:
  - [ ] Breadcrumb: Dashboard → Favorites
  - [ ] Heading: "Favorites"
  - [ ] Subheading: "Quick access to your starred accessories. Drag to reorder."
  - [ ] Grid of favorite accessories with inline controls
  - [ ] Each favorite shows: accessory name, appropriate control component, filled star button
- [ ] Verify starred accessory from previous step appears in grid
- [ ] Test drag-to-reorder (if implemented):
  - [ ] Drag an accessory card to new position
  - [ ] Release drop
  - [ ] Verify API call to `PATCH /favorites/reorder` (check DevTools Network tab)
  - [ ] Refresh page (`Cmd+R` or `F5`)
  - [ ] Verify new order persists
- [ ] Click filled star button on a favorite — verify:
  - [ ] Star icon empties (becomes outline)
  - [ ] Toast: "[Accessory Name] removed from favorites"
  - [ ] Accessory removed from favorites grid
- [ ] Refresh favorites page — verify accessory no longer appears
- [ ] Navigate back to room page — verify star button is empty (unfavorited state)
- [ ] Refresh page multiple times — verify favorites persist across page refreshes

### Cross-Cutting
- [ ] Keyboard navigation: Tab through controls, Enter to activate, Escape to close modals
- [ ] Mobile: all touch targets ≥ 44x44px, sliders work with swipe
- [ ] Error handling: disconnect Prefab, attempt control, verify error toast + UI rollback
- [ ] Performance: load room with 20+ accessories, verify no visible lag

---

## 11. Test Reporting

### Success Criteria

- ✅ All test cases pass with 100% success rate
- ✅ No JavaScript console errors
- ✅ No Rails log errors (warnings acceptable)
- ✅ All controls complete within 500ms latency
- ✅ Zero N+1 queries in any view
- ✅ All interactive elements keyboard accessible
- ✅ Mobile touch targets ≥ 44x44px

### Defect Triage

| Priority | Definition | Response Time |
|----------|-----------|---------------|
| P0 - Blocking | Test fails, feature unusable | Immediate |
| P1 - High | Test fails, feature partially unusable | 24 hours |
| P2 - Medium | Test passes, but defect affects UX | 1 week |
| P3 - Low | Minor UX issues, cosmetic | Next sprint |

### Test Results Template

```
Test Run: Epic 5 Manual Testing
Date: 2026-02-15
Tester: [Name]

## Summary
- Total Tests: [X]
- Passed: [X]
- Failed: [X]
- Skipped: [X]

## Critical Issues
- [Issue description] - [Priority]

## Minor Issues
- [Issue description] - [Priority]

## Observations
- [Any additional notes]
```

---

**Document Version:** 1.0  
**Last Updated:** 2026-02-15  
**Next Review:** 2026-02-22
