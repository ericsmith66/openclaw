# 🏛️ PRINCIPAL ARCHITECT AUDIT REPORT
## Epic 5: Interactive Controls — PRD-01 through PRD-07

**Auditor**: Principal Architect (AiderDesk)  
**Date**: 2026-02-14  
**Source of Truth**: `knowledge_base/epics/Epic-5-Interactive-Controls/0000-aider-desks-plan.md`  
**Scope**: Full codebase review of all files implementing PRD-01 through PRD-07

---

## 📊 EXECUTIVE SUMMARY

| Metric | Value |
|--------|-------|
| **Overall Grade** | **C+ (Conditional Pass)** |
| **PRDs Passing** | 4 of 7 |
| **Critical Security Findings** | 3 |
| **Blocking Defects** | 5 |
| **Technical Debt Items** | 12 |
| **Recommendation** | **HOLD on PRD-5-08** until blockers resolved |

---

## 📋 PRD-BY-PRD SCORECARD

### PRD-01: Prefab Write API Integration — ✅ PASS (A-)

| Criterion | Status | Notes |
|-----------|--------|-------|
| `ControlEvent` model | ✅ | Validations, scopes, class methods all present |
| `Open3.capture3` pattern | ✅ | `execute_curl_base` uses `Open3.capture3(*args)` correctly |
| `PrefabClient.update_characteristic` | ✅ | URL-encoding, structured response, request_id logging |
| `PrefabClient.execute_scene` | ✅ | POST pattern correct |
| `PrefabControlService` | ✅ | 3-attempt retry with 500ms sleep, `SecureRandom.uuid` |
| `Sensor#boolean_value?` | ✅ | Handles `true/1/"1"/"true"/"on"/"yes"` and inverses |
| Error scrubbing | ✅ | `scrub_error_message` filters Bearer tokens and API keys |
| Audit logging (user_ip, source, request_id) | ✅ | All fields passed through to `ControlEvent.create!` |
| Test coverage (services) | ✅ | `prefab_control_service_spec.rb` (90+ lines), `prefab_client_spec.rb` (200+ lines) |

**Findings**:
- **Minor**: `PrefabClient` test stubs `execute_curl` return signature `[json, true, latency, exit]` but `execute_curl` (the GET version) only returns `[result, success]` — the tests mock at the wrong level for read operations. Write operation tests are correct.
- **Minor**: `ControlEvent` model spec is embedded inside `prefab_control_service_spec.rb` rather than having its own `spec/models/control_event_spec.rb`. Not blocking but violates Rails convention.

---

### PRD-02: Scene Management UI — ⚠️ CONDITIONAL PASS (B-)

| Criterion | Status | Notes |
|-----------|--------|-------|
| `ScenesController` (index/show/execute) | ✅ | Filters, search, eager loading, JSON execute |
| `Scenes::CardComponent` | ✅ | Emoji heuristic, accessories count, last_executed |
| `scene_controller.js` Stimulus | ✅ | Loading spinner, success/error feedback, 3s auto-dismiss |
| Scenes views (index/show) | ✅ | Breadcrumbs, filters, responsive grid, empty state |
| Left sidebar navigation | ✅ | Scenes link present |
| **Toast notification system** | ❌ **MISSING** | No `toast_controller.js` exists anywhere in the codebase |
| Scene execution N+1 prevention | ✅ | `Scene.includes(:home, :accessories)` |
| Test coverage | ❌ **MISSING** | No `spec/requests/scenes_spec.rb`, no `spec/components/scenes/card_component_spec.rb` |

**Findings**:
- 🔴 **BLOCKER**: The **toast notification system** (PRD-02-A) was never built. Every single Stimulus controller across PRDs 03-07 has commented-out toast dispatch code (`// In production, this would dispatch a toast event`). This means **zero user feedback on errors** in the live UI — failures are silently logged to `console.error` only.
- 🔴 **BLOCKER**: Zero test coverage for Scenes. No request specs, no component specs. This is the only controller in Epic 5 with no tests at all.

---

### PRD-03: Light Controls — ⚠️ CONDITIONAL PASS (B-)

