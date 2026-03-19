require 'rails_helper'

RSpec.describe Sensor, type: :model do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room) }

  describe '#compare_values' do
    context 'with float format' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: 'float') }

      it 'returns true for semantically identical numeric values' do
        expect(sensor.compare_values('22.5', 22.5)).to be true
        expect(sensor.compare_values('22', 22)).to be true
        expect(sensor.compare_values(22.5, '22.5')).to be true
      end

      it 'returns false when values differ' do
        expect(sensor.compare_values('22.5', 23.0)).to be false
        expect(sensor.compare_values('22', 23)).to be false
      end

      it 'handles float comparison with epsilon tolerance' do
        expect(sensor.compare_values(22.5, 22.500001)).to be true
        expect(sensor.compare_values(22.5, 22.5001)).to be true # Within 0.01 epsilon
        expect(sensor.compare_values(22.5, 22.6)).to be false   # Outside epsilon
        expect(sensor.compare_values(22.5, 21.5)).to be false  # Outside epsilon
      end

      it 'handles string floats with decimal points' do
        expect(sensor.compare_values('22.5', '22.5')).to be true
        expect(sensor.compare_values('22.50', '22.5')).to be true
      end

      it 'handles integers when format is float' do
        expect(sensor.compare_values('22', 22)).to be true
        expect(sensor.compare_values('22.0', 22)).to be true
      end
    end

    context 'with int format' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: 'int') }

      it 'returns true for same integer values' do
        expect(sensor.compare_values('22', 22)).to be true
        expect(sensor.compare_values(22, '22')).to be true
      end

      it 'returns false when values differ' do
        expect(sensor.compare_values('22', 23)).to be false
      end
    end

    context 'with uint8 format' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: 'uint8') }

      it 'returns true for same uint8 values' do
        expect(sensor.compare_values('1', 1)).to be true
        expect(sensor.compare_values(1, '1')).to be true
      end

      it 'returns false when values differ' do
        expect(sensor.compare_values('1', 2)).to be false
      end
    end

    context 'with bool format' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: 'bool') }

      it 'returns true for semantically identical boolean values' do
        expect(sensor.compare_values('1', true)).to be true
        expect(sensor.compare_values('true', 1)).to be true
        expect(sensor.compare_values('true', true)).to be true
        expect(sensor.compare_values('0', false)).to be true
        expect(sensor.compare_values('false', 0)).to be true
        expect(sensor.compare_values('false', false)).to be true
        expect(sensor.compare_values('1', 1)).to be true
      end

      it 'returns false for non-boolean values' do
        expect(sensor.compare_values('1', '0')).to be false
        expect(sensor.compare_values('true', 'false')).to be false
      end

      it 'returns false when value is not boolean-like' do
        expect(sensor.compare_values('1', '2')).to be false
        expect(sensor.compare_values('true', 'foo')).to be false
      end
    end

    context 'with string values (no format specified)' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: nil) }

      it 'performs case-insensitive comparison' do
        expect(sensor.compare_values('ON', 'on')).to be true
        expect(sensor.compare_values('OFF', 'off')).to be true
        expect(sensor.compare_values('OPEN', 'open')).to be true
      end

      it 'returns false for different strings' do
        expect(sensor.compare_values('ON', 'OFF')).to be false
        expect(sensor.compare_values('OPEN', 'CLOSED')).to be false
      end

      it 'handles numeric strings' do
        expect(sensor.compare_values('22', 22)).to be true
        expect(sensor.compare_values('22.5', 22.5)).to be true
      end
    end

    context 'with nil values' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: 'float') }

      it 'returns true for both nil' do
        expect(sensor.compare_values(nil, nil)).to be true
      end

      it 'returns false when one is nil' do
        expect(sensor.compare_values(nil, 22.5)).to be false
        expect(sensor.compare_values(22.5, nil)).to be false
      end
    end

    it 'falls back to string comparison on error' do
      sensor = create(:sensor, accessory: accessory, value_format: 'float')
      allow(sensor).to receive(:coerce_value_without_conversion).and_raise(StandardError)

      expect(sensor.compare_values('22.5', '22.5')).to be true
      expect(sensor.compare_values('22.5', '23.0')).to be false
    end

    it 'logs warnings on error' do
      sensor = create(:sensor, accessory: accessory, value_format: 'float')
      # Match the actual log message in sensor.rb
      expect(Rails.logger).to receive(:warn).with(/\[Sensor#compare_values\] Failed for sensor #{sensor.id}:/).at_least(:once)

      allow(sensor).to receive(:coerce_value_without_conversion).and_raise(StandardError)
      sensor.compare_values('22.5', '22.5')
    end

    it 'does not apply temperature conversion for deduplication' do
      # Temperature sensors should NOT convert Celsius to Fahrenheit for deduplication
      sensor = create(:sensor,
                      accessory: accessory,
                      characteristic_type: 'Current Temperature',
                      value_format: 'float')

      # 22.5°C and 22.5°C should be identical (even though 22.5°C = 72.5°F for display)
      expect(sensor.compare_values(22.5, 22.5)).to be true

      # Different temperatures should not match
      expect(sensor.compare_values(22.5, 23.0)).to be false
    end
  end

  describe '#coerce_value_without_conversion' do
    context 'with float format' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: 'float') }

      it 'converts string to float' do
        expect(sensor.send(:coerce_value_without_conversion, '22.5')).to eq(22.5)
      end

      it 'converts integer to float' do
        expect(sensor.send(:coerce_value_without_conversion, 22)).to eq(22.0)
      end

      it 'handles nil' do
        expect(sensor.send(:coerce_value_without_conversion, nil)).to be_nil
      end

      it 'handles empty string' do
        expect(sensor.send(:coerce_value_without_conversion, '')).to eq(0.0)
      end
    end

    context 'with int format' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: 'int') }

      it 'converts string to integer' do
        expect(sensor.send(:coerce_value_without_conversion, '22')).to eq(22)
      end

      it 'converts float string to integer (truncates)' do
        expect(sensor.send(:coerce_value_without_conversion, '22.7')).to eq(22)
      end

      it 'handles nil' do
        expect(sensor.send(:coerce_value_without_conversion, nil)).to be_nil
      end
    end

    context 'with uint8 format' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: 'uint8') }

      it 'converts string to uint8' do
        expect(sensor.send(:coerce_value_without_conversion, '1')).to eq(1)
        expect(sensor.send(:coerce_value_without_conversion, '255')).to eq(255)
      end

      it 'handles nil' do
        expect(sensor.send(:coerce_value_without_conversion, nil)).to be_nil
      end
    end

    context 'with bool format' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: 'bool') }

      it 'coerces "1" to true' do
        expect(sensor.send(:coerce_value_without_conversion, '1')).to be true
      end

      it 'coerces 1 to true' do
        expect(sensor.send(:coerce_value_without_conversion, 1)).to be true
      end

      it 'coerces "true" (case-insensitive) to true' do
        expect(sensor.send(:coerce_value_without_conversion, 'true')).to be true
        expect(sensor.send(:coerce_value_without_conversion, 'True')).to be true
        expect(sensor.send(:coerce_value_without_conversion, 'TRUE')).to be true
      end

      it 'coerces "0" to false' do
        expect(sensor.send(:coerce_value_without_conversion, '0')).to be false
      end

      it 'coerces 0 to false' do
        expect(sensor.send(:coerce_value_without_conversion, 0)).to be false
      end

      it 'coerces "false" (case-insensitive) to false' do
        expect(sensor.send(:coerce_value_without_conversion, 'false')).to be false
        expect(sensor.send(:coerce_value_without_conversion, 'False')).to be false
      end

      it 'returns true for "yes" and "on"' do
        expect(sensor.send(:coerce_value_without_conversion, 'yes')).to be true
        expect(sensor.send(:coerce_value_without_conversion, 'on')).to be true
      end

      it 'returns false for unrecognized values' do
        expect(sensor.send(:coerce_value_without_conversion, '2')).to be false
        expect(sensor.send(:coerce_value_without_conversion, 'maybe')).to be false
      end

      it 'handles nil' do
        expect(sensor.send(:coerce_value_without_conversion, nil)).to be_nil
      end
    end

    context 'without format (auto-detect)' do
      let(:sensor) { create(:sensor, accessory: accessory, value_format: nil) }

      it 'detects numeric strings' do
        expect(sensor.send(:coerce_value_without_conversion, '22')).to eq(22)
        expect(sensor.send(:coerce_value_without_conversion, '22.5')).to eq(22.5)
        expect(sensor.send(:coerce_value_without_conversion, '-22.5')).to eq(-22.5)
      end

      it 'handles non-numeric strings' do
        expect(sensor.send(:coerce_value_without_conversion, 'hello')).to eq('hello')
        expect(sensor.send(:coerce_value_without_conversion, 'ON')).to eq('ON')
      end

      it 'handles integers' do
        expect(sensor.send(:coerce_value_without_conversion, 22)).to eq(22)
      end

      it 'handles floats' do
        expect(sensor.send(:coerce_value_without_conversion, 22.5)).to eq(22.5)
      end

      it 'handles nil' do
        expect(sensor.send(:coerce_value_without_conversion, nil)).to be_nil
      end
    end
  end

  describe '#type_value' do
    context 'with temperature sensor' do
      let(:sensor) { create(:sensor, accessory: accessory,
                           characteristic_type: 'Current Temperature',
                           value_format: 'float') }

      it 'converts Celsius to Fahrenheit for display' do
        expect(sensor.type_value(22.5)).to eq(72.5) # 22.5°C = 72.5°F
      end

      it 'preserves float values' do
        expect(sensor.type_value(22.5)).to be_a(Float)
      end
    end

    context 'with humidity sensor' do
      let(:sensor) { create(:sensor, accessory: accessory,
                           characteristic_type: 'Current Relative Humidity',
                           value_format: 'float') }

      it 'does NOT convert humidity values' do
        expect(sensor.type_value(45.0)).to eq(45.0) # No conversion for humidity
      end
    end
  end
end
