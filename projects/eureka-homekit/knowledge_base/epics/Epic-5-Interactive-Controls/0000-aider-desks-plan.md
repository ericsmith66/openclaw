# Strategic Roadmap: Epic 5 Interactive Controls

## 📍 CURRENT EXECUTION CONTEXT (DO NOT MOVE)
*   **Active Project Root**: `/Users/ericsmith66/development/agent-forge/projects/eureka-homekit`
*   **Active Task**: PRD-5-07 (Advanced Controls)
*   **Mandatory Phase Gates**: 
    1.  **Blueprint**: COMPLETED.
    2.  **QA Audit**: **UNAUTHORIZED BYPASS DETECTED.** The "Self-Audit" in Task 2b0e8490 iteration 8 is INVALID. **Claude (QA Subagent)** MUST approve the Blueprint before any code changes.
*   **No-Discovery Rule**: DO NOT use search tools.
*   **Global Directives**: Use `Sensor#boolean_value?` for state; Use `Shared::ConfirmationModalComponent` for secure actions.
*   **Execution Status**: Phase 2 is currently **UNAUTHORIZED**. Stop writing code immediately.

---

Now I have the full picture. Let me update the integration-specific tasks based on what I see.

## Key Findings

### Layout (`application_layout.html.erb`)
- Uses a **drawer layout** with left sidebar (`Layouts::LeftSidebarComponent`) and right sidebar (`Layouts::RightSidebarComponent`)
- Nav links live in `Layouts::LeftSidebarComponent` — I'd need to see that file to know exact placement, but the pattern is clear
- Flash messages already render as alerts at the top — the toast system (5-02-A) should complement, not duplicate this
- Header is `Layouts::HeaderComponent`

### Room Detail (`detail_component.rb` + `.html.erb`)
- **Sensors section**: iterates `sensors` and renders each as a card with icon, characteristic type, accessory name, formatted value, and time ago
- **Other Accessories section**: iterates `other_accessories` and renders each as a simple name + settings button
- **This is the exact integration point** for inline controls. The "Other Accessories" section currently shows accessories with just a name and a placeholder settings button — controls should replace or augment this
- The component receives `room`, `sensors`, and `other_accessories` as separate args from `RoomsController#show`

### Integration Strategy

Controls should be added in two places:

1. **Sensor cards** (left column): For sensors that are writable (`is_writable: true`), add an inline control next to the value display (e.g., toggle for `On`, small slider for `Brightness`)
2. **Other Accessories cards** (right column): Replace the placeholder settings button with the appropriate control component based on the accessory's sensor combination

The cleanest approach: create a **`Controls::AccessoryControlComponent`** dispatcher that detects accessory type from its sensors and renders the appropriate control sub-component. This avoids cluttering the room detail template with type-detection logic.

## Revised/New Tasks

Here are the specific tasks that change based on these findings:

### New Task (add to 5-03, before integration tasks)

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-03-F0 | **Create `Controls::AccessoryControlComponent` dispatcher** | `initialize(accessory:, compact: false)`. Inspects `accessory.sensors` to detect type: has `Brightness`/`Hue` → render `LightControlComponent`; has `On` only → render `SwitchControlComponent`; has `Target Temperature` → render `ThermostatControlComponent`; has `Lock Current State` → render `LockControlComponent`; has `Rotation Speed` → render `FanControlComponent`; has `Target Position` → render `BlindControlComponent`; has `Current Door State` → render `GarageDoorControlComponent`; else → render nothing. `compact:` flag controls whether to show minimal inline controls or full card. Component tests verify correct dispatch for each type. | 1h |

### Updated: Room Detail Integration (replaces 5-03-F, 5-04-D, 5-05-D, 5-06-E, 5-07-G)

Instead of each PRD adding its own integration code to the room detail view, we do it **once** with the dispatcher, then each PRD just needs to ensure its component is registered with the dispatcher.

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-03-F | **Integrate controls into `Rooms::DetailComponent`** | Modify `detail_component.rb`: accept new `controllable_accessories:` arg (or compute from existing `other_accessories` by checking for writable sensors). Modify `detail_component.html.erb`: in the "Other Accessories" section, replace the placeholder settings button with `<%= render Controls::AccessoryControlComponent.new(accessory: accessory, compact: true) %>`. In `RoomsController#show`, eager load `accessories.includes(:sensors)` to prevent N+1. Initially only `LightControlComponent` and `SwitchControlComponent` will render (since those are built first); others will be picked up automatically as PRDs complete. | 1h |