| Criterion | Status | Notes |
|-----------|--------|-------|
| `AccessoriesController#control` | ✅ | Validates writable, coerces values, delegates to service |
| `AccessoryControlComponent` dispatcher | ⚠️ **BROKEN** | `call` method returns symbol, not rendered HTML |
| `LightControlComponent` | ✅ | Uses `boolean_value?`, capability detection |
| `light_control_controller.js` | ⚠️ | Optimistic toggle works, brightness debounced 300ms |
| `ColorPickerComponent` + controller | ✅ | Hue/Sat sliders, preview swatch, apply/cancel |
| Room detail integration | ✅ | `controllable_accessories` method, dispatcher rendering |
| Test coverage | ❌ **MISSING** | No `spec/components/controls/light_control_component_spec.rb` |
| Test coverage (dispatcher) | ❌ **MISSING** | No `spec/components/controls/accessory_control_component_spec.rb` |

**Findings**:
- 🔴 **BLOCKER**: `AccessoryControlComponent#call` returns the **symbol** from `accessory_type` (e.g., `:light`, `:switch`), NOT rendered HTML. The `render_component` method exists but is **never called** from `call`. The dispatcher is fundamentally broken — it renders the type name as a string instead of the sub-component. The room detail view calls `render Controls::AccessoryControlComponent.new(...)` which would output `:light` as literal text.
- **Major**: `LightControlComponent` template file is `.html` not `.html.erb` — ViewComponent should still process it if ERB tags are present, but this is inconsistent with every other component in the project which uses `.html.erb`.
- **Major**: `light_control_controller.js` `showError` only does `console.error` — no rollback on toggle failure, no visual feedback. Compare to `fan_control_controller.js` which properly rolls back checkbox state on failure.
- **Minor**: `ColorPickerComponent` is standalone with its own Stimulus controller, but `light_control_controller.js` references `hueSliderTarget`/`saturationSliderTarget` directly — integration between the two controllers is unclear and likely broken.

---

### PRD-04: Switch & Outlet Controls — ✅ PASS (B+)

| Criterion | Status | Notes |
|-----------|--------|-------|
| `SwitchControlComponent` | ⚠️ | State coercion works but doesn't use `boolean_value?` |
| `OutletControlComponent` | ⚠️ | Clone of Switch — same `boolean_value?` bypass issue |
| `switch_control_controller.js` | ⚠️ | Optimistic UI, but no rollback on error |
| Template (DaisyUI toggle) | ✅ | Accessible (sr-only label), disabled when offline |
| Touch target 44x44px | ✅ | DaisyUI toggle meets minimum |
| Test coverage | ✅ | `switch_control_component_spec.rb` (100+ lines), `outlet_control_component_spec.rb` (100+ lines) |

**Findings**:
- 🟡 **DIRECTIVE VIOLATION**: `SwitchControlComponent#current_state` does **manual string comparison** (`val == 'true' || val == '1' || val == 'on' || val == 'yes'`) instead of using the mandated `Sensor#boolean_value?` helper. The plan explicitly states: "Use `Sensor#boolean_value?` for state." This is duplicated logic that could drift from the canonical implementation.
- 🟡 **DIRECTIVE VIOLATION**: Same issue in `OutletControlComponent#current_state` — copy-pasted manual coercion.
- 🟡 `SwitchControlComponent#offline?` uses `accessory.last_seen_at < 1.hour.ago` instead of `Sensor#offline?` which has the richer 3-tier check (Status Active → Status Fault → fallback). Inconsistent with `LightControlComponent` which delegates to sensor.
- **Minor**: `switch_control_controller.js` sends `accessory_id: this.accessoryIdValue` but the template binds `data-switch-control-accessory-id-value="<%= @accessory.id %>"` using the **integer ID** instead of `@accessory.uuid`. The `AccessoriesController#set_accessory` looks up by `uuid`, so this will 404 at runtime.
- **Minor**: No rollback in `switch_control_controller.js` — `showError` only logs to console.

---

### PRD-05: Thermostat Controls — ✅ PASS (B)

