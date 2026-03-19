# Epic 5: Interactive HomeKit Device Controls — Implementation Plan

**Version:** 1.0  
**Date:** 2026-02-15  
**Epic Owner:** Engineering  
**Audience:** Frontend Developers, Backend Developers, QA, UI/UX  
**Status:** Planning

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current State Assessment](#2-current-state-assessment)
3. [Architecture Overview](#3-architecture-overview)
4. [Sprint & Phase Breakdown](#4-sprint--phase-breakdown)
5. [PRD-by-PRD Implementation Details](#5-prd-by-prd-implementation-details)
6. [Frontend Implementation Guide](#6-frontend-implementation-guide)
7. [Backend Implementation Guide](#7-backend-implementation-guide)
8. [QA Test Plan](#8-qa-test-plan)
9. [UI/UX Design Requirements](#9-uiux-design-requirements)
10. [Cross-Cutting Concerns](#10-cross-cutting-concerns)
11. [Risk Register & Mitigations](#11-risk-register--mitigations)
12. [Definition of Done](#12-definition-of-done)
13. [Appendices](#13-appendices)

---

## 1. Executive Summary

Epic 5 transforms the eureka-homekit application from a **read-only monitoring dashboard** (Epic 2) into a **fully interactive HomeKit control interface**. Users will be able to control lights, locks, thermostats, switches, fans, blinds, garage doors, execute scenes, batch-control multiple accessories, and manage a favorites dashboard — all from the web UI.

### Key Numbers

| Metric | Value |
|--------|-------|
| Total PRDs | 8 (PRD 5-01 through 5-08) |
| New/Modified Models | 2 (ControlEvent ✅, UserPreference ❌) |
| New Services | 1 (PrefabControlService ✅) |
| New ViewComponents | ~15 total |
| New Stimulus Controllers | ~12 total |
| New Controllers | 3 (Accessories ✅, Scenes ✅, Favorites ✅) |
| Estimated Total Effort | 20–29 days (4–6 weeks) |

### Implementation Progress (as of 2026-02-15)

A significant portion of the core implementation has been completed. The focus going forward is on **filling gaps, hardening test coverage, adding missing shared components, and completing the Batch/Favorites feature set**.

---

## 2. Current State Assessment

### ✅ Completed (PRDs 5-01 through 5-07 — Core Implementation)

| Artifact | Status | Location |
|----------|--------|----------|
| `PrefabControlService` | ✅ Done | `app/services/prefab_control_service.rb` |
| `PrefabClient` write methods | ✅ Done | `app/services/prefab_client.rb` |
| `ControlEvent` model + migration | ✅ Done | `app/models/control_event.rb`, `db/migrate/20260214165835_create_control_events.rb` |
| `AccessoriesController` (control + batch_control) | ✅ Done | `app/controllers/accessories_controller.rb` |
| `ScenesController` (index, show, execute) | ✅ Done | `app/controllers/scenes_controller.rb` |
| `FavoritesController` (index) | ✅ Done | `app/controllers/favorites_controller.rb` |
| Scene views (index, show) | ✅ Done | `app/views/scenes/` |
| Favorites view (index) | ✅ Done | `app/views/favorites/index.html.erb` |
| Routes (scenes, accessories, favorites) | ✅ Done | `config/routes.rb` |
| `Shared::ConfirmationModalComponent` | ✅ Done | `app/components/shared/` |
| 11 control ViewComponents | ✅ Done | `app/components/controls/` |
| `Scenes::CardComponent` | ✅ Done | `app/components/scenes/` |
| 12 Stimulus controllers | ✅ Done | `app/javascript/controllers/` |
| Toast notification system | ✅ Done | `app/javascript/controllers/toast_controller.js` |
| All 11 component specs | ✅ Done | `spec/components/controls/` |
| AccessoriesController spec | ✅ Done | `spec/controllers/accessories_controller_spec.rb` |
| PrefabControlService spec | ✅ Done | `spec/services/prefab_control_service_spec.rb` |
| PrefabClient spec | ✅ Done | `spec/services/prefab_client_spec.rb` |
| ControlEvent model spec | ✅ Done | `spec/models/control_event_spec.rb` |

### ❌ Gaps Identified

| Gap | Priority | PRD Source | Owner |
|-----|----------|-----------|-------|
| `ScenesController` spec (controller tests) | **P0** | PRD 5-02 | Backend |
| `Scenes::CardComponent` spec | **P0** | PRD 5-02 | Backend |
| `Scenes::ListComponent` (grouped scene grid) | **P1** | PRD 5-02 | Frontend + Backend |
| `Shared::ControlFeedbackComponent` (loading/success/error) | **P1** | Overview | Frontend + Backend |
| `Shared::MultiSelectComponent` (checkbox selection) | **P1** | PRD 5-08 | Frontend |
| `Dashboards::FavoritesComponent` (favorites dashboard) | **P1** | PRD 5-08 | Frontend + Backend |
| `UserPreference` model + migration | **P1** | PRD 5-08 | Backend |
| `FavoritesController` spec | **P1** | PRD 5-08 | Backend |
| System / Capybara tests (end-to-end) | **P2** | All PRDs | QA |
| Integration tests (multi-layer) | **P2** | All PRDs | QA + Backend |
| Rate limiting (10 controls/sec/IP) | **P2** | Overview | Backend |
| Request deduplication | **P2** | Audit | Backend |
| Scene caching (5-min TTL) | **P3** | PRD 5-02 | Backend |
| `ControlEvent` retention policy (30 days) | **P3** | PRD 5-01 | Backend |

---

## 3. Architecture Overview

### Data Flow

```
┌──────────────┐     ┌───────────────┐     ┌─────────────────────┐     ┌──────────────┐
│  Browser UI  │────▶│  Stimulus JS  │────▶│  Rails Controller   │────▶│  Prefab API  │
│  (DaisyUI)   │◀────│  Controllers  │◀────│  (Accessories/      │◀────│  (HomeKit    │
│              │     │               │     │   Scenes)           │     │   Proxy)     │
└──────────────┘     └───────────────┘     └─────────┬───────────┘     └──────────────┘
                                                     │
                                               ┌─────▼─────────────┐
                                               │ PrefabControl     │
                                               │ Service            │
                                               │ (retry, audit,    │
                                               │  logging)         │
                                               └─────┬─────────────┘
                                                     │
                                           ┌─────────▼──────────┐
                                           │ PrefabClient       │
                                           │ (curl/Open3 HTTP)  │
                                           └────────────────────┘
                                                     │
                                           ┌─────────▼──────────┐
                                           │ ControlEvent       │
                                           │ (audit log)        │
                                           └────────────────────┘
```

### Component Hierarchy

```
Controls::AccessoryControlComponent (dispatcher)
├── Controls::LightControlComponent
│   ├── Controls::ColorPickerComponent
│   └── Brightness slider (inline)
├── Controls::SwitchControlComponent
├── Controls::OutletControlComponent
├── Controls::ThermostatControlComponent
├── Controls::LockControlComponent
│   └── Shared::ConfirmationModalComponent
├── Controls::FanControlComponent
├── Controls::BlindControlComponent
├── Controls::GarageDoorControlComponent
│   └── Shared::ConfirmationModalComponent
└── Controls::BatchControlComponent
    └── Shared::MultiSelectComponent (NEW)

Scenes::ListComponent (NEW)
└── Scenes::CardComponent

Dashboards::FavoritesComponent (NEW)
└── Controls::AccessoryControlComponent (per favorite)

Shared::ControlFeedbackComponent (NEW — loading/success/error)
```

### Key Architectural Patterns (Established)

| Pattern | Description |
|---------|-------------|
| **Dispatcher** | `AccessoryControlComponent` detects accessory type from sensors and delegates to correct sub-component |
| **Command Flow** | Stimulus JS → `AccessoriesController#control` → `PrefabControlService` → `PrefabClient` (Open3.capture3 curl) |
| **Optimistic UI** | UI updates immediately; rolls back on error |
| **Toast Feedback** | All controllers dispatch `window.dispatchEvent(new CustomEvent('toast:show', { detail: { message, type, duration } }))` |
| **Offline Detection** | `@accessory.sensors.any?(&:offline?)` — disables controls |
| **State Coercion** | `Sensor#boolean_value?` for state checks (not manual string comparison) |
| **Security Confirmation** | Inline `ConfirmationModalComponent` for Locks and Garage Doors |
| **Retry** | 3 attempts with 500ms sleep in `PrefabControlService` |
| **Audit Logging** | Every control action → `ControlEvent` with user_ip, source, latency, success/error |
| **UUID Routing** | All component templates use `@accessory.uuid` (not `@accessory.id`) for Stimulus data attributes |
| **Debounce** | Switch: 200ms, Sliders: 300ms, Thermostat: 500ms (intentional variance by interaction type) |

---

## 4. Sprint & Phase Breakdown

### Phase 1: Foundation Hardening (Sprint 1 — ~5 days)

> **Goal:** Fill all P0 gaps, ensure existing implementation is fully tested and stable.

| Task ID | Task | Owner | Est. | Depends On |
|---------|------|-------|------|------------|
| 1.1 | Write `ScenesController` spec (index, show, execute — success + all error paths) | Backend | 1d | — |
| 1.2 | Write `Scenes::CardComponent` spec | Backend | 0.5d | — |
| 1.3 | Create `Shared::ControlFeedbackComponent` (loading spinner, success check, error X + message) | Frontend + Backend | 1d | — |
| 1.4 | Create `Scenes::ListComponent` (wraps card grid + grouping by home + empty state) | Frontend + Backend | 1d | 1.2 |
| 1.5 | Refactor Scene views to use `Scenes::ListComponent` | Frontend | 0.5d | 1.4 |
| 1.6 | Add rate limiting to `AccessoriesController` (10 req/sec/IP) | Backend | 0.5d | — |
| 1.7 | Add request deduplication to `PrefabControlService` (prevent double-tap) | Backend | 0.5d | — |

### Phase 2: Batch & Favorites Completion (Sprint 2 — ~5 days)

> **Goal:** Complete PRD 5-08 feature set — the only PRD with significant remaining work.

| Task ID | Task | Owner | Est. | Depends On |
|---------|------|-------|------|------------|
| 2.1 | Create `UserPreference` model + migration (favorites, session_id, ordering) | Backend | 0.5d | — |
| 2.2 | Create `Shared::MultiSelectComponent` (checkbox list, select all/none, count) | Frontend + Backend | 1d | — |
| 2.3 | Create `Dashboards::FavoritesComponent` (starred accessories + inline controls) | Frontend + Backend | 1.5d | 2.1 |
| 2.4 | Implement star/unstar toggle (Stimulus + API endpoint on FavoritesController) | Frontend + Backend | 1d | 2.1 |
| 2.5 | Implement drag-and-drop reordering for favorites (SortableJS or Stimulus Sortable) | Frontend | 1d | 2.3 |
| 2.6 | Write `FavoritesController` spec | Backend | 0.5d | 2.4 |
| 2.7 | Write `UserPreference` model spec | Backend | 0.5d | 2.1 |
| 2.8 | Write `Dashboards::FavoritesComponent` spec | Backend | 0.5d | 2.3 |
| 2.9 | Write `Shared::MultiSelectComponent` spec | Backend | 0.5d | 2.2 |

### Phase 3: End-to-End Testing & Polish (Sprint 3 — ~5 days)

> **Goal:** System tests, integration tests, accessibility pass, performance validation.

| Task ID | Task | Owner | Est. | Depends On |
|---------|------|-------|------|------------|
| 3.1 | Write Capybara system tests: Scene execution flow | QA + Backend | 1d | Phase 1 |
| 3.2 | Write Capybara system tests: Light control flow (toggle, brightness, color) | QA + Backend | 1d | — |
| 3.3 | Write Capybara system tests: Lock control flow (confirm, lock, unlock) | QA + Backend | 0.5d | — |
| 3.4 | Write Capybara system tests: Thermostat control flow | QA + Backend | 0.5d | — |
| 3.5 | Write Capybara system tests: Batch control flow | QA + Backend | 0.5d | Phase 2 |
| 3.6 | Write Capybara system tests: Favorites dashboard flow | QA + Backend | 0.5d | Phase 2 |
| 3.7 | Accessibility audit (WCAG AA): keyboard nav, screen reader, focus, contrast | UI/UX + QA | 1d | — |
| 3.8 | Mobile responsiveness audit (all control components, 44px targets, swipe) | UI/UX + QA | 0.5d | — |
| 3.9 | Performance validation: N+1 queries, <500ms latency, 50+ scene load | QA + Backend | 0.5d | — |
| 3.10 | Add `ControlEvent` retention policy (auto-delete >30 days) | Backend | 0.5d | — |
| 3.11 | Add scene list caching (5-min TTL via `Rails.cache.fetch`) | Backend | 0.5d | — |

### Phase 4: Final Review & Deployment (Sprint 3, second half — ~2 days)

| Task ID | Task | Owner | Est. | Depends On |
|---------|------|-------|------|------------|
| 4.1 | Code review: all new/modified files | All devs | 0.5d | Phases 1–3 |
| 4.2 | Run full test suite, fix failures | All devs | 0.5d | 4.1 |
| 4.3 | Manual smoke test: all 8 accessory types + scenes + batch + favorites | QA | 0.5d | 4.2 |
| 4.4 | Update `0001-IMPLEMENTATION-STATUS.md` with final status | Lead | 0.25d | 4.3 |
| 4.5 | Deploy to staging, verify with real Prefab proxy | DevOps + QA | 0.5d | 4.4 |

---

## 5. PRD-by-PRD Implementation Details

### PRD 5-01: Prefab Write API Integration — ✅ COMPLETE

**Status:** Fully implemented and tested.

| Deliverable | Status | File |
|-------------|--------|------|
| `PrefabClient` write methods | ✅ | `app/services/prefab_client.rb` |
| `PrefabControlService` | ✅ | `app/services/prefab_control_service.rb` |
| `ControlEvent` model | ✅ | `app/models/control_event.rb` |
| Migration | ✅ | `db/migrate/20260214165835_create_control_events.rb` |
| Service spec | ✅ | `spec/services/prefab_control_service_spec.rb` |
| Client spec | ✅ | `spec/services/prefab_client_spec.rb` |
| Model spec | ✅ | `spec/models/control_event_spec.rb` |

**Remaining Work:**
- Task 1.7: Add request deduplication (prevent double-tap within 500ms for same accessory+characteristic)
- Task 3.10: Add `ControlEvent` retention policy (scheduled job to delete records older than 30 days)

---

### PRD 5-02: Scene Management UI — 🟡 MOSTLY COMPLETE

**Status:** Core functionality done; missing test coverage and a shared component.

| Deliverable | Status | File |
|-------------|--------|------|
| `ScenesController` | ✅ | `app/controllers/scenes_controller.rb` |
| Scene views (index, show) | ✅ | `app/views/scenes/` |
| `Scenes::CardComponent` | ✅ | `app/components/scenes/card_component.rb` |
| `Scenes::ListComponent` | ❌ | Not yet created |
| `Shared::ControlFeedbackComponent` | ❌ | Not yet created |
| Scene Stimulus controller | ✅ | `app/javascript/controllers/scene_controller.js` |
| `ScenesController` spec | ❌ | Not yet created |
| `Scenes::CardComponent` spec | ❌ | Not yet created |
| System tests | ❌ | Not yet created |

**Remaining Work:**
- Task 1.1: `ScenesController` spec
- Task 1.2: `Scenes::CardComponent` spec
- Task 1.3: `Shared::ControlFeedbackComponent`
- Task 1.4: `Scenes::ListComponent`
- Task 1.5: Refactor views to use ListComponent
- Task 3.1: Capybara system tests
- Task 3.11: Scene list caching (5-min TTL)

---

### PRD 5-03: Light Controls — ✅ COMPLETE

**Status:** Fully implemented and tested.

| Deliverable | Status | File |
|-------------|--------|------|
| `Controls::LightControlComponent` | ✅ | `app/components/controls/light_control_component.rb` |
| `Controls::ColorPickerComponent` | ✅ | `app/components/controls/color_picker_component.rb` |
| Light Stimulus controller | ✅ | `app/javascript/controllers/light_control_controller.js` |
| Color picker Stimulus controller | ✅ | `app/javascript/controllers/color_picker_controller.js` |
| Component specs | ✅ | `spec/components/controls/light_control_component_spec.rb`, `spec/components/controls/color_picker_component_spec.rb` |

**Remaining Work:**
- Task 3.2: Capybara system tests (toggle, brightness slider, color picker)

---

### PRD 5-04: Switch & Outlet Controls — ✅ COMPLETE

**Status:** Fully implemented and tested.

| Deliverable | Status | File |
|-------------|--------|------|
| `Controls::SwitchControlComponent` | ✅ | `app/components/controls/switch_control_component.rb` |
| `Controls::OutletControlComponent` | ✅ | `app/components/controls/outlet_control_component.rb` |
| Switch Stimulus controller | ✅ | `app/javascript/controllers/switch_control_controller.js` |
| Component specs | ✅ | `spec/components/controls/switch_control_component_spec.rb`, `spec/components/controls/outlet_control_component_spec.rb` |

**Remaining Work:** None (system tests optional, low complexity).

---

### PRD 5-05: Thermostat Controls — ✅ COMPLETE

**Status:** Fully implemented and tested.

| Deliverable | Status | File |
|-------------|--------|------|
| `Controls::ThermostatControlComponent` | ✅ | `app/components/controls/thermostat_control_component.rb` |
| Thermostat Stimulus controller | ✅ | `app/javascript/controllers/thermostat_control_controller.js` |
| Component spec | ✅ | `spec/components/controls/thermostat_control_component_spec.rb` |

**Remaining Work:**
- Task 3.4: Capybara system tests (temp slider, mode selector, units toggle)

---

### PRD 5-06: Lock Controls — ✅ COMPLETE

**Status:** Fully implemented and tested.

| Deliverable | Status | File |
|-------------|--------|------|
| `Controls::LockControlComponent` | ✅ | `app/components/controls/lock_control_component.rb` |
| Lock Stimulus controller | ✅ | `app/javascript/controllers/lock_control_controller.js` |
| `Shared::ConfirmationModalComponent` | ✅ | `app/components/shared/confirmation_modal_component.rb` |
| Component spec | ✅ | `spec/components/controls/lock_control_component_spec.rb` |

**Remaining Work:**
- Task 3.3: Capybara system tests (confirm dialog, lock/unlock flow)

---

### PRD 5-07: Advanced Controls (Fans, Blinds, Garage Doors) — ✅ COMPLETE

**Status:** Fully implemented and tested.

| Deliverable | Status | File |
|-------------|--------|------|
| `Controls::FanControlComponent` | ✅ | `app/components/controls/fan_control_component.rb` |
| `Controls::BlindControlComponent` | ✅ | `app/components/controls/blind_control_component.rb` |
| `Controls::GarageDoorControlComponent` | ✅ | `app/components/controls/garage_door_control_component.rb` |
| Fan Stimulus controller | ✅ | `app/javascript/controllers/fan_control_controller.js` |
| Blind Stimulus controller | ✅ | `app/javascript/controllers/blind_control_controller.js` |
| Garage Door Stimulus controller | ✅ | `app/javascript/controllers/garage_door_control_controller.js` |
| Component specs | ✅ | `spec/components/controls/fan_control_component_spec.rb`, `spec/components/controls/blind_control_component_spec.rb`, `spec/components/controls/garage_door_control_component_spec.rb` |

**Remaining Work:** None (system tests optional).

---

### PRD 5-08: Batch Controls & Favorites — 🟡 PARTIALLY COMPLETE

**Status:** Batch control backend and basic UI exist. Favorites has a controller and view but lacks the model layer and full component set.

| Deliverable | Status | File |
|-------------|--------|------|
| `AccessoriesController#batch_control` | ✅ | `app/controllers/accessories_controller.rb` |
| `Controls::BatchControlComponent` | ✅ | `app/components/controls/batch_control_component.rb` |
| Batch Stimulus controller | ✅ | `app/javascript/controllers/batch_control_controller.js` |
| `FavoritesController` | ✅ | `app/controllers/favorites_controller.rb` |
| Favorites view | ✅ | `app/views/favorites/index.html.erb` |
| Favorites Stimulus controller | ✅ | `app/javascript/controllers/favorites_controller.js` |
| `Shared::MultiSelectComponent` | ❌ | Not yet created |
| `Dashboards::FavoritesComponent` | ❌ | Not yet created |
| `UserPreference` model + migration | ❌ | Not yet created |
| Star/unstar API endpoint | ❌ | Not yet created |
| Drag-and-drop reordering | ❌ | Not yet implemented |
| `FavoritesController` spec | ❌ | Not yet created |
| `BatchControlComponent` spec | ✅ | `spec/components/controls/batch_control_component_spec.rb` |
| System tests | ❌ | Not yet created |

**Remaining Work:** Tasks 2.1–2.9, 3.5–3.6

---

## 6. Frontend Implementation Guide

### For Stimulus Controller Developers

#### Established Patterns (Follow These Exactly)

```javascript
// ALL Stimulus controllers MUST follow this pattern:

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [/* ... */]
  static values = {
    accessoryId: String,  // ALWAYS use UUID, not integer ID
    offline: Boolean
  }

  // 1. Debounce pattern
  debounce(fn, delay) {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(fn, delay)
  }

  // 2. Send control command
  async sendControl(characteristic, value) {
    const response = await fetch('/accessories/control', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        accessory_id: this.accessoryIdValue,
        characteristic: characteristic,
        value: value
      })
    })
    return await response.json()
  }

  // 3. Toast feedback (ALWAYS use this, not inline alerts)
  showSuccess(message) {
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: { message, type: 'success', duration: 3000 }
    }))
  }

  showError(message) {
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: { message, type: 'error', duration: 5000 }
    }))
  }

  // 4. Optimistic UI + rollback
  async toggle(event) {
    const oldValue = /* save current state */
    /* update UI immediately */
    const result = await this.sendControl('On', newValue)
    if (!result.success) {
      /* rollback UI to oldValue */
      this.showError(result.error || 'Control failed')
    } else {
      this.showSuccess('Updated successfully')
    }
  }
}
```

#### Debounce Times (Mandatory)

| Control Type | Debounce | Rationale |
|-------------|----------|-----------|
| Switch/Toggle | 200ms | Fast on/off, prevent double-tap |
| Sliders (brightness, position, speed) | 300ms | Continuous input, reduce API calls |
| Thermostat temp | 500ms | Deliberate adjustment, heavier operation |

#### New Components to Build

**`Shared::MultiSelectComponent`** (Task 2.2)
- Checkbox list with `data-controller="multi-select"`
- Targets: `checkbox`, `toolbar`, `countBadge`
- Actions: `selectAll`, `deselectAll`, `toggleSelection`
- Emits custom event: `multi-select:changed` with `detail: { selected: [...uuids] }`

**`Dashboards::FavoritesComponent`** (Task 2.3)
- Uses `data-controller="favorites"` (existing controller)
- Star toggle button on each accessory card
- SortableJS for drag-and-drop reordering
- Persists order via PATCH to `FavoritesController#update_order`

### CSS / DaisyUI Guidelines

- All controls use DaisyUI components (`toggle`, `range`, `btn`, `modal`, `card`)
- Size: `toggle-lg` for switches (44px touch target)
- Range slider: `range range-primary`
- Modals: `<dialog>` element with DaisyUI `modal` class
- Responsive grid: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4`
- Disabled state: add `opacity-50 cursor-not-allowed` + native `disabled` attribute

---

## 7. Backend Implementation Guide

### For Rails Developers

#### New Files to Create

**1. `UserPreference` Model (Task 2.1)**

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_user_preferences.rb
class CreateUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_preferences do |t|
      t.string :session_id, null: false
      t.jsonb :favorites, default: []        # Array of accessory UUIDs
      t.jsonb :favorites_order, default: []   # Ordered array of accessory UUIDs
      t.timestamps
    end
    add_index :user_preferences, :session_id, unique: true
  end
end

# app/models/user_preference.rb
class UserPreference < ApplicationRecord
  validates :session_id, presence: true, uniqueness: true

  def self.for_session(session_id)
    find_or_create_by(session_id: session_id)
  end

  def add_favorite(accessory_uuid)
    self.favorites ||= []
    return if favorites.include?(accessory_uuid)
    self.favorites << accessory_uuid
    self.favorites_order << accessory_uuid
    save!
  end

  def remove_favorite(accessory_uuid)
    self.favorites&.delete(accessory_uuid)
    self.favorites_order&.delete(accessory_uuid)
    save!
  end

  def reorder_favorites(ordered_uuids)
    self.favorites_order = ordered_uuids
    save!
  end
end
```

**2. `Scenes::ListComponent` (Task 1.4)**

```ruby
# app/components/scenes/list_component.rb
class Scenes::ListComponent < ViewComponent::Base
  def initialize(scenes:, show_home: false)
    @scenes = scenes
    @show_home = show_home
  end

  def grouped_scenes
    @scenes.group_by { |s| s.home.name }
  end

  def empty?
    @scenes.empty?
  end
end
```

**3. `Shared::ControlFeedbackComponent` (Task 1.3)**

```ruby
# app/components/shared/control_feedback_component.rb
class Shared::ControlFeedbackComponent < ViewComponent::Base
  STATES = %w[idle loading success error].freeze

  def initialize(state: 'idle', message: nil)
    @state = state
    @message = message
  end
end
```

**4. `Shared::MultiSelectComponent` (Task 2.2)**

```ruby
# app/components/shared/multi_select_component.rb
class Shared::MultiSelectComponent < ViewComponent::Base
  def initialize(items:, id_method: :uuid, label_method: :name)
    @items = items
    @id_method = id_method
    @label_method = label_method
  end
end
```

#### Rate Limiting (Task 1.6)

Add to `AccessoriesController`:

```ruby
# Option A: Rails 8 built-in rate limiting (preferred)
class AccessoriesController < ApplicationController
  rate_limit to: 10, within: 1.second, only: [:control, :batch_control],
             with: -> { render json: { success: false, error: 'Rate limit exceeded' }, status: :too_many_requests }
end

# Option B: If Rails 8 rate_limit not available, use Rack::Attack
# config/initializers/rack_attack.rb
Rack::Attack.throttle('control/ip', limit: 10, period: 1.second) do |req|
  req.ip if req.path.start_with?('/accessories') && req.post?
end
```

#### Request Deduplication (Task 1.7)

```ruby
# In PrefabControlService
def self.set_characteristic(accessory:, characteristic:, value:, user_ip: nil, source: 'web')
  dedup_key = "control:#{accessory.uuid}:#{characteristic}"

  # Skip if identical request within last 500ms
  if Rails.cache.read(dedup_key) == value.to_s
    return { success: true, value: value, deduplicated: true }
  end

  Rails.cache.write(dedup_key, value.to_s, expires_in: 0.5.seconds)

  # ... existing logic
end
```

#### Scene Caching (Task 3.11)

```ruby
# In ScenesController#index
def index
  @scenes = Rails.cache.fetch("scenes:home:#{params[:home_id]}", expires_in: 5.minutes) do
    Scene.includes(:home, :accessories).where(filter_params).order(name: :asc).to_a
  end
end
```

#### ControlEvent Retention (Task 3.10)

```ruby
# app/jobs/cleanup_control_events_job.rb
class CleanupControlEventsJob < ApplicationJob
  queue_as :low

  def perform
    ControlEvent.where('created_at < ?', 30.days.ago).delete_all
  end
end

# config/recurring.yml (Solid Queue)
cleanup_control_events:
  class: CleanupControlEventsJob
  schedule: every day at 3am
```

#### FavoritesController Enhancements (Tasks 2.4, 2.5)

```ruby
# app/controllers/favorites_controller.rb — add these actions
class FavoritesController < ApplicationController
  def index
    pref = UserPreference.for_session(session.id.to_s)
    @favorites = Accessory.where(uuid: pref.favorites_order.presence || pref.favorites)
                          .includes(:sensors, room: :home)
  end

  def toggle
    pref = UserPreference.for_session(session.id.to_s)
    uuid = params[:accessory_uuid]

    if pref.favorites.include?(uuid)
      pref.remove_favorite(uuid)
      render json: { favorited: false }
    else
      pref.add_favorite(uuid)
      render json: { favorited: true }
    end
  end

  def reorder
    pref = UserPreference.for_session(session.id.to_s)
    pref.reorder_favorites(params[:ordered_uuids])
    render json: { success: true }
  end
end
```

Update routes:
```ruby
resources :favorites, only: [:index] do
  collection do
    post :toggle
    patch :reorder
  end
end
```

---

## 8. QA Test Plan

### Test Matrix

#### Unit Tests (RSpec — Backend)

| Spec File | Status | PRD | Priority |
|-----------|--------|-----|----------|
| `spec/services/prefab_control_service_spec.rb` | ✅ Exists | 5-01 | — |
| `spec/services/prefab_client_spec.rb` | ✅ Exists | 5-01 | — |
| `spec/models/control_event_spec.rb` | ✅ Exists | 5-01 | — |
| `spec/controllers/accessories_controller_spec.rb` | ✅ Exists (381 lines) | 5-01 | — |
| `spec/controllers/scenes_controller_spec.rb` | ❌ **TO CREATE** | 5-02 | **P0** |
| `spec/controllers/favorites_controller_spec.rb` | ❌ **TO CREATE** | 5-08 | **P1** |
| `spec/models/user_preference_spec.rb` | ❌ **TO CREATE** | 5-08 | **P1** |
| `spec/components/scenes/card_component_spec.rb` | ❌ **TO CREATE** | 5-02 | **P0** |
| `spec/components/scenes/list_component_spec.rb` | ❌ **TO CREATE** | 5-02 | **P1** |
| `spec/components/shared/control_feedback_component_spec.rb` | ❌ **TO CREATE** | All | **P1** |
| `spec/components/shared/multi_select_component_spec.rb` | ❌ **TO CREATE** | 5-08 | **P1** |
| `spec/components/dashboards/favorites_component_spec.rb` | ❌ **TO CREATE** | 5-08 | **P1** |
| All 11 control component specs | ✅ Exist | 5-03–5-07 | — |

#### ScenesController Spec (Task 1.1) — Test Cases

```
describe ScenesController do
  describe 'GET #index' do
    - returns HTTP 200
    - assigns all scenes
    - filters scenes by home_id param
    - searches scenes by name (ILIKE)
    - returns empty set when no scenes match
    - eager loads home and accessories (no N+1)
  end

  describe 'GET #show' do
    - returns HTTP 200
    - assigns scene with associations
    - loads execution history (last 20 ControlEvents)
    - returns 404 for nonexistent scene
  end

  describe 'POST #execute' do
    - returns JSON { success: true } on success
    - calls PrefabControlService.trigger_scene with correct args
    - passes request.remote_ip as user_ip
    - returns 422 with error message on PrefabControlService failure
    - returns 500 on unexpected exception
    - creates ControlEvent record
  end
end
```

#### System Tests (Capybara — Task 3.1 through 3.6)

| Test File | Scenarios | Priority |
|-----------|-----------|----------|
| `spec/system/scenes_spec.rb` | Visit index, filter by home, search, execute scene, see toast, loading state | **P2** |
| `spec/system/light_controls_spec.rb` | Toggle on/off, adjust brightness slider, open color picker | **P2** |
| `spec/system/lock_controls_spec.rb` | Click unlock, see confirmation modal, confirm, see locked state | **P2** |
| `spec/system/thermostat_controls_spec.rb` | Adjust temp with +/-, change mode, toggle units | **P2** |
| `spec/system/batch_controls_spec.rb` | Select multiple, click Turn On, see progress, see results | **P2** |
| `spec/system/favorites_spec.rb` | Star accessory, see on favorites page, reorder, unstar | **P2** |

#### Manual Smoke Test Checklist (Task 4.3)

QA should execute the following **with a running Prefab proxy**:

**Scene Management:**
- [ ] Navigate to `/scenes` — verify grid loads
- [ ] Filter by home — verify results narrow
- [ ] Search by name — verify match
- [ ] Click Execute on a scene — verify spinner, then success toast
- [ ] Execute scene when Prefab offline — verify error toast
- [ ] Verify `ControlEvent.last` logs the execution

**Light Controls:**
- [ ] Toggle a light on — verify immediate UI change + toast
- [ ] Toggle off — verify rollback
- [ ] Drag brightness slider — verify value updates after debounce
- [ ] Open color picker — verify hue/saturation change
- [ ] Control offline light — verify disabled state

**Switch/Outlet:**
- [ ] Toggle switch on/off — verify optimistic update
- [ ] Control offline outlet — verify disabled + offline badge

**Thermostat:**
- [ ] Adjust target temp via slider — verify debounced update
- [ ] Click +/- buttons — verify 1° increment
- [ ] Change mode (Heat/Cool/Auto/Off) — verify API call
- [ ] Toggle °C/°F — verify display updates

**Lock:**
- [ ] Click Unlock — verify confirmation modal appears
- [ ] Cancel modal — verify no action
- [ ] Confirm unlock — verify state change + audit log
- [ ] Click Lock — verify no confirmation needed + immediate lock

**Fan:**
- [ ] Toggle on — verify speed slider appears
- [ ] Adjust speed — verify debounced update
- [ ] Toggle direction (if supported) — verify change

**Blinds:**
- [ ] Drag position slider — verify update
- [ ] Click "50%" quick action — verify position
- [ ] Click Open / Close — verify endpoints
- [ ] Adjust tilt (if supported)

**Garage Door:**
- [ ] Click Open — verify confirmation modal for BOTH open and close
- [ ] Verify obstruction warning when `Obstruction Detected` is true
- [ ] Verify all 5 states display correctly

**Batch Controls:**
- [ ] Select 3+ accessories — verify toolbar appears with count
- [ ] Click Select All / Deselect All
- [ ] Click "Turn On" batch — verify progress indicator
- [ ] Verify individual failure doesn't stop batch
- [ ] Verify `ControlEvent` records for each accessory

**Favorites:**
- [ ] Star an accessory — verify star icon fills
- [ ] Navigate to `/favorites` — verify starred accessories appear
- [ ] Drag to reorder — verify new order persists
- [ ] Unstar — verify removal from favorites page
- [ ] Verify favorites persist across page refreshes

**Cross-Cutting:**
- [ ] Keyboard navigation: Tab through controls, Enter to activate, Escape to close modals
- [ ] Mobile: all touch targets ≥ 44x44px, sliders work with swipe
- [ ] Error handling: disconnect Prefab, attempt control, verify error toast + UI rollback
- [ ] Performance: load room with 20+ accessories, verify no visible lag

---

## 9. UI/UX Design Requirements

### Visual Design System

| Element | DaisyUI Class | Notes |
|---------|---------------|-------|
| Toggle switch | `toggle toggle-lg toggle-primary` | 44px min, large for mobile |
| Slider (brightness, temp) | `range range-primary range-sm` | Full-width on mobile |
| Action button | `btn btn-primary` (normal) / `btn btn-warning` (destructive) | |
| Confirmation modal | `modal` with `<dialog>` | Native HTML dialog |
| Scene card | `card bg-white border border-gray-200 rounded-lg p-4 hover:shadow-lg` | |
| Toast notification | `toast` (via toast_controller.js) | Auto-dismiss: 3s success, 5s error |
| Disabled control | `opacity-50 cursor-not-allowed` + `disabled` attribute | |
| Loading spinner | `loading loading-spinner loading-md` | Show during API calls |
| Offline badge | `badge badge-error badge-sm` with text "Offline" | |

### Layout Specifications

| View | Desktop | Tablet | Mobile |
|------|---------|--------|--------|
| Scene grid | 4 columns | 2 columns | 1 column |
| Control cards | 3 columns | 2 columns | 1 column |
| Favorites grid | 4 columns | 2 columns | 1 column |

### Accessibility Requirements (WCAG AA)

| Requirement | Implementation |
|-------------|----------------|
| Focus indicators | DaisyUI default focus ring (verify contrast) |
| Keyboard navigation | Tab through all controls; Enter/Space to activate; Escape to close modals |
| Screen reader labels | `aria-label` on all interactive elements; `role="status"` on feedback |
| Slider a11y | `aria-valuemin`, `aria-valuemax`, `aria-valuenow`, `aria-label` |
| Color contrast | 4.5:1 minimum for text; 3:1 for UI components |
| Reduced motion | `prefers-reduced-motion` media query — disable spinner animation |
| Modal focus trap | Focus stays within open modal; returns to trigger on close |

### Empty States

| View | Message | Icon |
|------|---------|------|
| Scenes (none) | "No scenes configured. Use the Apple Home app to create scenes." | ⚡ |
| Favorites (none) | "No favorites yet. Star accessories from any room page for quick access." | ⭐ |
| Room (no controllable) | "No controllable accessories in this room." | 🔌 |
| Batch (none selected) | Toolbar hidden (no empty state needed) | — |

---

## 10. Cross-Cutting Concerns

### Security

| Concern | Status | Action |
|---------|--------|--------|
| Confirmation dialogs (Lock, Garage Door) | ✅ Implemented | — |
| Audit logging (all control actions) | ✅ Implemented | — |
| IP address tracking | ✅ Implemented | — |
| Rate limiting (10 req/sec/IP) | ❌ Missing | Task 1.6 |
| Request deduplication | ❌ Missing | Task 1.7 |
| CSRF tokens on all POST/PATCH | ✅ Implemented | Stimulus controllers include CSRF header |
| No authentication (single-user) | ✅ By design | Epic 8 scope |

### Performance

| Concern | Target | Status | Action |
|---------|--------|--------|--------|
| Control latency | <500ms (P95) | ✅ Measured via `ControlEvent.latency_ms` | — |
| N+1 queries | 0 | ✅ Eager loading in controllers | Verify in Task 3.9 |
| Scene list caching | 5-min TTL | ❌ Missing | Task 3.11 |
| 50+ scenes load | No degradation | ❌ Untested | Task 3.9 |
| ControlEvent table growth | 30-day retention | ❌ Missing | Task 3.10 |

### Observability

| Signal | Implementation |
|--------|----------------|
| Control success/failure | `ControlEvent.success` column + scopes |
| Latency | `ControlEvent.latency_ms` column |
| Error logging | `Rails.logger.error` for connection/timeout; `.warn` for validation; `.info` for offline |
| Success rate | `ControlEvent.success_rate(time_range)` class method |
| Average latency | `ControlEvent.average_latency(time_range)` class method |

---

## 11. Risk Register & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Prefab proxy down during testing | Medium | High | Mock all Prefab calls in tests; document manual test with live proxy |
| Double-tap sends duplicate commands | High | Medium | Task 1.7: request deduplication (500ms cache) |
| ControlEvent table grows unbounded | Medium | Medium | Task 3.10: 30-day retention policy |
| Accessibility gaps in custom controls | Medium | High | Task 3.7: dedicated accessibility audit |
| SortableJS conflicts with Stimulus | Low | Medium | Test drag-and-drop early in Phase 2 |
| Session-based favorites lost on session expiry | Medium | Low | Document limitation; future: move to user-auth model in Epic 8 |
| Rate limiting blocks legitimate rapid use | Low | Medium | Set generous limit (10/sec); add bypass for batch operations |

---

## 12. Definition of Done

### Per PRD

- [ ] All acceptance criteria from the PRD are met
- [ ] ViewComponent specs pass (render + all states)
- [ ] Controller specs pass (success + all error paths)
- [ ] Stimulus controller follows established patterns (debounce, toast, optimistic UI, rollback)
- [ ] Offline accessories show disabled state
- [ ] All interactive elements keyboard accessible
- [ ] Mobile touch targets ≥ 44x44px
- [ ] No N+1 queries (verified via Bullet or test logs)
- [ ] Code reviewed by at least 1 other developer

### For Epic 5 Overall

- [ ] All 8 PRDs at "Done" status
- [ ] System tests pass for critical flows (scenes, lights, locks, batch, favorites)
- [ ] Manual smoke test checklist completed by QA
- [ ] Accessibility audit passed (WCAG AA)
- [ ] Rate limiting active
- [ ] Request deduplication active
- [ ] ControlEvent retention policy scheduled
- [ ] Scene caching enabled
- [ ] `0001-IMPLEMENTATION-STATUS.md` updated with final status
- [ ] Control success rate >98% in staging
- [ ] Control latency <500ms (P95) in staging

---

## 13. Appendices

### A. File Inventory

#### Existing Files (No Changes Needed)

```
app/services/prefab_control_service.rb
app/services/prefab_client.rb
app/models/control_event.rb
app/controllers/accessories_controller.rb
app/controllers/scenes_controller.rb
app/controllers/favorites_controller.rb
app/views/scenes/index.html.erb
app/views/scenes/show.html.erb
app/views/favorites/index.html.erb
app/components/controls/accessory_control_component.rb + .html.erb
app/components/controls/light_control_component.rb + .html.erb
app/components/controls/color_picker_component.rb + .html.erb
app/components/controls/switch_control_component.rb + .html.erb
app/components/controls/outlet_control_component.rb + .html.erb
app/components/controls/thermostat_control_component.rb + .html.erb
app/components/controls/lock_control_component.rb + .html.erb
app/components/controls/fan_control_component.rb + .html.erb
app/components/controls/blind_control_component.rb + .html.erb
app/components/controls/garage_door_control_component.rb + .html.erb
app/components/controls/batch_control_component.rb + .html.erb
app/components/scenes/card_component.rb + .html.erb
app/components/shared/confirmation_modal_component.rb + .html.erb
app/javascript/controllers/light_control_controller.js
app/javascript/controllers/color_picker_controller.js
app/javascript/controllers/switch_control_controller.js
app/javascript/controllers/thermostat_control_controller.js
app/javascript/controllers/lock_control_controller.js
app/javascript/controllers/fan_control_controller.js
app/javascript/controllers/blind_control_controller.js
app/javascript/controllers/garage_door_control_controller.js
app/javascript/controllers/batch_control_controller.js
app/javascript/controllers/favorites_controller.js
app/javascript/controllers/scene_controller.js
app/javascript/controllers/toast_controller.js
spec/components/controls/* (11 specs)
spec/controllers/accessories_controller_spec.rb
spec/services/prefab_control_service_spec.rb
spec/services/prefab_client_spec.rb
spec/models/control_event_spec.rb
db/migrate/20260214165835_create_control_events.rb
config/routes.rb
```

#### New Files to Create

```
# Phase 1
app/components/shared/control_feedback_component.rb
app/components/shared/control_feedback_component.html.erb
app/components/scenes/list_component.rb
app/components/scenes/list_component.html.erb
spec/controllers/scenes_controller_spec.rb
spec/components/scenes/card_component_spec.rb
spec/components/scenes/list_component_spec.rb
spec/components/shared/control_feedback_component_spec.rb

# Phase 2
app/models/user_preference.rb
db/migrate/YYYYMMDDHHMMSS_create_user_preferences.rb
app/components/shared/multi_select_component.rb
app/components/shared/multi_select_component.html.erb
app/components/dashboards/favorites_component.rb
app/components/dashboards/favorites_component.html.erb
spec/models/user_preference_spec.rb
spec/controllers/favorites_controller_spec.rb
spec/components/shared/multi_select_component_spec.rb
spec/components/dashboards/favorites_component_spec.rb

# Phase 3
spec/system/scenes_spec.rb
spec/system/light_controls_spec.rb
spec/system/lock_controls_spec.rb
spec/system/thermostat_controls_spec.rb
spec/system/batch_controls_spec.rb
spec/system/favorites_spec.rb
app/jobs/cleanup_control_events_job.rb
spec/jobs/cleanup_control_events_job_spec.rb
```

#### Files to Modify

```
# Phase 1
app/services/prefab_control_service.rb          (add deduplication)
app/controllers/accessories_controller.rb       (add rate limiting)
app/views/scenes/index.html.erb                 (use ListComponent)

# Phase 2
app/controllers/favorites_controller.rb         (add toggle, reorder actions)
config/routes.rb                                (add favorites toggle/reorder routes)
```

### B. Characteristic Reference

| Accessory Type | Characteristics (Writable) | Value Range |
|---------------|---------------------------|-------------|
| Light | `On` (bool), `Brightness` (int), `Hue` (int), `Saturation` (int) | On: true/false, Brightness: 0-100, Hue: 0-360, Saturation: 0-100 |
| Switch | `On` (bool) | true/false |
| Outlet | `On` (bool) | true/false |
| Thermostat | `Target Temperature` (float), `Target Heating Cooling State` (int), `Temperature Display Units` (int) | Temp: 10-38°C, Mode: 0-3, Units: 0-1 |
| Lock | `Lock Target State` (int) | 0=unsecured, 1=secured |
| Fan | `Active` (int), `Rotation Speed` (int), `Rotation Direction` (int), `Swing Mode` (int) | Active: 0-1, Speed: 0-100, Direction: 0-1, Swing: 0-1 |
| Blind | `Target Position` (int), `Target Horizontal Tilt Angle` (int) | Position: 0-100, Tilt: -90 to 90 |
| Garage Door | `Target Door State` (int) | 0=open, 1=closed |

### C. Branch Strategy

| Phase | Branch Name | Base | Merge Target |
|-------|-------------|------|-------------|
| Phase 1 | `epic-5/phase-1-hardening` | `main` | `main` |
| Phase 2 | `epic-5/phase-2-batch-favorites` | `main` (after Phase 1 merge) | `main` |
| Phase 3 | `epic-5/phase-3-testing-polish` | `main` (after Phase 2 merge) | `main` |

### D. Estimated Effort Summary

| Phase | Duration | Backend | Frontend | QA | UI/UX |
|-------|----------|---------|----------|----|-------|
| Phase 1: Hardening | 5 days | 3d | 2d | — | — |
| Phase 2: Batch/Favorites | 5 days | 3d | 3d | — | — |
| Phase 3: Testing/Polish | 5 days | 2d | 1d | 3d | 1.5d |
| Phase 4: Review/Deploy | 2 days | 0.5d | 0.5d | 0.5d | — |
| **Total** | **~17 days** | **8.5d** | **6.5d** | **3.5d** | **1.5d** |

> Note: Some tasks overlap (e.g., Frontend + Backend on same component). Calendar time ≈ 3.5 weeks with parallel work.

---

*End of Implementation Plan*
