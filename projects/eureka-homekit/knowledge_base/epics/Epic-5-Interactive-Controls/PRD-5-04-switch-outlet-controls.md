#### PRD-5-04: Switch & Outlet Controls

**Log Requirements**
- Junie: Create/update task log under `knowledge_base/prds-junie-log/PRD-5-04-switch-outlet-controls-log.md`.

---

### Overview

Simple on/off toggle controls for switches, outlets, and other binary accessories. Fastest path to user value—most common control type after lights.

---

### Requirements

#### Functional

- Large toggle switch (DaisyUI `toggle-lg`) for on/off
- Optimistic UI updates (toggle immediately, rollback on error)
- Visual feedback (loading spinner during API call)
- Works for: switches, outlets, fans (simple on/off), humidifiers, air purifiers

#### Components

- `Controls::SwitchControlComponent` - simple on/off toggle
- Reusable for any accessory with `On` characteristic

#### Technical Notes

- Characteristic: `On` (boolean: true/false or 1/0)
- No debouncing needed (single action)
- Inline display on room cards and detail pages

---

### Acceptance Criteria

- [ ] Toggle switches accessories on/off
- [ ] Optimistic UI with rollback on error
- [ ] Loading state during API call
- [ ] Disabled state for offline accessories
- [ ] Works on mobile (44x44px touch target)
- [ ] Keyboard accessible (Space/Enter)

---

### Implementation Highlights

```ruby
# app/components/controls/switch_control_component.rb
class Controls::SwitchControlComponent < ViewComponent::Base
  def initialize(accessory:, size: 'md')
    @accessory = accessory
    @size = size
    @on_sensor = accessory.sensors.find_by(characteristic_type: 'On')
  end

  def current_state
    @on_sensor&.current_value == 'true' || @on_sensor&.current_value == '1'
  end

  def offline?
    @accessory.last_seen_at.nil? || @accessory.last_seen_at < 1.hour.ago
  end
end
```

**Template**:
```erb
<label class="label cursor-pointer">
  <span class="label-text font-medium"><%= @accessory.name %></span>
  <input type="checkbox"
         class="toggle toggle-<%= @size %> <%= 'toggle-disabled' if offline? %>"
         <%= 'checked' if current_state %>
         <%= 'disabled' if offline? %>
         data-controller="switch-control"
         data-switch-control-accessory-id-value="<%= @accessory.id %>"
         data-action="change->switch-control#toggle">
</label>
```

---

### Test Cases

- Toggle switches accessory on/off
- Offline accessories are disabled
- Error shows toast and reverts toggle
- Mobile touch targets work
