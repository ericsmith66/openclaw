**Epic 5: Interactive HomeKit Device Controls & Scene Management**

**Epic Overview**

This epic extends the read-only monitoring UI (Epic 2) to enable full read/write control of all HomeKit accessories through the Prefab proxy. Currently, users can view sensor states and historical data, but cannot control lights, locks, thermostats, outlets, or trigger scenes. This epic bridges that gap by implementing interactive controls for all writable characteristics, scene execution, and accessory grouping by capability.

The user-facing outcome is a fully interactive HomeKit dashboard where users can turn on lights, adjust thermostats, lock doors, trigger scenes, and control any HomeKit-compatible accessory directly from the web interface—matching functionality available in the native Apple Home app but with enhanced monitoring, logging, and multi-home management capabilities.

**User Capabilities**

- Control all writable HomeKit accessories (lights, switches, thermostats, locks, outlets, fans, etc.)
- Adjust multi-value characteristics (brightness, temperature, target states)
- Execute HomeKit scenes with one click
- View and manage scenes by home
- Group accessories by capability (lighting, climate, security, etc.)
- See real-time feedback when controls are activated
- Track control actions in the event log
- Batch control multiple accessories simultaneously
- Set up quick access controls for frequently used devices

**Fit into Big Picture**

Epic 5 builds directly on Epic 2's monitoring foundation by adding the "write" side of the read/write equation. While Epic 2 established ViewComponents, real-time updates, and sensor dashboards, Epic 5 transforms the application from a passive monitoring tool into an active control interface. This is essential for full HomeKit management and sets the stage for Epic 5 (automation rules) and Epic 7 (voice/mobile apps).

The Prefab proxy already supports all necessary write operations via its REST API—we simply need to expose these capabilities through intuitive UI components with proper error handling and user feedback.

**Reference Documents**

- Epic 2: Web UI Dashboard for HomeKit Monitoring
- Epic 1 PRD 1.2: Prefab HTTP Client Service (`app/services/prefab_client.rb`)
- HomeKit Accessory Protocol (HAP) - Characteristic Types
- DaisyUI Component Library - https://daisyui.com/
- ViewComponent Patterns (existing `app/components/`)

---

### Key Decisions Locked In

**Architecture / Boundaries**

- **New Models**: None—use existing `Accessory`, `Scene`, `Sensor` models
- **New Services**:
  - `PrefabControlService` - handles all write operations to Prefab proxy
  - `AccessoryGrouper` - groups accessories by capability/type
- **New Components**:
  - `Controls::LightControlComponent` (brightness, color, on/off)
  - `Controls::ThermostatControlComponent` (target temp, mode)
  - `Controls::LockControlComponent` (lock/unlock)
  - `Controls::SwitchControlComponent` (on/off, outlets)
  - `Controls::FanControlComponent` (speed, oscillation)
  - `Controls::BlindControlComponent` (position, tilt)
  - `Scenes::CardComponent` (scene card with execute button)
  - `Scenes::ListComponent` (grouped scene list)
  - `Shared::ControlFeedbackComponent` (loading/success/error states)
- **Controllers**:
  - `AccessoriesController` (new) - handles control requests
  - `ScenesController` (new) - handles scene execution
- **Out of Scope**:
  - Creating/editing scenes (use Apple Home app)
  - Creating automations (deferred to Epic 5)
  - HomeKit pairing/bridge setup (handled by Prefab)
  - Voice control (deferred to Epic 9)

**UX / UI**

- Controls appear inline on Room detail pages and Accessory cards
- Modal overlays for complex controls (e.g., color picker for lights)
- Optimistic UI updates with rollback on error
- Loading states (spinner) during API calls
- Success/error toast notifications
- Disabled state for read-only or offline accessories
- Scene cards show thumbnail/icon + execute button
- Touch-friendly control sizes (44x44px minimum)
- Keyboard accessible (Enter to activate, Escape to close)

**Testing**

- Minitest component tests for all control components
- Controller integration tests for all write endpoints
- System tests for end-to-end control flows
- Mock Prefab API responses in tests (use WebMock)
- Test error scenarios (offline, timeout, invalid values)
- Test optimistic UI updates and rollback

**Observability**

- Log all control actions with: `user_ip`, `accessory_uuid`, `characteristic`, `old_value`, `new_value`, `timestamp`
- Track control failures separately: `Rails.logger.error` + increment `control_failures` counter
- Sentry integration for unexpected errors (connection failures, API errors)
- Track control latency (time from button press to Prefab response)
- Add `ControlEvent` model to persist user-initiated control actions (separate from `HomekitEvent`)

---

### High-Level Scope & Non-Goals

**In scope**

- Read all writable characteristics from Prefab API
- UI controls for 8+ common accessory types (lights, switches, thermostats, locks, fans, blinds, outlets, doors)
- Scene execution UI and listing
- Real-time feedback (success/error states)
- Control event logging
- Accessory grouping by capability
- Batch control (select multiple + apply action)
- Quick access controls (favorites dashboard)

**Non-goals / deferred**

- Scene creation/editing (use Apple Home)
- Automation rules (Epic 5)
- Voice control (Epic 9)
- Camera feeds (Epic 10)
- HomeKit pairing/setup (handled by Prefab)
- Multi-user permissions (Epic 8)
- Control scheduling (Epic 5)
- Siri shortcuts integration (Epic 9)