| Criterion | Status | Notes |
|-----------|--------|-------|
| `ThermostatControlComponent` | ✅ | All sensors indexed, mode/state methods, unit handling |
| Template (slider + ±, mode select) | ⚠️ | Slider + mode select present, but ±1° buttons missing |
| `thermostat_control_controller.js` | ⚠️ | Debounced 500ms, mode change, unit toggle |
| Heating/cooling indicators | ✅ | 🔥/❄️ dot indicators with opacity |
| Test coverage | ✅ | `thermostat_control_component_spec.rb` (150+ lines) |

**Findings**:
- 🟡 **Missing Feature**: PRD specifies "target temp (slider + ±1° buttons)" but the template only has the slider — no increment/decrement buttons. The JS controller also has no increment/decrement methods.
- 🟡 `thermostat_control_controller.js` references `TemperatureConverter` as a JS class but it's only defined as a Ruby module (`app/helpers/temperature_converter.rb`). The JS `toCelsius`/`toFahrenheit` methods are defined locally but `currentTempCelsius()` calls `TemperatureConverter.to_fahrenheit(celsius)` which will throw `ReferenceError` at runtime.
- 🟡 `thermostat_control_controller.js` defines `offlineValue()` as a regular method but Stimulus expects it as a `static values` declaration. The `offlineValue` in the controller is a method that reads `dataset`, not a Stimulus value. This means `this.offlineValue` in `update_target_temp` calls the method correctly, but it won't receive Stimulus value change callbacks.
- **Minor**: Template uses `disabled="<%= offline? ? 'disabled' : nil %>"` which will render `disabled=""` (truthy in HTML) even when nil because ERB still outputs the attribute. Should use conditional: `<%= 'disabled' if offline? %>`.

---

### PRD-06: Lock Controls — ✅ PASS (A-)

| Criterion | Status | Notes |
|-----------|--------|-------|
| `Shared::ConfirmationModalComponent` | ✅ | Reusable, configurable (title, confirm_text, confirm_type) |
| `LockControlComponent` | ✅ | All 4 states mapped, icons, text |
| Unlock confirmation modal | ✅ | Modal shown before unlock |
| Lock direct action | ✅ | Lock fires immediately (no confirmation needed) |
| Jammed state handling | ✅ | Alert shown, buttons hidden |
| `lock_control_controller.js` | ⚠️ | Promise-based, loading states |
| Test coverage | ✅ | `lock_control_component_spec.rb` (180+ lines, all states) |
| Audit logging (IP, source) | ✅ | Handled by `PrefabControlService` |

**Findings**:
- ✅ **Security**: Unlock requires confirmation modal — correctly implemented inline in the lock template using native `<dialog>`.
- 🟡 `LockControlComponent` does NOT use `Shared::ConfirmationModalComponent`. It has its own inline `<dialog>` element hardcoded in the template. The reusable modal component was built (PRD-06-A) but then **not actually used** by the lock component itself. This is architectural drift — the plan explicitly says "reuse `Shared::ConfirmationModalComponent`".
- 🟡 `lock_control_controller.js` defines `offlineValue()` and `currentStateValue()` as regular methods, not Stimulus static values. Same pattern issue as thermostat.
- **Minor**: `showError` has toast dispatch code **commented out** — depends on missing toast system.

---

### PRD-07: Advanced Controls — ❌ FAIL (F)

| Criterion | Status | Notes |
|-----------|--------|-------|
| `FanControlComponent` | ✅ | Uses `boolean_value?`, feature detection, state text |
| `fan_control_controller.js` | ✅ | Debounced speed, direction, oscillation, rollback on error |
| **`BlindControlComponent`** | ❌ **MISSING** | No files exist |
| **`blind_control_controller.js`** | ❌ **MISSING** | No files exist |
| **`GarageDoorControlComponent`** | ❌ **MISSING** | No files exist |
| **`garage_door_control_controller.js`** | ❌ **MISSING** | No files exist |
| Dispatcher registration (fan) | ✅ | `fan?` method checks `Rotation Speed` + `Active` |
| Dispatcher registration (blind) | ✅ | `blind?` method present in dispatcher |
| Dispatcher registration (garage) | ✅ | `garage_door?` method present in dispatcher |
| `coerce_value` for fan/blind/garage | ❌ **MISSING** | No coercion for Active, Rotation Speed, Target Position, etc. |
| Test coverage (fan) | ❌ **MISSING** | No `spec/components/controls/fan_control_component_spec.rb` |
| Test coverage (blind/garage) | ❌ **N/A** | Components don't exist |

