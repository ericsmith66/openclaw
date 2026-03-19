#### PRD-5-06: Lock Controls

**Log Requirements**
- Junie: Create/update task log under `knowledge_base/prds-junie-log/PRD-5-06-lock-controls-log.md`.

---

### Overview

Secure lock/unlock controls for HomeKit smart locks with confirmation dialog, visual state indicators, and detailed logging for security-critical actions.

---

### Requirements

#### Functional

- Lock/unlock button with confirmation dialog
- Visual lock state (locked/unlocked/jammed/unknown)
- Confirmation required before unlocking (security)
- Action logging with timestamp and IP address
- Success/error feedback with detailed messages

#### Components

- `Controls::LockControlComponent` - lock control interface
- `Shared::ConfirmationModalComponent` - unlock confirmation dialog

#### Technical Notes

- Characteristics:
  - `Lock Current State` (0=unsecured, 1=secured, 2=jammed, 3=unknown)
  - `Lock Target State` (0=unsecured, 1=secured)
- Always require confirmation for unlock action
- Log all lock/unlock attempts to `ControlEvent` with IP
- Show detailed error messages (jammed, timeout, etc.)

---

### Acceptance Criteria

- [ ] Lock button locks the door
- [ ] Unlock button shows confirmation dialog
- [ ] Lock state displayed with icon (🔒/🔓/⚠️)
- [ ] All actions logged with IP address
- [ ] Error states shown (jammed, timeout)
- [ ] Keyboard accessible (Enter confirms dialog)

---

### Implementation Highlights

```ruby
# app/components/controls/lock_control_component.rb
class Controls::LockControlComponent < ViewComponent::Base
  def initialize(accessory:)
    @accessory = accessory
    @current_state_sensor = accessory.sensors.find_by(characteristic_type: 'Lock Current State')
    @target_state_sensor = accessory.sensors.find_by(characteristic_type: 'Lock Target State')
  end

  def locked?
    @current_state_sensor&.current_value == '1'
  end

  def jammed?
    @current_state_sensor&.current_value == '2'
  end

  def state_icon
    if jammed?
      '⚠️'
    elsif locked?
      '🔒'
    else
      '🔓'
    end
  end

  def state_text
    case @current_state_sensor&.current_value
    when '0' then 'Unlocked'
    when '1' then 'Locked'
    when '2' then 'Jammed'
    else 'Unknown'
    end
  end
end
```

**Template with Confirmation**:
```erb
<div class="card" data-controller="lock-control">
  <div class="flex items-center gap-3">
    <div class="text-4xl"><%= state_icon %></div>
    <div>
      <h4 class="font-semibold"><%= @accessory.name %></h4>
      <p class="text-sm text-gray-600"><%= state_text %></p>
    </div>
  </div>

  <% if locked? %>
    <button class="btn btn-warning mt-3"
            data-action="click->lock-control#showUnlockConfirmation">
      Unlock
    </button>
  <% else %>
    <button class="btn btn-primary mt-3"
            data-action="click->lock-control#lock">
      Lock
    </button>
  <% end %>

  <!-- Confirmation Modal -->
  <dialog data-lock-control-target="confirmDialog" class="modal">
    <div class="modal-box">
      <h3 class="font-bold text-lg">Confirm Unlock</h3>
      <p class="py-4">Are you sure you want to unlock <%= @accessory.name %>?</p>
      <div class="modal-action">
        <button class="btn" data-action="click->lock-control#cancelUnlock">Cancel</button>
        <button class="btn btn-warning" data-action="click->lock-control#confirmUnlock">Unlock</button>
      </div>
    </div>
  </dialog>
</div>
```

---

### Test Cases

- Lock button locks the door
- Unlock button shows confirmation dialog
- Confirmation required before unlocking
- Cancel button closes dialog without action
- Lock state icons display correctly
- All actions logged to ControlEvent
- Error states (jammed, timeout) handled
