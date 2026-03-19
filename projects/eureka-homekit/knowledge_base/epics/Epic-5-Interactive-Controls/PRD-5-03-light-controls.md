#### PRD-5-03: Light Controls

**Log Requirements**
- Junie: Create/update task log under `knowledge_base/prds-junie-log/PRD-5-03-light-controls-log.md`.

---

### Overview

Implement interactive controls for HomeKit lights with on/off toggle, brightness slider, and color picker (for color-capable lights). Controls appear inline on room detail pages and accessory cards.

---

### Requirements

#### Functional

- On/Off toggle for all lights
- Brightness slider (0-100%) for dimmable lights
- Color picker for color-capable lights (Hue, Saturation)
- Real-time value display during adjustment
- Optimistic UI updates (immediate feedback)
- Rollback on failure with error toast

#### Components

- `Controls::LightControlComponent` - main light control interface
- `Controls::BrightnessSliderComponent` - brightness slider (0-100)
- `Controls::ColorPickerComponent` - HSV color picker
- Use Stimulus controllers for slider/picker interactivity

#### Technical Notes

- Characteristics: `On` (boolean), `Brightness` (0-100), `Hue` (0-360), `Saturation` (0-100)
- Debounce slider changes (300ms) to reduce API calls
- Store slider state in Stimulus controller, send final value on change end

---

### Acceptance Criteria

- [ ] Toggle switches all lights on/off
- [ ] Brightness slider adjusts light level
- [ ] Color picker changes light color (HSV)
- [ ] Optimistic UI updates with rollback on error
- [ ] Controls disabled for offline lights
- [ ] All controls keyboard accessible
- [ ] Mobile touch gestures work for sliders
- [ ] Component tests cover all states

---

### Implementation Highlights

```ruby
# app/components/controls/light_control_component.rb
class Controls::LightControlComponent < ViewComponent::Base
  def initialize(accessory:, show_advanced: false)
    @accessory = accessory
    @show_advanced = show_advanced
    @on_sensor = accessory.sensors.find_by(characteristic_type: 'On')
    @brightness_sensor = accessory.sensors.find_by(characteristic_type: 'Brightness')
    @hue_sensor = accessory.sensors.find_by(characteristic_type: 'Hue')
    @saturation_sensor = accessory.sensors.find_by(characteristic_type: 'Saturation')
  end

  def supports_dimming?
    @brightness_sensor.present?
  end

  def supports_color?
    @hue_sensor.present? && @saturation_sensor.present?
  end

  def current_state
    @on_sensor&.current_value == 'true' || @on_sensor&.current_value == '1'
  end

  def current_brightness
    @brightness_sensor&.current_value&.to_i || 100
  end
end
```

**Stimulus Controller** (`app/javascript/controllers/light_control_controller.js`):
- Handle toggle, slider drag, color picker changes
- Debounce API calls (300ms)
- Show loading/success/error states
- Rollback on failure

---

### Test Cases

- Toggle turns light on/off
- Brightness slider updates light level
- Color picker changes hue/saturation
- Offline lights show disabled state
- Error scenarios display error toast