---

### PRD Summary Table

| Priority | PRD Title | Scope | Dependencies | Suggested Branch | Notes |
|----------|-----------|-------|--------------|------------------|-------|
| 5-01 | Prefab Write API Integration | Extend `PrefabClient` with PUT/POST methods for characteristics and scenes | Epic 1 PRD 1.2 | `epic-5/prd-01-prefab-write-api` | Core write capability |
| 5-02 | Scene Management UI | Scene listing, grouping, and execution | PRD 5-01 | `epic-5/prd-02-scene-management` | High user value |
| 5-03 | Light Controls | Brightness, color, on/off controls | PRD 5-01 | `epic-5/prd-03-light-controls` | Most common control |
| 5-04 | Switch & Outlet Controls | Simple on/off controls | PRD 5-01 | `epic-5/prd-04-switch-outlet` | Simple, fast win |
| 5-05 | Thermostat Controls | Target temp, mode, fan controls | PRD 5-01 | `epic-5/prd-05-thermostat-controls` | Climate control |
| 5-06 | Lock Controls | Lock/unlock with confirmation | PRD 5-01 | `epic-5/prd-06-lock-controls` | Security critical |
| 5-07 | Advanced Controls | Fans, blinds, doors, garage | PRD 5-01 | `epic-5/prd-07-advanced-controls` | Less common types |
| 5-08 | Batch Controls & Favorites | Multi-select + quick access dashboard | PRD 5-03, 5-04 | `epic-5/prd-08-batch-favorites` | Power user features |

---

### Key Guidance for All PRDs in This Epic

- **Architecture**:
  - All write operations go through `PrefabControlService` (single point of control)
  - Control components accept `accessory`, `characteristic`, `current_value` props
  - Use Stimulus controllers for interactive behavior (sliders, toggles, modals)
- **Components**:
  - Namespace under `app/components/controls/` and `app/components/scenes/`
  - Follow existing patterns in `app/components/sensors/`
  - Include loading, success, error states in all control components
- **Data Access**:
  - Eager load `accessories.includes(:sensors, :room)` to prevent N+1
  - Cache scene lists (5 minute TTL)
  - Use optimistic UI updates (update UI immediately, rollback on error)
- **Error Handling**:
  - Show user-friendly error messages (avoid technical jargon)
  - Log detailed errors to `Rails.logger.error` + Sentry
  - Retry failed writes once before showing error
  - Fallback: disable control + show "Offline" badge
- **Empty States**:
  - "No controllable accessories in this room"
  - "No scenes configured for this home"
  - "This accessory is read-only"
- **Accessibility**:
  - WCAG AA compliance (contrast, focus indicators)
  - Keyboard navigation (Tab, Enter, Escape, Arrow keys for sliders)
  - Screen reader labels for all controls
  - Confirm dialogs for destructive actions (unlock doors)
- **Mobile**:
  - Touch targets 44x44px minimum
  - Large toggle switches (DaisyUI `toggle-lg`)
  - Modal controls for complex interactions (color picker)
  - Swipe gestures for sliders (Stimulus + touch events)
- **Security**:
  - No authentication in Epic 5 (single-user assumption)
  - Log all control actions with IP address
  - Confirm destructive actions (unlock, garage door open)
  - Rate limiting (10 controls/second max per IP)

---

### Implementation Status Tracking

- Create `0001-IMPLEMENTATION-STATUS.md` in this directory before starting PRD work.
- Update it after each PRD completion.

---

### Success Metrics

- User can control 95%+ of writable accessories (excluding cameras, speakers)
- Control latency <500ms (button press to Prefab response)
- Control success rate >98%
- Zero N+1 queries in control views
- All controls keyboard accessible
- Mobile touch targets meet 44x44px requirement
- Test coverage >80% for control components

---

### Estimated Timeline

- PRD 5-01 (Prefab Write API): 2-3 days
- PRD 5-02 (Scene Management): 2-3 days
- PRD 5-03 (Light Controls): 3-4 days
- PRD 5-04 (Switch & Outlet): 1-2 days
- PRD 5-05 (Thermostat Controls): 2-3 days
- PRD 5-06 (Lock Controls): 2-3 days
- PRD 5-07 (Advanced Controls): 3-4 days
- PRD 5-08 (Batch & Favorites): 2-3 days
- Testing & Polish: 3-4 days

**Total: 20-29 days** (4-6 weeks)

---

### Next Steps

1. Create `0001-IMPLEMENTATION-STATUS.md` in this directory
2. Review and approve Epic 5 scope
3. Proceed with PRD 5-01 (Prefab Write API Integration)

---

### Detailed PRDs

Full PRD specifications live in separate files:
- `PRD-5-01-prefab-write-api.md`
- `PRD-5-02-scene-management.md`
- `PRD-5-03-light-controls.md`
- `PRD-5-04-switch-outlet-controls.md`
- `PRD-5-05-thermostat-controls.md`
- `PRD-5-06-lock-controls.md`
- `PRD-5-07-advanced-controls.md`
- `PRD-5-08-batch-favorites.md`