**Findings**:
- 🔴 **BLOCKER**: `BlindControlComponent` (5-07-B) is **completely unimplemented**. No Ruby component, no template, no Stimulus controller. The dispatcher references it but rendering will crash.
- 🔴 **CRITICAL SECURITY**: `GarageDoorControlComponent` (5-07-C) is **completely unimplemented**. This is a **security-critical** component that MUST use `Shared::ConfirmationModalComponent` for both Open and Close actions per the security directive. It does not exist at all.
- 🟡 `FanControlComponent` was built but has zero test coverage.
- 🟡 `AccessoriesController#coerce_value` has no cases for `Active`, `Rotation Speed`, `Rotation Direction`, `Swing Mode`, `Target Position`, `Target Horizontal Tilt Angle`, or `Target Door State` — all values from these characteristics pass through as raw strings.
- 🟡 **Orchestration Violation**: The `0001-IMPLEMENTATION-STATUS-PRD-5-07.md` shows Phase 1 Blueprint was completed and Phase 2 was "BLOCKED" pending QA audit. However, the Fan component files **were created anyway**, bypassing the QA gate. The master plan's execution context explicitly states: "**UNAUTHORIZED BYPASS DETECTED**" and "Phase 2 is currently **UNAUTHORIZED**. Stop writing code immediately."

---

## 🔴 CRITICAL SECURITY FINDINGS

### SEC-01: Missing Toast System = Silent Failures (Severity: HIGH)

**Every Stimulus controller** across PRDs 03-07 logs errors to `console.error` only. Users receive **zero visual feedback** when a control command fails. A user could toggle a lock, see optimistic "unlocking" UI, have the command fail, and **never know the lock didn't actually unlock**. This is a safety issue for security devices.

**Affected files**: `switch_control_controller.js`, `light_control_controller.js`, `thermostat_control_controller.js`, `lock_control_controller.js`, `fan_control_controller.js`

**Required Action**: Implement `toast_controller.js` (PRD-5-02-A) and replace all `console.error`/`console.log` calls with `CustomEvent('toast:show', ...)` dispatches.

### SEC-02: Missing Garage Door Confirmation Modal (Severity: CRITICAL)

The `GarageDoorControlComponent` does not exist. Per the security directive, **both Open and Close** actions on garage doors MUST require confirmation via `Shared::ConfirmationModalComponent`. This component must not ship without this safeguard.

### SEC-03: No Control-Level Deduplication Window (Severity: MEDIUM)

The plan references a "10s deduplication window" for control commands but **no deduplication logic exists** in `AccessoriesController#control` or `PrefabControlService`. The existing `DEDUPE_WINDOW` in `homekit_events_controller.rb` is for inbound events (5 minutes), not outbound control commands. A rapid-fire user could send dozens of conflicting commands in seconds.

**Required Action**: Add a per-accessory-per-characteristic deduplication check in `AccessoriesController#control` using Redis or in-memory cache with a 10-second window.

---

## 🟡 REFACTORING RECOMMENDATIONS (Technical Debt)

### TD-01: AccessoryControlComponent Dispatcher is Broken
**Priority**: P0 (Blocking)  
**Fix**: Change `call` method to invoke `render_component` or use an `.html.erb` template that calls `render_component`.

### TD-02: Inconsistent `boolean_value?` Usage
**Priority**: P1  
**Fix**: Refactor `SwitchControlComponent#current_state` and `OutletControlComponent#current_state` to delegate to `@on_sensor.boolean_value?` instead of manual string comparison.

