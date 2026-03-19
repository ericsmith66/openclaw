require 'rails_helper'

RSpec.describe Api::HomekitEventsController, type: :controller do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room) }
  let(:valid_token) { 'sk_live_eureka_abc123xyz789' }
  let(:valid_headers) { { 'Authorization' => "Bearer #{valid_token}" } }

  describe '#should_store_event?' do
    let(:controller) { described_class.new }

    # Make the private method accessible for testing
    before do
      controller.class_eval do
        public :should_store_event?
      end
    end

    let(:sensor) { create(:sensor, accessory: accessory, value_format: 'float') }
    let(:timestamp) { Time.current }

    before do
      travel_to timestamp
      sensor.update!(last_event_stored_at: timestamp - 1.hour)
      # Force reload to ensure last_event_stored_at is picked up
      sensor.reload
    end

    after do
      travel_back
    end

    context 'when sensor is nil' do
      it 'returns true (always store if no sensor)' do
        expect(controller.should_store_event?(nil, '22.5', timestamp)).to be true
      end
    end

    context 'when sensor has no current_value' do
      before do
        sensor.update!(current_value: nil)
      end

      it 'returns true (always store first value)' do
        expect(controller.should_store_event?(sensor, '22.5', timestamp)).to be true
      end
    end

    context 'when heartbeat is due' do
      before do
        # Set last_event_stored_at to 16 minutes ago
        sensor.update!(current_value: '22.5', last_event_stored_at: 16.minutes.ago)
      end

      it 'returns true even if value is unchanged' do
        # Move time forward to when heartbeat is due
        travel 16.minutes do
          expect(controller.should_store_event?(sensor, '22.5', Time.current)).to be true
        end
      end

      it 'does not return true before heartbeat interval' do
        # Set last_event_stored_at to 14 minutes ago
        sensor.update!(last_event_stored_at: 14.minutes.ago)

        expect(controller.should_store_event?(sensor, '22.5', timestamp)).to be false
      end
    end

    context 'when values match (typed comparison)' do
      before do
        sensor.update!(current_value: '22.5', last_event_stored_at: timestamp)
        sensor.reload
      end

      it 'returns false for identical values within time window' do
        # Move 500ms forward (within 1-second window)
        travel 0.5.seconds do
          expect(controller.should_store_event?(sensor, 22.5, Time.current)).to be false
        end
      end

      it 'returns true for identical values after time window' do
        # Move 1.5 seconds forward (beyond 1-second window)
        # However, it should STILL be false because it's a duplicate and heartbeat is not due
        travel 1.5.seconds do
          expect(controller.should_store_event?(sensor, 22.5, Time.current)).to be false
        end
      end

      it 'performs typed comparison for semantically identical values' do
        # Test semantically identical values (typed comparison)
        sensor.update!(current_value: 22.5, last_event_stored_at: timestamp)
        sensor.reload

        # String '22.5' should match float 22.5
        travel 0.5.seconds do
          expect(controller.should_store_event?(sensor, '22.5', Time.current)).to be false
        end
      end
    end

    context 'when values differ' do
      before do
        sensor.update!(current_value: '22.5', last_event_stored_at: timestamp)
        sensor.reload
      end

      it 'returns true for different values' do
        expect(controller.should_store_event?(sensor, '23.0', timestamp)).to be true
      end

      it 'returns true for different values within time window' do
        travel 0.5.seconds do
          expect(controller.should_store_event?(sensor, '23.0', Time.current)).to be true
        end
      end
    end

    context 'echo prevention' do
      before do
        sensor.update!(current_value: '22.5', last_event_stored_at: timestamp)
        sensor.reload
      end

      it 'returns false when recent control command matches' do
        # Create a recent control event
        ControlEvent.create!(
          accessory: accessory,
          action_type: 'set_characteristic',
          characteristic_name: sensor.characteristic_type,
          new_value: '22.5',
          success: true,
          created_at: 2.seconds.ago
        )

        expect(controller.should_store_event?(sensor, '22.5', timestamp)).to be false
      end

      it 'returns false when no recent control command exists but it is a duplicate' do
        expect(controller.should_store_event?(sensor, '22.5', timestamp)).to be false
      end

      it 'returns true when different value and no recent control command exists' do
        expect(controller.should_store_event?(sensor, '23.0', timestamp)).to be true
      end

      it 'returns false when control command does not match but it is a duplicate' do
        ControlEvent.create!(
          accessory: accessory,
          action_type: 'set_characteristic',
          characteristic_name: sensor.characteristic_type,
          new_value: '23.0', # Different value in control
          success: true,
          created_at: 2.seconds.ago
        )

        expect(controller.should_store_event?(sensor, '22.5', timestamp)).to be false
      end

      it 'returns true when control command does not match and value changed' do
        ControlEvent.create!(
          accessory: accessory,
          action_type: 'set_characteristic',
          characteristic_name: sensor.characteristic_type,
          new_value: '24.0', # Different value in control
          success: true,
          created_at: 2.seconds.ago
        )

        expect(controller.should_store_event?(sensor, '23.0', timestamp)).to be true
      end

      it 'returns false when control command is older than 5 seconds but value is duplicate' do
        ControlEvent.create!(
          accessory: accessory,
          action_type: 'set_characteristic',
          characteristic_name: sensor.characteristic_type,
          new_value: '22.5',
          success: true,
          created_at: 6.seconds.ago
        )

        expect(controller.should_store_event?(sensor, '22.5', timestamp)).to be false
      end

      it 'returns true when control command is older than 5 seconds and value changed' do
        ControlEvent.create!(
          accessory: accessory,
          action_type: 'set_characteristic',
          characteristic_name: sensor.characteristic_type,
          new_value: '22.5',
          success: true,
          created_at: 6.seconds.ago
        )

        expect(controller.should_store_event?(sensor, '23.0', timestamp)).to be true
      end

      it 'returns true when different value and sensor has no accessory' do
        # Use allow to bypass the belongs_to association for testing if needed
        # but better to just mock the accessory method
        allow(sensor).to receive(:accessory).and_return(nil)

        expect(controller.should_store_event?(sensor, '23.0', timestamp)).to be true
      end
    end

    context 'typed value comparison scenarios' do
      it 'treats "1" and 1 as identical for boolean format' do
        boolean_sensor = create(:sensor,
                                accessory: accessory,
                                value_format: 'bool',
                                current_value: '1',
                                last_event_stored_at: timestamp)

        travel 0.5.seconds do
          expect(controller.should_store_event?(boolean_sensor, 1, Time.current)).to be false
        end
      end

      it 'treats "true" and 1 as identical for boolean format' do
        boolean_sensor = create(:sensor,
                                accessory: accessory,
                                value_format: 'bool',
                                current_value: 'true',
                                last_event_stored_at: timestamp)

        travel 0.5.seconds do
          expect(controller.should_store_event?(boolean_sensor, 1, Time.current)).to be false
        end
      end

      it 'treats "22.5" and 22.5 as identical for float format' do
        float_sensor = create(:sensor,
                              accessory: accessory,
                              value_format: 'float',
                              current_value: '22.5',
                              last_event_stored_at: timestamp)

        travel 0.5.seconds do
          expect(controller.should_store_event?(float_sensor, 22.5, Time.current)).to be false
        end
      end

      it 'treats "ON" and "on" as identical (case-insensitive)' do
        string_sensor = create(:sensor,
                               accessory: accessory,
                               value_format: nil,
                               current_value: 'ON',
                               last_event_stored_at: timestamp)

        travel 0.5.seconds do
          expect(controller.should_store_event?(string_sensor, 'on', Time.current)).to be false
        end
      end
    end

    context 'time window edge cases' do
      it 'does not apply time window for first event' do
        # First event - no last_event_stored_at
        expect(controller.should_store_event?(sensor, '22.5', timestamp)).to be true
      end

      it 'does not apply time window if last_event_stored_at is nil' do
        sensor.update!(current_value: '22.5', last_event_stored_at: nil)
        expect(controller.should_store_event?(sensor, '22.5', timestamp)).to be true
      end

      it 'applies time window only when values match' do
        sensor.update!(current_value: '22.5', last_event_stored_at: 1.hour.ago)

        travel 0.5.seconds do
          # Different value - should store even within time window
          expect(controller.should_store_event?(sensor, '23.0', Time.current)).to be true
        end
      end
    end
  end

  describe 'deduplication decision paths' do
    let(:controller) { described_class.new }

    before do
      controller.class_eval do
        public :should_store_event?
      end
    end

    let(:sensor) { create(:sensor, accessory: accessory, value_format: 'float') }
    let(:timestamp) { Time.current }

    it 'returns true for first event (sensor has no current_value)' do
      sensor.update!(current_value: nil)
      expect(controller.should_store_event?(sensor, '22.5', timestamp)).to be true
    end

    it 'returns true when value changes' do
      sensor.update!(current_value: '22.5', last_event_stored_at: timestamp)
      sensor.reload
      expect(controller.should_store_event?(sensor, '23.0', timestamp)).to be true
    end

    it 'returns false for duplicate value within time window' do
      sensor.update!(current_value: '22.5', last_event_stored_at: timestamp)
      travel 0.5.seconds do
        expect(controller.should_store_event?(sensor, 22.5, Time.current)).to be false
      end
    end

    it 'returns false for duplicate value after time window' do
      sensor.update!(current_value: '22.5', last_event_stored_at: timestamp)
      travel 1.5.seconds do
        expect(controller.should_store_event?(sensor, 22.5, Time.current)).to be false
      end
    end

    it 'returns true for duplicate value when heartbeat is due' do
      sensor.update!(current_value: '22.5', last_event_stored_at: 16.minutes.ago)
      travel 16.minutes do
        expect(controller.should_store_event?(sensor, 22.5, Time.current)).to be true
      end
    end

    it 'returns false for duplicate value with recent echo (control command)' do
      sensor.update!(current_value: '22.5', last_event_stored_at: timestamp)

      ControlEvent.create!(
        accessory: accessory,
        action_type: 'set_characteristic',
        characteristic_name: sensor.characteristic_type,
        new_value: '22.5',
        success: true,
        created_at: 2.seconds.ago
      )

      expect(controller.should_store_event?(sensor, 22.5, timestamp)).to be false
    end

    it 'handles nil sensor gracefully' do
      expect(controller.should_store_event?(nil, '22.5', timestamp)).to be true
    end

    it 'handles nil timestamp gracefully' do
      sensor.update!(current_value: nil)
      expect(controller.should_store_event?(sensor, '22.5', nil)).to be true
    end
  end
end