This means tasks 5-04-D, 5-05-D, 5-06-E, and 5-07-G become **trivial** — just "register your component in the dispatcher's type detection" (~5 min each), which I'll fold into the component creation tasks for those PRDs.

### Updated: Toast System (5-02-A)

The layout already has flash-based alerts. The toast system should:
- **Not duplicate** the existing flash alerts
- Be JS-driven (dispatched from Stimulus controllers via `CustomEvent`)
- Render as fixed-position toasts in the bottom-right (distinct from the top-right flash alerts)
- Auto-dismiss success toasts after 3s

---

## Final Revised Plan

### PRD 5-01: Prefab Write API Integration (no changes)

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-01-A | Create `ControlEvent` migration and model | Migration per PRD schema. Model: validations, associations, scopes, class methods. Tests. | 1h |
| 5-01-B | Refactor existing `execute_curl` to use `Open3` | Replace backtick interpolation with `Open3.capture2`. Add HTTP status code parsing. Fix for all existing read methods. Ensure existing tests pass. | 1.5h |
| 5-01-C | Add `execute_curl_put` and `execute_curl_post` private methods | `Open3.capture2` pattern, configurable timeout, return structured hash with `http_status`. Tests. | 1.5h |
| 5-01-D | Add `update_characteristic` to `PrefabClient` | URL-encoded path, JSON payload, structured response, severity-appropriate logging. Tests. | 1h |
| 5-01-E | Add `execute_scene` to `PrefabClient` | POST pattern, structured response. Tests. | 0.75h |
| 5-01-F | Create `PrefabControlService` | `set_characteristic` and `trigger_scene` with retry, latency tracking, `ControlEvent` creation. Tests. | 2h |
| 5-01-G | Add `Sensor#boolean_value?` helper | Handle jsonb coercion: `true`, `1`, `"1"`, `"true"`. Update `format_value` for `On`. Tests. | 0.5h |
| 5-01-H | Integration tests | End-to-end flows, retry logic, concurrent writes. | 1.5h |
| 5-01-I | Manual verification & task log | Follow PRD checklist, create log file. | 0.5h |
| | **Total** | | **10.25h** |

---

### PRD 5-04: Switch & Outlet Controls (moved before 5-02)

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-04-A | Create `Controls::SwitchControlComponent` | Find `On` sensor, `current_state` via `boolean_value?`, `offline?` via sensor's method. Component tests. | 0.75h |
| 5-04-B | Create switch control template | DaisyUI toggle, disabled when offline, 44x44px touch target. Stimulus wiring. | 0.5h |
| 5-04-C | Create `switch_control_controller.js` | Optimistic toggle, POST to control endpoint, rollback + toast on error. | 1h |
| 5-04-D | Tests | Component tests (on/off/offline/sizes). System test (toggle, rollback). | 1h |
| 5-04-E | Manual verification & task log | Test against real devices. | 0.25h |
| | **Total** | | **3.5h** |

*Note: integration into room view handled by 5-03-F via dispatcher*

---

### PRD 5-02: Scene Management UI

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-02-A | Create shared toast notification system | `toast_controller.js` Stimulus controller, listens for `toast:show` CustomEvents, renders fixed-position toasts (bottom-right), auto-dismiss success (3s). Add toast container to `application_layout.html.erb`. Tests. | 1.5h |
| 5-02-B | Add scenes routes | `resources :scenes` with `execute` member route. | 0.25h |
| 5-02-C | Create `ScenesController` | `index` (filters, search, eager load), `show` (execution history), `execute` (JSON response). Tests. | 2h |
| 5-02-D | Create `Scenes::CardComponent` | Emoji heuristic, accessories count (`.size`), last executed from `ControlEvent`. Template with execute button. Tests. | 1.5h |
| 5-02-E | Create `scene_controller.js` Stimulus controller | POST execute, loading spinner, success/error feedback, dispatch toast events. | 1.5h |
| 5-02-F | Create `scenes/index.html.erb` | Breadcrumb, filters, responsive grid, empty state. | 1h |
| 5-02-G | Create `scenes/show.html.erb` | Detail page with accessories list and execution history table. | 1h |
| 5-02-H | Add Scenes to left sidebar navigation | Add link in `Layouts::LeftSidebarComponent`. | 0.5h |
| 5-02-I | Tests | Controller, component, integration, system tests. | 2h |
| 5-02-J | Manual verification & task log | Follow 11-step checklist. | 0.5h |
| | **Total** | | **11.75h** |

