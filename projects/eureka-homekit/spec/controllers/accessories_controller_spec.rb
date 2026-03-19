require 'rails_helper'

RSpec.describe AccessoriesController, type: :controller do
  let(:home) { create(:home, name: 'Main House') }
  let(:room) { create(:room, home: home, name: 'Living Room') }
  let(:accessory) { create(:accessory, room: room, name: 'Light 1', uuid: 'light-uuid-1') }

  describe 'POST #control' do
    let(:on_sensor) do
      create(:sensor,
        accessory: accessory,
        characteristic_type: 'On',
        current_value: '0',
        is_writable: true
      )
    end

    before do
      on_sensor # Ensure sensor exists
    end

    context 'when successful' do
      before do
        allow(PrefabControlService).to receive(:set_characteristic).and_return(
          { success: true }
        )
      end

      it 'returns success response' do
        post :control, params: { accessory_id: accessory.uuid, characteristic: 'On', value: 'true' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['value']).to be true
      end

      it 'calls PrefabControlService with correct parameters' do
        expect(PrefabControlService).to receive(:set_characteristic).with(
          accessory: accessory,
          characteristic: 'On',
          value: true,
          user_ip: '0.0.0.0',
          source: 'web'
        )

        post :control, params: { accessory_id: accessory.uuid, characteristic: 'On', value: 'true' }
      end

      it 'coerces truthy boolean values correctly' do
        allow(PrefabControlService).to receive(:set_characteristic).and_return({ success: true })

        [ '1', 'true', 'on', 'yes' ].each do |truthy_value|
          post :control, params: { accessory_id: accessory.uuid, characteristic: 'On', value: truthy_value }
        end

        expect(PrefabControlService).to have_received(:set_characteristic).exactly(4).times.with(
          hash_including(value: true)
        )
      end

      it 'coerces falsy boolean values correctly' do
        allow(PrefabControlService).to receive(:set_characteristic).and_return({ success: true })

        [ '0', 'false', 'off', 'no' ].each do |falsy_value|
          post :control, params: { accessory_id: accessory.uuid, characteristic: 'On', value: falsy_value }
        end

        expect(PrefabControlService).to have_received(:set_characteristic).exactly(4).times.with(
          hash_including(value: false)
        )
      end
    end

    context 'when accessory not found' do
      it 'returns 404 error' do
        post :control, params: { accessory_id: 'nonexistent-uuid', characteristic: 'On', value: 'true' }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to eq('Accessory not found')
      end
    end

    context 'when missing required parameters' do
      it 'returns 400 when characteristic is missing' do
        post :control, params: { accessory_id: accessory.uuid, value: 'true' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to include('Missing required parameters')
      end

      it 'returns 400 when value is missing' do
        post :control, params: { accessory_id: accessory.uuid, characteristic: 'On' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to include('Missing required parameters')
      end
    end

    context 'when accessory is not controllable' do
      let(:read_only_accessory) { create(:accessory, room: room, name: 'Sensor 1') }

      before do
        create(:sensor,
          accessory: read_only_accessory,
          characteristic_type: 'Temperature',
          is_writable: false
        )
      end

      it 'returns 403 forbidden' do
        post :control, params: {
          accessory_id: read_only_accessory.uuid,
          characteristic: 'Temperature',
          value: '22'
        }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to eq('Accessory is not controllable')
      end
    end

    context 'when characteristic is not writable' do
      before do
        create(:sensor,
          accessory: accessory,
          characteristic_type: 'Temperature',
          is_writable: false
        )
      end

      it 'returns 403 forbidden' do
        post :control, params: {
          accessory_id: accessory.uuid,
          characteristic: 'Temperature',
          value: '22'
        }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to eq('Characteristic Temperature is not writable')
      end
    end

    context 'when PrefabControlService fails' do
      before do
        allow(PrefabControlService).to receive(:set_characteristic).and_return(
          { success: false, error: 'Device offline' }
        )
      end

      it 'returns 500 with error message' do
        post :control, params: { accessory_id: accessory.uuid, characteristic: 'On', value: 'true' }

        expect(response).to have_http_status(:internal_server_error)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to eq('Device offline')
      end
    end

    context 'with value coercion' do
      let(:brightness_sensor) do
        create(:sensor,
          accessory: accessory,
          characteristic_type: 'Brightness',
          is_writable: true
        )
      end

      before do
        brightness_sensor
        allow(PrefabControlService).to receive(:set_characteristic).and_return({ success: true })
      end

      it 'clamps brightness values to 0-100' do
        post :control, params: { accessory_id: accessory.uuid, characteristic: 'Brightness', value: '150' }
        expect(PrefabControlService).to have_received(:set_characteristic).with(
          hash_including(value: 100)
        )

        post :control, params: { accessory_id: accessory.uuid, characteristic: 'Brightness', value: '-10' }
        expect(PrefabControlService).to have_received(:set_characteristic).with(
          hash_including(value: 0)
        )
      end
    end

    context 'with deduplication' do
      before do
        allow(PrefabControlService).to receive(:set_characteristic).and_return(
          { success: true, deduplicated: true, message: 'Identical command already sent' }
        )
      end

      it 'handles deduplicated responses' do
        post :control, params: { accessory_id: accessory.uuid, characteristic: 'On', value: 'true' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end
    end
  end

  describe 'POST #batch_control' do
    let(:light1) { create(:accessory, room: room, name: 'Light 1', uuid: 'light-1') }
    let(:light2) { create(:accessory, room: room, name: 'Light 2', uuid: 'light-2') }

    before do
      create(:sensor, accessory: light1, characteristic_type: 'On', is_writable: true)
      create(:sensor, accessory: light2, characteristic_type: 'On', is_writable: true)
    end

    context 'when successful' do
      before do
        allow(PrefabControlService).to receive(:set_characteristic).and_return({ success: true })
      end

      it 'controls multiple accessories' do
        post :batch_control, params: {
          accessory_ids: [ light1.uuid, light2.uuid ],
          action_type: 'turn_on'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['total']).to eq(2)
        expect(json['succeeded']).to eq(2)
        expect(json['failed']).to eq(0)
      end

      it 'calls PrefabControlService for each accessory' do
        expect(PrefabControlService).to receive(:set_characteristic).twice

        post :batch_control, params: {
          accessory_ids: [ light1.uuid, light2.uuid ],
          action_type: 'turn_on'
        }
      end
    end

    context 'when missing required parameters' do
      it 'returns 400 when accessory_ids is missing' do
        post :batch_control, params: { action_type: 'turn_on' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to include('Missing required parameter: accessory_ids')
      end

      it 'returns 400 when action_type is missing' do
        post :batch_control, params: { accessory_ids: [ light1.uuid ] }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to include('Missing required parameter: action_type')
      end
    end

    context 'with unknown action_type' do
      it 'returns 400 error' do
        post :batch_control, params: {
          accessory_ids: [ light1.uuid ],
          action_type: 'invalid_action'
        }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to include('Unknown action_type')
      end
    end

    context 'with mixed results' do
      before do
        call_count = 0
        allow(PrefabControlService).to receive(:set_characteristic) do |**args|
          call_count += 1
          if call_count == 1
            { success: true }
          else
            { success: false, error: 'Device offline' }
          end
        end
      end

      it 'returns mixed results' do
        post :batch_control, params: {
          accessory_ids: [ light1.uuid, light2.uuid ],
          action_type: 'turn_on'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['total']).to eq(2)
        expect(json['succeeded']).to eq(1)
        expect(json['failed']).to eq(1)
      end
    end

    context 'with non-writable characteristic' do
      let(:sensor_accessory) { create(:accessory, room: room, name: 'Sensor', uuid: 'sensor-1') }

      before do
        create(:sensor, accessory: sensor_accessory, characteristic_type: 'Temperature', is_writable: false)
      end

      it 'returns error for non-writable accessory' do
        post :batch_control, params: {
          accessory_ids: [ sensor_accessory.uuid ],
          action_type: 'turn_on'
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['failed']).to eq(1)
        expect(json['results'].first['error']).to eq('Characteristic not writable')
      end
    end

    context 'with different action types' do
      let(:dimmable_light) { create(:accessory, room: room, name: 'Dimmable Light', uuid: 'dim-light-1') }
      let(:thermostat) { create(:accessory, room: room, name: 'Thermostat', uuid: 'thermo-1') }

      before do
        create(:sensor, accessory: dimmable_light, characteristic_type: 'Brightness', is_writable: true)
        create(:sensor, accessory: thermostat, characteristic_type: 'Target Temperature', is_writable: true)
        allow(PrefabControlService).to receive(:set_characteristic).and_return({ success: true })
      end

      it 'handles turn_off action' do
        post :batch_control, params: {
          accessory_ids: [ light1.uuid ],
          action_type: 'turn_off'
        }

        expect(PrefabControlService).to have_received(:set_characteristic).with(
          hash_including(characteristic: 'On', value: false)
        )
      end

      it 'handles set_brightness action' do
        post :batch_control, params: {
          accessory_ids: [ dimmable_light.uuid ],
          action_type: 'set_brightness',
          value: 75
        }

        expect(PrefabControlService).to have_received(:set_characteristic).with(
          hash_including(characteristic: 'Brightness', value: 75)
        )
      end

      it 'handles set_temperature action' do
        post :batch_control, params: {
          accessory_ids: [ thermostat.uuid ],
          action_type: 'set_temperature',
          value: 22.5
        }

        expect(PrefabControlService).to have_received(:set_characteristic).with(
          hash_including(characteristic: 'Target Temperature', value: 22.5)
        )
      end
    end
  end
end