### TD-03: Inconsistent `offline?` Implementation
**Priority**: P1  
**Fix**: Three different `offline?` strategies exist:
1. `Sensor#offline?` — 3-tier (Status Active → Status Fault → 24h fallback) ← **canonical**
2. `SwitchControlComponent` / `OutletControlComponent` / `LockControlComponent` / `ThermostatControlComponent` — `accessory.last_seen_at < 1.hour.ago` ← **naive**
3. `LightControlComponent` — `@accessory.sensors.any?(&:offline?)` ← **correct delegation**

All components should use pattern #3 or a new `Accessory#offline?` method.

### TD-04: Switch Template Uses Integer ID Instead of UUID
**Priority**: P0 (Runtime error)  
**Fix**: Change `data-switch-control-accessory-id-value="<%= @accessory.id %>"` to `@accessory.uuid` in both `switch_control_component.html.erb` and `outlet_control_component.html.erb`.

### TD-05: Thermostat JS References Non-Existent `TemperatureConverter`
**Priority**: P1 (Runtime error)  
**Fix**: Remove the `TemperatureConverter.to_fahrenheit(celsius)` call from `thermostat_control_controller.js` and use the local `toFahrenheit()` method instead.

### TD-06: Lock Component Doesn't Use Shared ConfirmationModalComponent
**Priority**: P2  
**Fix**: Refactor lock template to render `Shared::ConfirmationModalComponent` instead of inline `<dialog>`.

### TD-07: Missing `coerce_value` Cases for Fan/Blind/Garage Characteristics
**Priority**: P1  
**Fix**: Add cases for `Active` (int 0/1), `Rotation Speed` (int 0-100), `Rotation Direction` (int 0/1), `Swing Mode` (int 0/1), `Target Position` (int 0-100), `Target Horizontal Tilt Angle` (int -90..90), `Target Door State` (int 0/1).

### TD-08: Light Template File Extension
**Priority**: P3  
**Fix**: Rename `light_control_component.html` to `light_control_component.html.erb` and `color_picker_component.html` to `color_picker_component.html.erb` for consistency.

### TD-09: No `spec/models/control_event_spec.rb`
**Priority**: P2  
**Fix**: Extract `ControlEvent` model tests from `prefab_control_service_spec.rb` into their own spec file.

### TD-10: Stimulus Value Declarations
**Priority**: P2  
**Fix**: `lock_control_controller.js` and `thermostat_control_controller.js` define `offlineValue()` as methods instead of declaring `offline: Boolean` in `static values`. This breaks Stimulus value observation callbacks.

### TD-11: Missing `Scenes::CardComponent` Spec
**Priority**: P2  
**Fix**: Create `spec/components/scenes/card_component_spec.rb` covering emoji heuristic, count, and last_executed.

### TD-12: DRY Stimulus `sendControl` Method
**Priority**: P3  
**Fix**: Five controllers have nearly identical `sendControl`/`fetch` patterns. Extract into a shared mixin or base controller class.

---

## 🔍 TEST COVERAGE ANALYSIS

| Component / Service | Spec Exists? | Coverage Quality |
|---------------------|:------------:|------------------|
| `PrefabControlService` | ✅ | Good — success, retry, failure, scrubbing |
| `PrefabClient` | ✅ | Good — all endpoints, URL encoding, errors |
| `SwitchControlComponent` | ✅ | Strong — all states, rendering, Stimulus attrs |
| `OutletControlComponent` | ✅ | Strong — mirrors switch spec |
| `LockControlComponent` | ✅ | Strong — all 4 states, icons, text, offline |
| `ThermostatControlComponent` | ✅ | Strong — temps, modes, units, display values |
| `LightControlComponent` | ❌ | **MISSING** |
| `FanControlComponent` | ❌ | **MISSING** |
| `AccessoryControlComponent` (dispatcher) | ❌ | **MISSING** — critical, dispatcher is broken |
| `ColorPickerComponent` | ❌ | **MISSING** |
| `ConfirmationModalComponent` | ❌ | **MISSING** |
| `Scenes::CardComponent` | ❌ | **MISSING** |
| `ScenesController` | ❌ | **MISSING** |
| `AccessoriesController` | ❌ | **MISSING** |
| `ControlEvent` (model) | ⚠️ | Embedded in service spec, not standalone |
| `BlindControlComponent` | N/A | Component doesn't exist |
| `GarageDoorControlComponent` | N/A | Component doesn't exist |

