# Test Coverage Plan for Epic 5: Interactive Controls
## PRD-01 through PRD-07 Testing Gaps

**Created**: 2026-02-14  
**Status**: Implementation Needed  
**Estimated Effort**: 8-10 hours

---

## Overview

This document outlines the missing test coverage identified in the audit report for Epic 5 Interactive Controls. All P0 and P1 issues have been resolved. The remaining P2 tasks require comprehensive test coverage for components and controllers.

---

## Missing Component Specs

### 1. LightControlComponent Spec
**Priority**: P2  
**File**: `spec/components/controls/light_control_component_spec.rb`  
**Estimated Time**: 1.5 hours

**Test Coverage Needed**:
- ✅ Component renders with accessory name
- ✅ Shows offline badge when accessory is offline
- ✅ Toggle button state reflects current on/off state
- ✅ Brightness slider present when accessory has Brightness sensor
- ✅ Brightness slider hidden when no Brightness sensor
- ✅ Color button present when accessory has Hue/Saturation sensors
- ✅ Color button hidden when no Hue/Saturation sensors
- ✅ Controls disabled when offline
- ✅ Stimulus controller and targets wired correctly
- ✅ Correct accessory UUID passed to Stimulus controller

**Example Test Structure**:
```ruby
require 'rails_helper'

RSpec.describe Controls::LightControlComponent, type: :component do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room, name: 'Living Room Light') }
  
  describe 'basic light (on/off only)' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: 'true')
    end
    
    it 'renders accessory name' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Living Room Light')
    end
    
    # ... more tests
  end
  
  describe 'dimmable light' do
    # Tests for brightness slider
  end
  
  describe 'color light' do
    # Tests for color picker button
  end
end
```

---

### 2. FanControlComponent Spec
**Priority**: P2  
**File**: `spec/components/controls/fan_control_component_spec.rb`  
**Estimated Time**: 1.5 hours

**Test Coverage Needed**:
- ✅ Component renders with accessory name
- ✅ Shows offline badge when offline
- ✅ Toggle switch reflects active state
- ✅ Speed slider present and reflects current speed
- ✅ Direction buttons present when Rotation Direction sensor exists
- ✅ Oscillation toggle present when Swing Mode sensor exists
- ✅ All controls disabled when offline
- ✅ Stimulus controller wired correctly
- ✅ Correct accessory UUID passed

---

### 3. AccessoryControlComponent (Dispatcher) Spec
**Priority**: P2  
**File**: `spec/components/controls/accessory_control_component_spec.rb`  
**Estimated Time**: 2 hours

**Test Coverage Needed**:
- ✅ Detects light type (On + Brightness/Hue)
- ✅ Detects switch type (On only, no outlet)
- ✅ Detects outlet type (On + Outlet In Use)
- ✅ Detects thermostat type (Target Temperature)
- ✅ Detects lock type (Lock Current State)
- ✅ Detects fan type (Active + Rotation Speed)
- ✅ Detects blind type (Target Position, no Active)
- ✅ Detects garage door type (Current Door State)
- ✅ Renders LightControlComponent for lights
- ✅ Renders SwitchControlComponent for switches
- ✅ Renders OutletControlComponent for outlets
- ✅ Renders ThermostatControlComponent for thermostats
- ✅ Renders LockControlComponent for locks
- ✅ Renders FanControlComponent for fans
- ✅ Renders BlindControlComponent for blinds
- ✅ Renders GarageDoorControlComponent for garage doors
- ✅ Returns nil for unknown accessory types
- ✅ Compact mode passes through to sub-components
- ✅ Favorite star shown when show_favorite is true

**Critical**: This is the most important missing spec because the dispatcher is the entry point for all controls.

---

### 4. ColorPickerComponent Spec
**Priority**: P2  
**File**: `spec/components/controls/color_picker_component_spec.rb`  
**Estimated Time**: 1 hour

**Test Coverage Needed**:
- ✅ Renders hue slider with correct range (0-360)
- ✅ Renders saturation slider with correct range (0-100)
- ✅ Preview swatch present
- ✅ Apply button present
- ✅ Cancel button present
- ✅ Sliders disabled when offline
- ✅ Stimulus controller wired correctly

---

### 5. BlindControlComponent Spec
**Priority**: P2  
**File**: `spec/components/controls/blind_control_component_spec.rb`  
**Estimated Time**: 1 hour

**Test Coverage Needed**:
- ✅ Renders accessory name
- ✅ Shows offline badge when offline
- ✅ Quick action buttons (Open, 50%, Close)
- ✅ Position slider present with correct range (0-100)
- ✅ Tilt slider present when Target Horizontal Tilt Angle sensor exists
- ✅ Tilt slider hidden when no tilt sensor
- ✅ Obstruction warning shown when obstruction detected
- ✅ All controls disabled when offline
- ✅ Stimulus controller wired correctly

---

### 6. GarageDoorControlComponent Spec
**Priority**: P2  
**File**: `spec/components/controls/garage_door_control_component_spec.rb`  
**Estimated Time**: 1.5 hours

