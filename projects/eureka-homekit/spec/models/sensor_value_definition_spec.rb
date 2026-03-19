require 'rails_helper'

RSpec.describe SensorValueDefinition, type: :model do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room) }
  let(:sensor) { create(:sensor, accessory: accessory) }

  describe '.discover!' do
    context 'with Temperature sensor' do
      before do
        sensor.update!(
          characteristic_type: 'Current Temperature',
          value_format: 'float'
        )
      end

      it 'auto-populates label for temperature in Fahrenheit' do
        definition = SensorValueDefinition.discover!(sensor, 20.0, Time.current)
        expect(definition.label).to eq('68.0°F')
      end
    end

    context 'with Humidity sensor' do
      before do
        sensor.update!(
          characteristic_type: 'Current Relative Humidity',
          value_format: 'int'
        )
      end

      it 'auto-populates label with %' do
        definition = SensorValueDefinition.discover!(sensor, 45, Time.current)
        expect(definition.label).to eq('45%')
      end
    end

    context 'with Light Level sensor' do
      before do
        sensor.update!(
          characteristic_type: 'Current Ambient Light Level',
          value_format: 'int'
        )
      end

      it 'auto-populates label with lux' do
        definition = SensorValueDefinition.discover!(sensor, 120, Time.current)
        expect(definition.label).to eq('120 lux')
      end
    end

    context 'with Motion sensor' do
      before do
        sensor.update!(
          characteristic_type: 'Motion Detected',
          value_format: 'bool'
        )
      end

      it 'auto-populates label as Detected/Clear' do
        expect(SensorValueDefinition.discover!(sensor, '1', Time.current).label).to eq('Detected')
        expect(SensorValueDefinition.discover!(sensor, '0', Time.current).label).to eq('Clear')
      end
    end
  end
end
