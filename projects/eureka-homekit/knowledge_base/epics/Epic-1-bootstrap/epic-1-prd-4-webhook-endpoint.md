# PRD 1.4: Webhook Endpoint for Prefab Events

## Epic
Epic 1: Initial Rails Server Setup with Prefab Integration

## Objective
Create API endpoint to receive real-time HomeKit events from Prefab.

## Requirements

### Endpoint
**POST** `/api/homekit/events`

### Controller
Location: `app/controllers/api/homekit_events_controller.rb`

Namespace: `Api::HomekitEventsController`

#### Features
1. Accept JSON payload
2. Validate `Authorization: Bearer <token>` header
3. Parse event data
4. Create `HomekitEvent` record
5. Return 200 OK or appropriate error

### Authentication
- Token stored in Rails credentials: `Rails.application.credentials.prefab_webhook_token`
- Expected header: `Authorization: Bearer sk_live_eureka_abc123xyz789`
- Return 401 Unauthorized if missing/invalid

### Payload Examples

**Characteristic Updated**:
```json
{
  "type": "characteristic_updated",
  "accessory": "Front Door",
  "characteristic": "Lock Current State",
  "value": 1,
  "timestamp": "2026-01-25T15:12:34Z"
}
```

**Homes Updated**:
```json
{
  "type": "homes_updated",
  "home_count": 2,
  "timestamp": "2026-01-25T15:12:34Z"
}
```

## Implementation

### Routes
`config/routes.rb`:
```ruby
namespace :api do
  post 'homekit/events', to: 'homekit_events#create'
end
```

### Controller
```ruby
module Api
  class HomekitEventsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_webhook

    def create
      event = HomekitEvent.create!(
        event_type: params[:type],
        accessory_name: params[:accessory],
        characteristic: params[:characteristic],
        value: params[:value],
        raw_payload: request.body.read,
        timestamp: params[:timestamp] || Time.current
      )

      Rails.logger.info("HomeKit event received: #{event.event_type} - #{event.accessory_name}")

      head :ok
    rescue StandardError => e
      Rails.logger.error("Failed to process HomeKit event: #{e.message}")
      render json: { error: 'Bad request' }, status: :bad_request
    end

    private

    def authenticate_webhook
      token = request.headers['Authorization']&.remove('Bearer ')
      expected_token = Rails.application.credentials.prefab_webhook_token

      unless token == expected_token
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end
    end
  end
end
```

### Credentials Setup
```bash
rails credentials:edit
```

Add:
```yaml
prefab_webhook_token: sk_live_eureka_abc123xyz789
```

## CSRF Protection
Skip CSRF for API endpoints in `ApplicationController`:
```ruby
protect_from_forgery with: :exception, unless: -> { request.format.json? }
```

Or in the controller:
```ruby
skip_before_action :verify_authenticity_token
```

## Success Criteria
- ✅ Endpoint accepts POST requests
- ✅ Auth token validated
- ✅ Events stored in database
- ✅ Returns appropriate HTTP status codes
- ✅ Logs events for debugging

## Testing

### RSpec Test Cases

**spec/requests/api/homekit_events_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe 'Api::HomekitEvents', type: :request do
  let(:valid_token) { 'sk_live_eureka_abc123xyz789' }
  let(:invalid_token) { 'invalid_token' }

  let(:valid_payload) do
    {
      type: 'characteristic_updated',
      accessory: 'Front Door',
      characteristic: 'Lock Current State',
      value: 1,
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
        expect(event.event_type).to eq('characteristic_updated')
        expect(event.accessory_name).to eq('Front Door')
        expect(event.characteristic).to eq('Lock Current State')
        expect(event.value).to eq(1)
        expect(event.timestamp).to be_present
      end

      it 'logs the event' do
        expect(Rails.logger).to receive(:info).with(
          /HomeKit event received: characteristic_updated - Front Door/
        )

        post '/api/homekit/events', params: valid_payload.to_json, headers: valid_headers
      end

      it 'uses current time if timestamp not provided' do
        payload = valid_payload.except(:timestamp)
        freeze_time = Time.current

        travel_to freeze_time do
          post '/api/homekit/events', params: payload.to_json, headers: valid_headers
        end

        event = HomekitEvent.last
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
        expect(Rails.logger).to receive(:error).with(/Failed to process HomeKit event/)

        post '/api/homekit/events', params: 'invalid json', headers: valid_headers
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
        allow(HomekitEvent).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
        expect(Rails.logger).to receive(:error).with(/Failed to process HomeKit event/)

        post '/api/homekit/events', params: valid_payload.to_json, headers: valid_headers

        expect(response).to have_http_status(:bad_request)
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
```

**spec/controllers/api/homekit_events_controller_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe Api::HomekitEventsController, type: :controller do
  let(:valid_token) { 'sk_live_eureka_abc123xyz789' }

  before do
    allow(Rails.application.credentials).to receive(:prefab_webhook_token).and_return(valid_token)
  end

  describe 'authentication' do
    it 'extracts token from Authorization header' do
      request.headers['Authorization'] = "Bearer #{valid_token}"

      post :create, params: {
        type: 'test',
        timestamp: Time.current
      }, format: :json

      expect(response).to have_http_status(:ok)
    end

    it 'handles Authorization header without Bearer prefix' do
      request.headers['Authorization'] = valid_token

      post :create, params: {
        type: 'test',
        timestamp: Time.current
      }, format: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

**spec/routing/api/homekit_events_routing_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe 'API routing', type: :routing do
  it 'routes POST /api/homekit/events to api/homekit_events#create' do
    expect(post: '/api/homekit/events').to route_to(
      controller: 'api/homekit_events',
      action: 'create'
    )
  end
end
```

### Manual Test
```bash
curl -X POST http://localhost:3000/api/homekit/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk_live_eureka_abc123xyz789" \
  -d '{
    "type": "characteristic_updated",
    "accessory": "Front Door",
    "characteristic": "Lock Current State",
    "value": 1,
    "timestamp": "2026-01-25T15:12:34Z"
  }'
```

### Test Coverage Goals
- ✅ Successful event creation
- ✅ Authentication validation
- ✅ Missing auth header (401)
- ✅ Invalid auth token (401)
- ✅ Malformed JSON (400)
- ✅ Missing required fields (400)
- ✅ Database errors handled
- ✅ CSRF protection bypassed for API
- ✅ Event logging verified
- ✅ Routing tested

---
**Status**: Ready
**Depends On**: PRD 1.1
**Blocks**: None