**Spec Files**: 6 of 15 required spec files exist (40% coverage)

---

## 🏗️ ORCHESTRATION INTEGRITY

### Phase Gate Violations Detected

| PRD | Gate | Status | Evidence |
|-----|------|--------|----------|
| 5-06 | QA Phase 1 (Security Logic) | ⚠️ SKIPPED | Status doc shows "⏳ AWAITING" but Phase 3 marked COMPLETE |
| 5-06 | QA Phase 2 (State Machine) | ⚠️ SKIPPED | Status doc shows "⏳ PENDING" but code was written anyway |
| 5-07 | QA Blueprint Approval | ❌ BYPASSED | Master plan says "UNAUTHORIZED BYPASS DETECTED". Fan component was created despite Phase 2 being "BLOCKED" |

The master plan's execution context explicitly flagged an **unauthorized bypass** on the QA gate. The Lead Agent proceeded to create `FanControlComponent` files despite the Blueprint not being approved by the QA subagent. The Lock component also shows signs of Phase 1 and Phase 2 QA reviews being skipped (both marked "AWAITING"/"PENDING" in the status doc while Phase 3 was completed).

---

## 📊 PLAN ADHERENCE: DISPATCHER ANALYSIS

### Original Plan
> Create `Controls::AccessoryControlComponent` dispatcher: `initialize(accessory:, compact: false)`. Inspects `accessory.sensors` to detect type [...] Component tests verify correct dispatch for each type.

### Current Implementation
The dispatcher **partially adheres** to the plan:
- ✅ Correct `initialize(accessory:, compact:)` signature
- ✅ Correct type detection logic (sensor-based)
- ✅ All 8 types registered (including outlet as bonus)
- ❌ `call` method returns a symbol instead of rendered HTML
- ❌ No template file exists (`.html.erb` missing)
- ❌ `render_component` is defined but never invoked
- ❌ Zero test coverage for the dispatcher
- ❌ Will render literal text like `:light` in the room view

---

## ✅ FINAL VERDICT

### Is the project stable enough to proceed to PRD-5-08 (Batch Controls)?

# ❌ NO — NOT READY

**Rationale**: Five blocking defects must be resolved first:

1. **AccessoryControlComponent dispatcher is broken** — renders symbols not components. All room detail controls are non-functional.
2. **Toast notification system doesn't exist** — all error feedback is `console.error` only. Security devices (locks) silently fail.
3. **BlindControlComponent is completely missing** — dispatcher will crash when encountering blinds.
4. **GarageDoorControlComponent is completely missing** — security-critical component with mandatory confirmation modal.
5. **Switch/Outlet use integer ID instead of UUID** — will 404 at runtime.

### Recommended Action Before PRD-5-08

| Priority | Action | Effort |
|----------|--------|--------|
| P0 | Fix `AccessoryControlComponent#call` to render sub-components | 30 min |
| P0 | Fix Switch/Outlet templates to use `@accessory.uuid` | 15 min |
| P0 | Implement `toast_controller.js` + wire all controllers | 2 hours |
| P0 | Implement `BlindControlComponent` + template + Stimulus | 3 hours |
| P0 | Implement `GarageDoorControlComponent` with confirmation modal | 3 hours |
| P1 | Add `coerce_value` cases for all new characteristics | 30 min |
| P1 | Refactor Switch/Outlet to use `Sensor#boolean_value?` | 15 min |
| P1 | Fix thermostat JS `TemperatureConverter` reference | 15 min |
| P1 | Standardize `offline?` across all components | 1 hour |
| P2 | Create missing specs (light, fan, dispatcher, scenes, etc.) | 4 hours |
| P2 | Refactor lock to use `Shared::ConfirmationModalComponent` | 30 min |

**Estimated remediation**: ~15 hours before PRD-5-08 can safely begin.

---

*Report generated by Principal Architect audit on 2026-02-14. All findings are based on direct source code inspection of the files in the project repository.*
