# Epic 5 Interactive Controls - Architecture Decisions

This document records key architectural decisions made during Epic 5 implementation.

---

## Decision 1: Inline Confirmation Modals vs Shared Component

**Date**: February 14, 2026  
**Context**: Epic 5 PRD-06 (Lock Controls) and PRD-07 (Garage Door Controls)  
**Status**: Approved

### Decision

Security-critical controls (Locks, Garage Doors) use **inline confirmation modals** embedded in their component templates rather than the shared `Shared::ConfirmationModalComponent`.

### Rationale

1. **Multiple Modal Instances**: Lock and Garage Door components each require **two distinct modals**:
   - Lock: One for "Lock" action, one for "Unlock" action
   - Garage Door: One for "Open" action, one for "Close" action

2. **Custom Messaging**: Each modal requires unique, context-specific messaging:
   - Lock unlock: "Are you sure you want to unlock [name]?"
   - Garage door open: "Are you sure you want to open [name]?"
   - Garage door close: "Make sure the door path is clear before closing [name]"

3. **Component Flexibility**: Inline modals allow each control component to be self-contained and independently rendered without requiring complex modal ID management or event coordination when multiple instances exist on the same page.

4. **DaisyUI Simplicity**: DaisyUI's `<dialog>` element is simple enough that duplication doesn't create significant technical debt.

### Implementation Pattern

All inline modals follow this pattern:

```erb
<!-- Inline confirmation modal -->
<dialog id="unlock-modal-<%= @accessory.uuid %>" class="modal">
  <div class="modal-box">
    <h3 class="font-bold text-lg">Confirm Unlock</h3>
    <p class="py-4">Are you sure you want to unlock <%= @accessory.name %>?</p>
    <div class="modal-action">
      <button class="btn" onclick="document.getElementById('unlock-modal-<%= @accessory.uuid %>').close()">Cancel</button>
      <button class="btn btn-primary" 
              data-action="lock-control#confirm_unlock"
              data-lock-control-action-param="unlock">
        Unlock
      </button>
    </div>
  </div>
  <form method="dialog" class="modal-backdrop">
    <button>close</button>
  </form>
</dialog>
```

### Trade-offs

**Pros**:
- Self-contained components (no external dependencies)
- Simple to understand and modify
- No modal ID collision issues
- Each component independently testable

**Cons**:
- Some HTML duplication across components
- Slightly larger component templates

**Verdict**: The flexibility and simplicity outweigh the minimal duplication. This is **not a code smell** but an intentional architectural choice.

### Affected Components

- `app/components/controls/lock_control_component.html.erb` (2 inline modals)
- `app/components/controls/garage_door_control_component.html.erb` (2 inline modals)

### Future Considerations

If more than 3-4 components require inline modals with similar patterns, consider:
1. Creating a `confirmation_modal` partial with slot-based content injection
2. Extracting a base modal wrapper component that accepts custom content blocks

---

## Decision 2: Server-Side Deduplication Window

**Date**: February 14, 2026  
**Context**: Epic 5 Principal Architect Audit - Security Enhancement  
**Status**: Implemented

### Decision

Implement a **10-second server-side deduplication window** in `PrefabControlService` to prevent command flooding and accidental duplicate triggers.

### Rationale

1. **Security Gap**: Client-side debouncing (200-500ms) can be bypassed by malicious scripts or buggy clients.

2. **API Protection**: Without server-side protection, the `/accessories/control` endpoint could be flooded with identical commands.

3. **User Experience**: Prevents accidental double-clicks or page refreshes from sending duplicate commands to devices.

4. **Audit Trail**: Only successful commands are checked for duplication, allowing retries of failed commands.

### Implementation

Location: `app/services/prefab_control_service.rb`

```ruby
DEDUPLICATION_WINDOW = 10.seconds

def self.set_characteristic(accessory:, characteristic:, value:, user_ip: nil, source: 'web')
  # Check for duplicate command within deduplication window
  recent_event = ControlEvent.where(
    accessory: accessory,
    characteristic_name: characteristic,
    new_value: value.to_s,
    success: true
  ).where('created_at > ?', DEDUPLICATION_WINDOW.ago).order(created_at: :desc).first

  if recent_event
    return {
      success: true,
      deduplicated: true,
      message: 'Identical command already sent',
      original_event_id: recent_event.id,
      original_timestamp: recent_event.created_at
    }
  end

  # ... proceed with normal execution
end
```

### Deduplication Key

Commands are considered duplicates when ALL of the following match:
- Same accessory
- Same characteristic name
- Same value (coerced to string)
- Previous command was successful
- Within 10-second window

### Trade-offs

**Pros**:
- Prevents API abuse and accidental duplicates
- Minimal performance impact (indexed database query)
- Does not create new ControlEvent for duplicates (audit log stays clean)
- Returns immediately without hitting Prefab API

**Cons**:
- Very rapid legitimate state changes (e.g., toggle light off then on within 10s) will be deduplicated
- Adds one additional database query per control request

**Verdict**: The security and UX benefits far outweigh the cons. Edge cases (rapid toggle) are rare and can be handled by waiting 10 seconds or using different characteristics.

### Test Coverage

Comprehensive test coverage added in `spec/services/prefab_control_service_spec.rb`:
- Deduplication of identical commands
- No deduplication after 10 seconds
- No deduplication for different values
- No deduplication for different characteristics
- No deduplication for different accessories
- No deduplication of failed commands
- No ControlEvent created for deduplicated commands

---

## Decision 3: Thermostat Display Units Are Display-Only

**Date**: February 14, 2026  
**Context**: Epic 5 PRD-05 (Thermostat Controls) - User Feedback  
**Status**: Clarified

### Decision

The temperature unit toggle (°F / °C) in the thermostat control is **display-only** and does not write unit preference to the device.

### Rationale

1. **HomeKit Convention**: HomeKit devices store temperature in Celsius internally. The display unit is a client-side preference, not a device setting.

2. **User Preference**: Different users may prefer different units. This is a UI preference, not a device configuration.

3. **No Standard Characteristic**: HomeKit's "Temperature Display Units" characteristic (0=Celsius, 1=Fahrenheit) exists but is rarely implemented by manufacturers and is meant for physical device displays, not app interfaces.

### Implementation

- Toggle button in `thermostat_control_component.html.erb` updates JavaScript state only
- All temperature writes to device are converted to Celsius
- Tooltip clarifies: "Toggle display unit (Display Only - does not change device settings)"

### User Visibility

To prevent confusion, the toggle button includes a clear tooltip explaining this behavior.

---

## Summary

These architectural decisions prioritize:
1. **Security**: Server-side deduplication protects against API abuse
2. **Flexibility**: Inline modals allow component independence
3. **User Experience**: Clear labeling prevents confusion about display-only features
4. **Maintainability**: Decisions are documented and tested

All decisions were approved during the Principal Architect Audit (February 14, 2026).