---

### PRD 5-03: Light Controls

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-03-A | Create `AccessoriesController` with `control` action | Route, validate writable, delegate to `PrefabControlService`, JSON response. Tests. | 1.5h |
| 5-03-B | Create `Controls::AccessoryControlComponent` dispatcher | Detect accessory type from sensors, render correct sub-component. `compact:` flag. Tests. | 1h |
| 5-03-C | Create `Controls::LightControlComponent` | Find On/Brightness/Hue/Saturation sensors. Capability detection, state methods using `boolean_value?`. Tests. | 1.5h |
| 5-03-D | Create light control template | Toggle + brightness slider + color button. Disabled when offline. Stimulus wiring. | 1.5h |
| 5-03-E | Create `light_control_controller.js` | Toggle (optimistic), brightness (debounced 300ms), color picker open. Loading states, rollback, toast dispatch. | 2.5h |
| 5-03-F | Integrate controls into `Rooms::DetailComponent` | Replace placeholder settings button in "Other Accessories" with `AccessoryControlComponent`. Eager load sensors. One-time integration that all subsequent PRDs benefit from. | 1h |
| 5-03-G | Create `Controls::ColorPickerComponent` | Modal with Hue + Saturation sliders, preview swatch, Apply/Cancel. Debounced. | 2h |
| 5-03-H | Tests | Component tests (all states). System test (toggle, brightness, color). | 2h |
| 5-03-I | Manual verification & task log | Test against real lights. | 0.5h |
| | **Total** | | **13.5h** |

---

### PRD 5-05: Thermostat Controls

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-05-A | Create `Controls::ThermostatControlComponent` | Find all thermostat sensors. Mode/state methods, unit handling (read in °F via `typed_value`, write in raw). Register in dispatcher. Tests. | 1.5h |
| 5-05-B | Create thermostat control template | Current temp (read-only, large), target temp (slider + ±1° buttons), mode selector (4 buttons), heating/cooling indicator (🔥/❄️). Disabled when offline. | 2h |
| 5-05-C | Create `thermostat_control_controller.js` | Increment/decrement, slider (debounced 500ms), mode change. Each POSTs to control endpoint. Units toggle (display only). | 2h |
| 5-05-D | Tests | Component tests (all modes, indicators, units). System test (adjust temp, change mode). | 1.5h |
| 5-05-E | Manual verification & task log | Test against real thermostat. | 0.25h |
| | **Total** | | **7.25h** |

---

### PRD 5-06: Lock Controls

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-06-A | Create `Shared::ConfirmationModalComponent` | Reusable DaisyUI `<dialog>`. Props: title, message, confirm_label, confirm_class. Stimulus open/close. Keyboard (Enter/Escape). Tests. | 1h |
| 5-06-B | Create `Controls::LockControlComponent` | Find lock sensors. State methods for all 4 states. Register in dispatcher. Tests. | 1h |
| 5-06-C | Create lock control template | State icon + text, Lock/Unlock buttons, embedded confirmation modal, jammed warning. | 1h |
| 5-06-D | Create `lock_control_controller.js` | Lock (immediate POST), unlock (show modal → confirm → POST), cancel. Loading states, rollback, toast. | 1.5h |
| 5-06-E | Tests | Component tests (all states + offline). System test (lock, unlock with confirm, cancel, jammed). | 1.5h |
| 5-06-F | Manual verification & task log | Test against real lock. | 0.25h |
| | **Total** | | **6.25h** |

---