**Test Coverage Needed**:
- ✅ Renders accessory name
- ✅ Shows correct state icon for all 5 states (Open, Closed, Opening, Closing, Stopped)
- ✅ Shows correct state text for all 5 states
- ✅ Shows correct state color class for all 5 states
- ✅ Shows Open button when can_open? is true
- ✅ Hides Open button when can_open? is false
- ✅ Shows Close button when can_close? is true
- ✅ Hides Close button when can_close? is false
- ✅ Shows obstruction warning when obstruction detected
- ✅ Shows locked info when locked
- ✅ Renders open confirmation modal
- ✅ Renders close confirmation modal
- ✅ All buttons disabled when offline
- ✅ Stimulus controller wired correctly

---

### 7. Scenes::CardComponent Spec
**Priority**: P2  
**File**: `spec/components/scenes/card_component_spec.rb`  
**Estimated Time**: 1 hour

**Test Coverage Needed**:
- ✅ Renders scene name
- ✅ Emoji heuristic works (detects emojis from name)
- ✅ Shows accessories count
- ✅ Shows last_executed timestamp when available
- ✅ Shows "Never executed" when last_executed is nil
- ✅ Execute button present
- ✅ Execute button has correct Stimulus wiring
- ✅ Scene controller wired correctly

---

### 8. Shared::ConfirmationModalComponent Spec
**Priority**: P2  
**File**: `spec/components/shared/confirmation_modal_component_spec.rb`  
**Estimated Time**: 0.5 hours

**Test Coverage Needed**:
- ✅ Renders title
- ✅ Renders description
- ✅ Renders confirm button with correct text
- ✅ Renders cancel button with correct text
- ✅ Confirm button has correct class based on confirm_type
- ✅ Cancel button has correct class based on cancel_type
- ✅ Modal backdrop present

---

## Missing Controller Specs

### 9. ScenesController Spec
**Priority**: P2  
**File**: `spec/requests/scenes_controller_spec.rb`  
**Estimated Time**: 2 hours

**Test Coverage Needed**:
- ✅ GET /scenes (index)
  - Returns successful response
  - Returns all scenes for current home
  - Filters by room_id when provided
  - Searches by name when query provided
  - Eager loads associations (home, accessories)
  - Paginates results
- ✅ GET /scenes/:id (show)
  - Returns successful response
  - Loads scene with execution history
  - Returns 404 for non-existent scene
- ✅ POST /scenes/:id/execute
  - Creates ControlEvent record
  - Calls PrefabControlService.trigger_scene
  - Returns success JSON on success
  - Returns error JSON on failure
  - Returns 404 for non-existent scene

---

### 10. AccessoriesController Spec
**Priority**: P2  
**File**: `spec/requests/accessories_controller_spec.rb`  
**Estimated Time**: 2 hours

**Test Coverage Needed**:
- ✅ POST /accessories/control
  - Returns 400 when missing accessory_id
  - Returns 400 when missing characteristic
  - Returns 400 when missing value
  - Returns 404 when accessory not found
  - Returns 403 when accessory is not controllable
  - Returns 403 when characteristic is not writable
  - Calls PrefabControlService.set_characteristic
  - Returns success JSON on success
  - Returns error JSON on failure
  - Coerces values correctly for each characteristic type
  - Passes user_ip and source to service
- ✅ POST /accessories/batch_control
  - Returns 400 when missing accessory_ids
  - Returns 400 when missing action_type
  - Returns 400 when action_type is unknown
  - Returns partial success when some accessories fail
  - Returns results array with success/failure per accessory
  - Calls PrefabControlService for each accessory
  - Resolves batch actions correctly (turn_on, turn_off, set_brightness, set_temperature)

---

## Implementation Strategy

### Phase 1: Critical Components (4 hours)
1. AccessoryControlComponent spec (dispatcher) - **MOST IMPORTANT**
2. LightControlComponent spec
3. FanControlComponent spec

### Phase 2: Controllers (4 hours)
4. AccessoriesController spec
5. ScenesController spec

### Phase 3: Supporting Components (2-3 hours)
6. BlindControlComponent spec
7. GarageDoorControlComponent spec
8. ColorPickerComponent spec
9. Scenes::CardComponent spec
10. ConfirmationModalComponent spec

---

## Test Execution

After implementing all specs, run:

```bash
# Run all component specs
bundle exec rspec spec/components/controls/

# Run all controller specs
bundle exec rspec spec/requests/

# Run full Epic 5 test suite
bundle exec rspec spec/components/controls/ spec/requests/scenes_spec.rb spec/requests/accessories_spec.rb
```

---

## Acceptance Criteria

All tests must:
- ✅ Pass with green status
- ✅ Achieve >90% code coverage for tested files
- ✅ Test both happy path and error conditions
- ✅ Use proper RSpec matchers and best practices
- ✅ Include descriptive test names
- ✅ Use factories for test data
- ✅ Test all public methods and edge cases

---

## Notes

- The audit report correctly identified that test coverage is a P2 priority (not blocking PRD-5-08)
- However, these tests should be implemented before moving to production
- Tests serve as living documentation of component behavior
- Component tests use `render_inline` for ViewComponent testing
- Controller tests use RSpec request specs for integration testing

---

**Status**: Ready for implementation  
**Next Steps**: Implement specs in priority order (Phase 1 → Phase 2 → Phase 3)
