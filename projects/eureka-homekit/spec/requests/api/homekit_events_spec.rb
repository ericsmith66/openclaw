require 'rails_helper'

RSpec.describe 'Api::HomekitEvents', type: :request do
  include ActiveSupport::Testing::TimeHelpers
  let(:valid_token) { 'sk_live_eureka_abc123xyz789' }
  let(:invalid_token) { 'invalid_token' }

    let(:valid_payload) do
      {
        type: 'characteristic_updated',
        accessory: 'Front Door',
        characteristic: 'Unique Characteristic', # New name
        value: 123,
        timestamp: '2026-01-25T15:12:34Z'
      }
    end

  let(:valid_headers) do
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{valid_token}"
    }
  end

  before do
    # Mock Rails credentials
    allow(Rails.application.credentials).to receive(:prefab_webhook_token).and_return(valid_token)

    # Create accessory for sensor tests
    home = Home.create!(name: 'Test Home', uuid: 'home-abc')
    room = Room.create!(name: 'Test Room', uuid: 'room-abc', home: home)
    Accessory.create!(
      name: 'Front Door',
      uuid: 'acc-front-door',
      room: room,
      raw_data: {
        'services' => [
          {
            'typeName' => 'Lock Mechanism',
            'uniqueIdentifier' => 'svc-lock',
            'characteristics' => [
              {
                'typeName' => 'Lock Current State',
                'uniqueIdentifier' => 'char-lock-state',
                'properties' => [ 'HMCharacteristicPropertySupportsEventNotification' ],
                'metadata' => { 'format' => 'int' }
              },
              {
                'typeName' => 'Current Temperature',
                'uniqueIdentifier' => 'char-temp',
                'properties' => [ 'HMCharacteristicPropertySupportsEventNotification' ],
                'metadata' => { 'format' => 'float' }
              }
            ]
          },
          {
            'typeName' => 'TemperatureSensor',
            'uniqueIdentifier' => 'svc-temp',
            'characteristics' => [
              {
                'typeName' => 'Current Temperature',
                'uniqueIdentifier' => 'char-temp-actual',
                'properties' => [ 'HMCharacteristicPropertySupportsEventNotification' ],
                'metadata' => { 'format' => 'float' }
              }
            ]
          }
        ]
      }
    )
  end

  describe 'POST /api/homekit/events' do
    context 'with valid authentication and payload' do
      it 'creates a homekit event' do
        expect {
          post '/api/homekit/events', params: valid_payload.to_json, headers: valid_headers
        }.to change(HomekitEvent, :count).by(1)

        expect(response).to have_http_status(:ok)
      end

      it 'stores event with correct attributes' do
        post '/api/homekit/events', params: valid_payload.to_json, headers: valid_headers

        event = HomekitEvent.last
        expect(event).to be_present
        expect(event.event_type).to eq('characteristic_updated')
        expect(event.accessory_name).to eq('Front Door')
        expect(event.characteristic).to eq('Unique Characteristic')
        expect(event.value.to_i).to eq(123)
        expect(event.timestamp).to be_present
      end

      it 'logs the event' do
        allow(Rails.logger).to receive(:info)

        post '/api/homekit/events', params: valid_payload.to_json, headers: valid_headers

        expect(Rails.logger).to have_received(:info).with(
          "HomeKit event received: characteristic_updated - Front Door"
        ).at_least(:once)
        expect(Rails.logger).to have_received(:info).with(
          "HomeKit event stored: Front Door - Unique Characteristic = 123"
        ).at_least(:once)
      end

      it 'uses current time if timestamp not provided' do
        payload = valid_payload.except(:timestamp)
        freeze_time = Time.parse('2026-01-25T15:12:34Z')

        # We need to make sure duplication logic doesn't skip it
        # Let's use a unique accessory name for this specific test
        payload[:accessory] = 'Unique Sensor'
        Accessory.create!(
          name: 'Unique Sensor',
          uuid: 'acc-unique',
          room: Room.last,
          raw_data: { 'services' => [] }
        )

        travel_to freeze_time do
          post '/api/homekit/events', params: payload.to_json, headers: valid_headers
        end

        event = HomekitEvent.find_by(accessory_name: 'Unique Sensor')
        expect(event).to be_present
        expect(event.timestamp).to be_within(1.second).of(freeze_time)
      end
    end

    context 'with homes_updated event type' do
      let(:homes_payload) do
        {
          type: 'homes_updated',
          home_count: 2,
          timestamp: '2026-01-25T15:12:34Z'
        }
      end

      it 'creates event without accessory name' do
        expect {
          post '/api/homekit/events', params: homes_payload.to_json, headers: valid_headers
        }.to change(HomekitEvent, :count).by(1)

        event = HomekitEvent.last
        expect(event.event_type).to eq('homes_updated')
        expect(event.accessory_name).to be_nil
      end
    end

    context 'with missing authorization header' do
      it 'returns 401 unauthorized' do
        headers = valid_headers.except('Authorization')

        post '/api/homekit/events', params: valid_payload.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Unauthorized' })
      end

      it 'does not create an event' do
        headers = valid_headers.except('Authorization')

        expect {
          post '/api/homekit/events', params: valid_payload.to_json, headers: headers
        }.not_to change(HomekitEvent, :count)
      end
    end

    context 'with invalid authorization token' do
      it 'returns 401 unauthorized' do
        headers = valid_headers.merge('Authorization' => "Bearer #{invalid_token}")

        post '/api/homekit/events', params: valid_payload.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Unauthorized' })
      end

      it 'does not create an event' do
        headers = valid_headers.merge('Authorization' => "Bearer #{invalid_token}")

        expect {
          post '/api/homekit/events', params: valid_payload.to_json, headers: headers
        }.not_to change(HomekitEvent, :count)
      end
    end

    context 'with malformed JSON' do
      it 'returns 400 bad request' do
        headers = valid_headers

        post '/api/homekit/events', params: 'invalid json', headers: headers

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to have_key('error')
      end

      it 'logs the error' do
        allow(Rails.logger).to receive(:error)

        post '/api/homekit/events', params: 'invalid json', headers: valid_headers

        expect(Rails.logger).to have_received(:error).with(/Failed to process HomeKit event/)
      end
    end

    context 'with missing required fields' do
      it 'returns 400 bad request when type is missing' do
        payload = valid_payload.except(:type)

        post '/api/homekit/events', params: payload.to_json, headers: valid_headers

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with database error' do
      it 'returns 400 and logs error' do
        # Use a new value to ensure it's not deduplicated before create! is called
        payload = valid_payload.merge(value: 99.9)
        allow(HomekitEvent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
        allow(Rails.logger).to receive(:error)

        post '/api/homekit/events', params: payload.to_json, headers: valid_headers

        expect(response).to have_http_status(:bad_request)
        expect(Rails.logger).to have_received(:error).with(/Failed to process HomeKit event/)
      end
    end

    context 'CSRF protection' do
      it 'does not require CSRF token for API endpoint' do
        # This test ensures skip_before_action :verify_authenticity_token is working
        post '/api/homekit/events', params: valid_payload.to_json, headers: valid_headers

        expect(response).to have_http_status(:ok)
        # If CSRF was enforced, this would return 422 Unprocessable Entity
      end
    end
  end
end