### PRD 5-07: Advanced Controls (Fans, Blinds, Garage Doors)

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-07-A | Create `Controls::FanControlComponent` + template + Stimulus | Active/speed/direction/oscillation. Register in dispatcher. Debounced speed slider. **Implementation Anchors**: Use `Sensor#boolean_value?` for state. Follow `lock_control_controller.js` for toast/rollback pattern. | 2.5h |
| 5-07-B | Create `Controls::BlindControlComponent` + template + Stimulus | Position/tilt sliders, quick actions (Open/50%/Close). Register in dispatcher. Debounced. **Implementation Anchors**: Pattern `app/javascript/controllers/light_control_controller.js` for debounced sliders. | 2.5h |
| 5-07-C | Create `Controls::GarageDoorControlComponent` + template + Stimulus | 5 states + obstruction. **SECURITY**: MUST reuse `Shared::ConfirmationModalComponent` (from 5-06) for BOTH Open and Close actions. Register in dispatcher. **Implementation Anchors**: State logic per HAP GarageDoorOpener spec. | 2.5h |
| 5-07-D | Tests | Component tests for all three (all states). System tests (fan speed, blind quick actions, garage confirm + obstruction). | 2h |
| 5-07-E | Manual verification & task log | Test against real devices. | 0.5h |
| | **Total** | | **10h** |

---

### PRD 5-08: Batch Controls & Favorites Dashboard

| # | Task | Description | Est |
|---|------|-------------|-----|
| 5-08-A | Add `batch_control` to `AccessoriesController` | Route (`collection { post :batch_control }`), validate action_type, iterate + collect results, JSON response. Tests. | 1.5h |
| 5-08-B | Create `Controls::BatchControlComponent` + template | Checkboxes per accessory, Select All/Deselect All, action toolbar with count + buttons. | 1.5h |
| 5-08-C | Create `batch_control_controller.js` | Selection management, toolbar visibility, POST batch, progress text, results summary + toasts. | 2h |
| 5-08-D | Integrate batch controls into room view | Add above accessories list when >1 controllable accessory. | 0.75h |
| 5-08-E | Create `favorites_controller.js` | localStorage management, toggle star, load favorites, SortableJS for drag-and-drop reorder. | 2h |
| 5-08-F | Add star/unstar buttons to accessory cards | ☆/★ toggle on control components and accessory cards. Read initial state from localStorage. | 1h |
| 5-08-G | Create favorites dashboard page | Route, controller action, template with grid of controls, empty state. | 1.5h |
| 5-08-H | Add Favorites to navigation | Link in left sidebar. | 0.25h |
| 5-08-I | Tests | Controller, component, system tests. | 2h |
| 5-08-J | Manual verification & task log | Test batch + favorites persistence. | 0.5h |
| | **Total** | | **13h** |

---

### Cleanup

| # | Task | Description | Est |
|---|------|-------------|-----|
| CC-3 | Create `control_events:cleanup` rake task | Delete records >30 days old. Log count. README note. | 0.5h |

---

## Grand Total

| PRD | Hours | Days |
|-----|-------|------|
| 5-01 | 10.25h | 2 |
| 5-04 | 3.5h | 1 |
| 5-02 | 11.75h | 2-3 |
| 5-03 | 13.5h | 3 |
| 5-05 | 7.25h | 2 |
| 5-06 | 6.25h | 2 |
| 5-07 | 10h | 2-3 |
| 5-08 | 13h | 3 |
| CC-3 | 0.5h | — |
| **Total** | **76h** | **~19 days** |

### Implementation Order

```
5-01 (API foundation + ControlEvent + boolean_value? helper)
  └→ 5-04 (switch toggle — simplest, validates full pipeline)
  └→ 5-02 (scenes + toast system)
  └→ 5-03 (lights + AccessoriesController#control + dispatcher + room integration)
     └→ 5-05 (thermostat — registers in dispatcher, done)
     └→ 5-06 (locks + confirmation modal)
        └→ 5-07 (fans/blinds/garage — registers in dispatcher, reuses modal)
     └→ 5-08 (batch + favorites)
        └→ CC-3 (cleanup task)
```

Want me to write any of these tasks out as detailed implementation specs ready for a developer to pick up?