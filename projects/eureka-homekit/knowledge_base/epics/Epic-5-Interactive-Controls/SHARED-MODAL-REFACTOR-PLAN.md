# Shared Confirmation Modal Refactor Plan
## Deferred - Requires Shared Component Enhancement

**Created**: 2026-02-14  
**Status**: DEFERRED (Not Blocking)  
**Priority**: P3 (Low - Architectural Polish)

---

## Current Situation

### Components Using Inline Modals
1. **LockControlComponent** - Single unlock confirmation modal
2. **GarageDoorControlComponent** - Two confirmation modals (open + close)

### Existing Shared Component
- `Shared::ConfirmationModalComponent` exists but has limitations:
  - Uses hardcoded `data-shared-target="confirmDialog"`
  - Uses hardcoded actions `shared#confirm` and `shared#cancel`
  - Cannot support multiple instances per parent component
  - Cannot integrate with parent Stimulus controllers

---

## Why Inline Modals Are Currently Used

### Technical Limitations
The shared component was designed for simple, standalone confirmation dialogs but doesn't support:

1. **Custom Target Names**: Each modal needs a unique target name for Stimulus
   - Lock: `data-lock-control-target="confirmDialog"`
   - Garage (open): `data-garage-door-control-target="openDialog"`
   - Garage (close): `data-garage-door-control-target="closeDialog"`

2. **Custom Action Handlers**: Each modal needs to trigger parent controller methods
   - Lock: `lock-control#confirmUnlock` / `lock-control#cancelUnlock`
   - Garage: `garage-door-control#confirmOpen` / `garage-door-control#confirmClose`

3. **Multiple Instances**: GarageDoorControlComponent needs TWO modals with different messages and actions

### Current Implementation Is Correct
The inline modals in Lock and GarageDoor components:
- ✅ Work correctly with their Stimulus controllers
- ✅ Use native `<dialog>` elements (modern, accessible)
- ✅ Support keyboard navigation (Enter/Escape)
- ✅ Are DRY enough (only 15-20 lines of markup each)
- ✅ Are easier to understand (co-located with the component)

---

## Proposed Enhancement to Shared Component

To make the shared component truly reusable, it would need:

### 1. Dynamic Target Names
```ruby
def initialize(
  title:,
  description:,
  target_name: 'confirmDialog',  # NEW: Allow custom target
  controller_name: 'shared',     # NEW: Allow custom controller
  # ... existing params
)
```

### 2. Custom Action Integration
```erb
<dialog class="modal" data-<%= controller_name %>-target="<%= target_name %>">
  <div class="modal-box">
    <h3 class="font-bold text-lg"><%= @title %></h3>
    <p class="py-4"><%= @description %></p>
    <div class="modal-action">
      <button class="<%= cancel_classes %>" 
              data-action="click-><%= @controller_name %>#<%= @cancel_action %>">
        <%= @cancel_text %>
      </button>
      <button class="<%= confirm_classes %>" 
              data-action="click-><%= @controller_name %>#<%= @confirm_action %>">
        <%= @confirm_text %>
      </button>
    </div>
  </div>
  <!-- ... -->
</dialog>
```

### 3. Usage Example After Enhancement
```erb
<!-- In lock_control_component.html.erb -->
<%= render Shared::ConfirmationModalComponent.new(
  title: "Confirm Unlock",
  description: "Are you sure you want to unlock #{@accessory.name}?",
  confirm_text: "Unlock",
  confirm_type: :warning,
  target_name: "confirmDialog",
  controller_name: "lock-control",
  confirm_action: "confirmUnlock",
  cancel_action: "cancelUnlock"
) %>
```

---

## Estimated Effort

### Phase 1: Enhance Shared Component (2-3 hours)
- Add dynamic target/controller/action parameters
- Update component template
- Ensure backward compatibility with existing usages
- Add tests for new parameters

### Phase 2: Refactor Lock Component (30 minutes)
- Replace inline modal with enhanced shared component
- Test unlock flow

### Phase 3: Refactor GarageDoor Component (1 hour)
- Replace inline modals (2) with enhanced shared component
- Test open/close flows
- Ensure different messages/styles work

### Total Effort: 4-4.5 hours

---

## Decision: DEFER

### Rationale
1. **Not Blocking**: Inline modals work correctly and meet security requirements
2. **Low ROI**: Refactor saves ~15 lines per component but requires 4+ hours work
3. **Risk vs Reward**: Changes to shared component could break existing usages
4. **Maintainability**: Inline modals are actually easier to understand for these specific cases

### When to Revisit
- When we have 5+ components needing confirmation modals (currently only 2)
- When the shared component is being refactored for other reasons
- When we need significantly more complex modal interactions
- During a dedicated tech debt sprint

---

## Alternative: Extract a Modal Builder Helper

Instead of enhancing the shared component, we could create a helper method:

```ruby
# app/helpers/modal_helper.rb
module ModalHelper
  def confirmation_modal(
    target_name:,
    controller:,
    confirm_action:,
    cancel_action:,
    title:,
    message:,
    confirm_text: 'Confirm',
    confirm_class: 'btn-warning'
  )
    # ... render modal markup with interpolated values
  end
end
```

This would:
- Be lighter weight than a full component
- Allow customization per usage
- Not require changing the shared component
- Still provide DRY benefits

**Estimated Effort**: 1-2 hours

This might be a better middle-ground solution.

---

## Conclusion

The audit report's recommendation to use `Shared::ConfirmationModalComponent` is valid in principle, but premature given the current component's limitations. The inline modals in Lock and GarageDoor are the correct pragmatic choice until we have a properly enhanced shared component.

**Recommendation**: Keep inline modals for now. Revisit when:
1. We need 5+ confirmation modals across the app, OR
2. We're already refactoring the shared component, OR
3. During a scheduled tech debt sprint

**Status**: Intentionally deferred, not a defect.

---

**Prepared by**: AiderDesk  
**Date**: 2026-02-14
