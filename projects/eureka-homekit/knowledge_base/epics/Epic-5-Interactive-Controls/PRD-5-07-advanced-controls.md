#### PRD-5-07: Advanced Controls (Fans, Blinds, Garage Doors)

**Log Requirements**
- Junie: Create/update task log under `knowledge_base/prds-junie-log/PRD-5-07-advanced-controls-log.md`.

---

### Overview

Controls for less common but important accessory types: ceiling fans (speed control), window blinds (position/tilt), and garage doors (open/close with confirmation).

---

### Requirements

#### Functional

**Fans**:
- On/off toggle
- Speed slider (0-100%)
- Rotation direction toggle (if supported)
- Oscillation toggle (if supported)

**Blinds/Shades**:
- Position slider (0=closed, 100=open)
- Tilt angle slider (if supported)
- Quick action buttons (Open, Close, 50%)

**Garage Doors**:
- Open/close button with confirmation
- Current state indicator (open/closed/opening/closing/stopped/jammed)
- Obstruction detection alert

#### Components

- `Controls::FanControlComponent`
- `Controls::BlindControlComponent`
- `Controls::GarageDoorControlComponent`

#### Technical Notes

**Fan Characteristics**:
- `Active` (0=inactive, 1=active)
- `Rotation Speed` (0-100)
- `Rotation Direction` (0=clockwise, 1=counterclockwise)
- `Swing Mode` (0=disabled, 1=enabled)

**Blind Characteristics**:
- `Current Position` (0-100, read-only)
- `Target Position` (0-100)
- `Current Horizontal Tilt Angle` (-90 to 90, read-only)
- `Target Horizontal Tilt Angle` (-90 to 90)

**Garage Door Characteristics**:
- `Current Door State` (0=open, 1=closed, 2=opening, 3=closing, 4=stopped)
- `Target Door State` (0=open, 1=closed)
- `Obstruction Detected` (boolean)

---

### Acceptance Criteria

- [ ] Fan controls adjust speed and rotation
- [ ] Blind controls adjust position and tilt
- [ ] Garage door controls open/close with confirmation
- [ ] All controls show current state
- [ ] Obstruction alerts shown for garage doors
- [ ] Quick action buttons work (50%, Close, Open)
- [ ] All controls keyboard accessible

---

### Implementation Highlights

```ruby
# app/components/controls/fan_control_component.rb
class Controls::FanControlComponent < ViewComponent::Base
  def initialize(accessory:)
    @accessory = accessory
    @active_sensor = accessory.sensors.find_by(characteristic_type: 'Active')
    @speed_sensor = accessory.sensors.find_by(characteristic_type: 'Rotation Speed')
    @direction_sensor = accessory.sensors.find_by(characteristic_type: 'Rotation Direction')
  end

  def active?
    @active_sensor&.current_value == '1'
  end

  def current_speed
    @speed_sensor&.current_value&.to_i || 0
  end

  def supports_direction?
    @direction_sensor.present?
  end
end

# app/components/controls/garage_door_control_component.rb
class Controls::GarageDoorControlComponent < ViewComponent::Base
  def initialize(accessory:)
    @accessory = accessory
    @current_state_sensor = accessory.sensors.find_by(characteristic_type: 'Current Door State')
    @obstruction_sensor = accessory.sensors.find_by(characteristic_type: 'Obstruction Detected')
  end

  def state_text
    states = ['Open', 'Closed', 'Opening', 'Closing', 'Stopped']
    states[@current_state_sensor&.current_value&.to_i || 0]
  end

  def obstructed?
    @obstruction_sensor&.current_value == 'true' || @obstruction_sensor&.current_value == '1'
  end

  def closed?
    @current_state_sensor&.current_value == '1'
  end
end
```

---

### Test Cases

- Fan speed slider adjusts rotation speed
- Fan direction toggle works
- Blind position slider moves blinds
- Blind tilt slider adjusts angle
- Garage door open/close with confirmation
- Obstruction alert shown when detected
- Quick action buttons (50%, Open, Close)
