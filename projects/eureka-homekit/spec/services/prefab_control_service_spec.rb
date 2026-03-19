require 'rails_helper'

RSpec.describe PrefabControlService do
  let(:home) { create(:home, name: 'Main House') }
  let(:room) { create(:room, home: home, name: 'Living Room') }
  let(:accessory) { create(:accessory, room: room, name: 'Light 1', uuid: 'acc-123') }
  let(:scene) { create(:scene, home: home, uuid: 'scene-456', name: 'Good Night') }
  let!(:on_sensor) { create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: '0', is_writable: true) }

  describe '.set_characteristic' do
    context 'when successful' do
      before do
        allow(PrefabClient).to receive(:update_characteristic).and_return(
          { success: true, latency_ms: 150 }
        )
      end

      it 'returns success response' do
        result = described_class.set_characteristic(accessory: accessory, characteristic: 'On', value: true)

        expect(result[:success]).to be true
        expect(result[:latency_ms]).to eq(150)
      end

      it 'creates a ControlEvent record' do
        expect {
          described_class.set_characteristic(accessory: accessory, characteristic: 'On', value: true)
        }.to change(ControlEvent, :count).by(1)

        event = ControlEvent.last
        expect(event.accessory).to eq(accessory)
        expect(event.action_type).to eq('set_characteristic')
        expect(event.characteristic_name).to eq('On')
        expect(event.new_value).to eq('true')
        expect(event.success).to be true
      end
    end

    context 'when first attempt fails but retry succeeds' do
      before do
        @call_count = 0
        allow(PrefabClient).to receive(:update_characteristic) do |*args|
          @call_count += 1
          if @call_count == 1
            { success: false, error: 'Device offline', latency_ms: 200 }
          else
            { success: true, latency_ms: 100 }
          end
        end
        allow(ENV).to receive(:fetch).with('PREFAB_RETRY_ATTEMPTS', '1').and_return('1')
      end

      it 'retries once' do
        described_class.set_characteristic(accessory: accessory, characteristic: 'On', value: true)

        expect(@call_count).to eq(2)
      end

      it 'returns success after retry' do
        result = described_class.set_characteristic(accessory: accessory, characteristic: 'On', value: true)

        expect(result[:success]).to be true
      end

      it 'creates one ControlEvent (the successful one)' do
        expect {
          described_class.set_characteristic(accessory: accessory, characteristic: 'On', value: true)
        }.to change(ControlEvent, :count).by(1)

        event = ControlEvent.last
        expect(event.success).to be true
      end
    end

    context 'when all attempts fail' do
      before do
        allow(PrefabClient).to receive(:update_characteristic).and_return(
          { success: false, error: 'Device offline', latency_ms: 200 }
        )
        allow(ENV).to receive(:fetch).with('PREFAB_RETRY_ATTEMPTS', '1').and_return('0')
      end

      it 'returns failure' do
        result = described_class.set_characteristic(accessory: accessory, characteristic: 'On', value: true)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Device offline')
      end

      it 'creates a failed ControlEvent' do
        described_class.set_characteristic(accessory: accessory, characteristic: 'On', value: true)

        event = ControlEvent.last
        expect(event.success).to be false
        expect(event.error_message).to eq('Device offline')
      end
    end

    context 'with boolean value' do
      it 'coerces true values' do
        allow(PrefabClient).to receive(:update_characteristic).and_return({ success: true, latency_ms: 100 })

        described_class.set_characteristic(accessory: accessory, characteristic: 'On', value: true)

        event = ControlEvent.last
        expect(event.new_value).to eq('true')
      end
    end

    context 'with user_ip and source' do
      it 'records them in the ControlEvent' do
        described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true,
          user_ip: '192.168.1.100',
          source: 'ai-decision'
        )

        event = ControlEvent.last
        expect(event.user_ip).to eq('192.168.1.100')
        expect(event.source).to eq('ai-decision')
      end
    end

    context 'with deduplication' do
      before do
        allow(PrefabClient).to receive(:update_characteristic).and_return(
          { success: true, latency_ms: 150 }
        )
      end

      it 'deduplicates identical commands within 10 seconds' do
        # First command succeeds
        first_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )
        expect(first_result[:success]).to be true
        expect(first_result[:deduplicated]).to be_nil

        # Second identical command within 10 seconds should be deduplicated
        second_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )
        expect(second_result[:success]).to be true
        expect(second_result[:deduplicated]).to be true
        expect(second_result[:message]).to eq('Identical command already sent')
      end

      it 'does not deduplicate after 10 seconds' do
        # First command
        first_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )
        first_event = ControlEvent.last

        # Manually age the first event to be older than 10 seconds
        first_event.update_column(:created_at, 11.seconds.ago)

        # Second command should not be deduplicated
        second_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )
        expect(second_result[:deduplicated]).to be_nil
        expect(second_result[:success]).to be true
      end

      it 'does not deduplicate different values' do
        # First command with value true
        described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )

        # Second command with value false
        second_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: false
        )
        expect(second_result[:deduplicated]).to be_nil
      end

      it 'does not deduplicate different characteristics' do
        # First command for On
        described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )

        # Second command for Brightness
        create(:sensor, accessory: accessory, characteristic_type: 'Brightness', current_value: '50', is_writable: true)
        second_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'Brightness',
          value: 50
        )
        expect(second_result[:deduplicated]).to be_nil
      end

      it 'does not deduplicate different accessories' do
        other_accessory = create(:accessory, room: room, name: 'Light 2')
        create(:sensor, accessory: other_accessory, characteristic_type: 'On', current_value: '0', is_writable: true)

        # First command for accessory 1
        described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )

        # Second command for accessory 2
        second_result = described_class.set_characteristic(
          accessory: other_accessory,
          characteristic: 'On',
          value: true
        )
        expect(second_result[:deduplicated]).to be_nil
      end

      it 'only deduplicates successful commands' do
        # First command fails
        allow(PrefabClient).to receive(:update_characteristic).and_return(
          { success: false, error: 'Device offline', latency_ms: 200 }
        )
        allow(ENV).to receive(:fetch).with('PREFAB_RETRY_ATTEMPTS', '1').and_return('0')

        first_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )
        expect(first_result[:success]).to be false

        # Second identical command should NOT be deduplicated (first was failure)
        allow(PrefabClient).to receive(:update_characteristic).and_return(
          { success: true, latency_ms: 150 }
        )

        second_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )
        expect(second_result[:success]).to be true
        expect(second_result[:deduplicated]).to be_nil
      end

      it 'does not create a ControlEvent for deduplicated commands' do
        # First command
        described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )

        # Second command should be deduplicated and not create an event
        expect {
          described_class.set_characteristic(
            accessory: accessory,
            characteristic: 'On',
            value: true
          )
        }.not_to change(ControlEvent, :count)
      end

      it 'returns original event details for deduplicated commands' do
        # First command
        first_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )
        original_event = ControlEvent.last

        # Second command
        second_result = described_class.set_characteristic(
          accessory: accessory,
          characteristic: 'On',
          value: true
        )

        expect(second_result[:original_event_id]).to eq(original_event.id)
        expect(second_result[:original_timestamp]).to eq(original_event.created_at)
      end
    end
  end

  describe '.trigger_scene' do
    context 'when successful' do
      before do
        allow(PrefabClient).to receive(:execute_scene).and_return(
          { success: true, latency_ms: 200 }
        )
      end

      it 'returns success response' do
        result = described_class.trigger_scene(scene: scene)

        expect(result[:success]).to be true
        expect(result[:latency_ms]).to eq(200)
      end

      it 'creates a ControlEvent record' do
        expect {
          described_class.trigger_scene(scene: scene)
        }.to change(ControlEvent, :count).by(1)

        event = ControlEvent.last
        expect(event.scene).to eq(scene)
        expect(event.action_type).to eq('execute_scene')
        expect(event.success).to be true
      end
    end

    context 'when scene not found' do
      before do
        allow(PrefabClient).to receive(:execute_scene).and_return(
          { success: false, error: 'Scene not found', latency_ms: 150 }
        )
        allow(ENV).to receive(:fetch).with('PREFAB_RETRY_ATTEMPTS', '1').and_return('0')
      end

      it 'returns failure' do
        result = described_class.trigger_scene(scene: scene)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Scene not found')
      end

      it 'creates a failed ControlEvent' do
        described_class.trigger_scene(scene: scene)

        event = ControlEvent.last
        expect(event.success).to be false
        expect(event.error_message).to eq('Scene not found')
      end
    end

    context 'with retry' do
      before do
        @call_count = 0
        allow(PrefabClient).to receive(:execute_scene) do |*args|
          @call_count += 1
          if @call_count == 1
            { success: false, error: 'Network error', latency_ms: 300 }
          else
            { success: true, latency_ms: 100 }
          end
        end
        allow(ENV).to receive(:fetch).with('PREFAB_RETRY_ATTEMPTS', '1').and_return('1')
      end

      it 'retries once' do
        described_class.trigger_scene(scene: scene)

        expect(@call_count).to eq(2)
      end
    end
  end

  describe '.scrub_error_message' do
    it 'filters bearer tokens' do
      message = 'Unauthorized: Bearer abc123xyz is invalid'
      expect(described_class.send(:scrub_error_message, message)).to eq('Unauthorized: Bearer [FILTERED] is invalid')
    end

    it 'filters API keys' do
      message = 'Error: api_key=sk-12345 is invalid'
      expect(described_class.send(:scrub_error_message, message)).to eq('Error: api_key=[FILTERED] is invalid')
    end

    it 'returns nil for nil input' do
      expect(described_class.send(:scrub_error_message, nil)).to be_nil
    end
  end

  describe 'ControlEvent class methods' do
    before do
      # Create some test events
      3.times do |i|
        ControlEvent.create!(
          action_type: 'set_characteristic',
          success: i < 2, # 2 success, 1 failure
          latency_ms: 100 + i * 10,
          created_at: i.hours.ago
        )
      end
    end

    describe '.success_rate' do
      it 'calculates success rate' do
        rate = ControlEvent.success_rate
        expect(rate).to be_within(0.1).of(66.67)
      end

      it 'returns 0 when no records' do
        ControlEvent.delete_all
        expect(ControlEvent.success_rate).to eq(0.0)
      end
    end

    describe '.average_latency' do
      it 'calculates average latency' do
        lat = ControlEvent.average_latency
        expect(lat).to be_within(0.1).of(110.0)
      end

      it 'returns 0 when no records' do
        ControlEvent.delete_all
        expect(ControlEvent.average_latency).to eq(0.0)
      end
    end

    describe '.recent' do
      it 'returns recent events' do
        events = ControlEvent.recent
        expect(events.count).to be <= 100
        expect(events.first.created_at).to be > events.last.created_at
      end
    end
  end
end
