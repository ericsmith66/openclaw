#### PRD-5-05: Thermostat Controls

**Log Requirements**
- Junie: Create/update task log under `knowledge_base/prds-junie-log/PRD-5-05-thermostat-controls-log.md`.

---

### Overview

Climate control UI for HomeKit thermostats with target temperature adjustment, mode selection (heat/cool/auto/off), and current temperature display.

---

### Requirements

#### Functional

- Target temperature slider with +/- buttons
- Mode selector (Heat, Cool, Auto, Off)
- Current temperature display (read-only)
- Temperature units toggle (°C / °F)
- Fan control (if supported)
- Heating/cooling state indicator

#### Components

- `Controls::ThermostatControlComponent` - full thermostat interface
- `Controls::TemperatureSliderComponent` - temperature adjustment
- `Controls::ModeSelector Component` - mode buttons

#### Technical Notes

- Characteristics:
  - `Current Temperature` (read-only)
  - `Target Temperature` (0-100°C or 32-212°F)
  - `Current Heating Cooling State` (0=off, 1=heat, 2=cool)
  - `Target Heating Cooling State` (0=off, 1=heat, 2=cool, 3=auto)
  - `Temperature Display Units` (0=celsius, 1=fahrenheit)
- Debounce temperature slider (500ms)
- Show visual indicator when actively heating/cooling

---

### Acceptance Criteria

- [ ] Temperature slider adjusts target temp
- [ ] +/- buttons increment by 1 degree
- [ ] Mode selector changes heating/cooling mode
- [ ] Current temp displayed (read-only)
- [ ] Units toggle (°C / °F)
- [ ] Heating/cooling indicator shows state
- [ ] Keyboard accessible (arrow keys for slider)

---

### Implementation Highlights

```ruby
# app/components/controls/thermostat_control_component.rb
class Controls::ThermostatControlComponent < ViewComponent::Base
  def initialize(accessory:)
    @accessory = accessory
    @current_temp_sensor = accessory.sensors.find_by(characteristic_type: 'Current Temperature')
    @target_temp_sensor = accessory.sensors.find_by(characteristic_type: 'Target Temperature')
    @mode_sensor = accessory.sensors.find_by(characteristic_type: 'Target Heating Cooling State')
    @state_sensor = accessory.sensors.find_by(characteristic_type: 'Current Heating Cooling State')
    @units_sensor = accessory.sensors.find_by(characteristic_type: 'Temperature Display Units')
  end

  def current_temperature
    @current_temp_sensor&.current_value&.to_f
  end

  def target_temperature
    @target_temp_sensor&.current_value&.to_f || 20
  end

  def current_mode
    modes = ['Off', 'Heat', 'Cool', 'Auto']
    modes[@mode_sensor&.current_value&.to_i || 0]
  end

  def heating?
    @state_sensor&.current_value == '1'
  end

  def cooling?
    @state_sensor&.current_value == '2'
  end

  def units_celsius?
    @units_sensor&.current_value == '0' || @units_sensor.nil?
  end
end
```

---

### Test Cases

- Temperature adjustment via slider and +/- buttons
- Mode changes (heat/cool/auto/off)
- Current temp displays correctly
- Heating/cooling indicator shows active state
- Units toggle switches display (°C / °F)
