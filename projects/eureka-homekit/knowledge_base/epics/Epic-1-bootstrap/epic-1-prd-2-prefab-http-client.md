# PRD 1.2: Prefab HTTP Client Service

## Epic
Epic 1: Initial Rails Server Setup with Prefab Integration

## Objective
Build a service class to query Prefab's REST API at `http://localhost:8080`.

## Requirements

### Service Class: `PrefabClient`
Location: `app/services/prefab_client.rb`

#### Methods
1. **`homes`**
   - GET `/homes`
   - Returns array of home objects

2. **`rooms(home_name_or_uuid)`**
   - GET `/rooms/:home`
   - Returns array of room objects for a home

3. **`accessories(home, room)`**
   - GET `/accessories/:home/:room`
   - Returns array of accessory objects with characteristics

4. **`accessory_details(home, room, accessory)`**
   - GET `/accessories/:home/:room/:accessory`
   - Returns single accessory with full details

5. **`scenes(home_name_or_uuid)`**
   - GET `/scenes/:home`
   - Returns array of scene objects for a home

#### Configuration
- Base URL: `http://localhost:8080`
- Configurable via ENV var: `PREFAB_API_URL`
- Timeout: 5 seconds
- Use HTTParty or Faraday

#### Error Handling
- Rescue connection errors
- Log failed requests
- Return `nil` or empty array on failure
- Raise custom `PrefabClient::ConnectionError` for critical failures

## Implementation Example

```ruby
class PrefabClient
  include HTTParty
  base_uri ENV.fetch('PREFAB_API_URL', 'http://localhost:8080')
  default_timeout 5

  class ConnectionError < StandardError; end

  def self.homes
    response = get('/homes')
    response.success? ? response.parsed_response : []
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    []
  end

  def self.rooms(home)
    response = get("/rooms/#{ERB::Util.url_encode(home)}")
    response.success? ? response.parsed_response : []
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    []
  end

  def self.accessories(home, room)
    response = get("/accessories/#{ERB::Util.url_encode(home)}/#{ERB::Util.url_encode(room)}")
    response.success? ? response.parsed_response : []
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    []
  end

  def self.accessory_details(home, room, accessory)
    response = get("/accessories/#{ERB::Util.url_encode(home)}/#{ERB::Util.url_encode(room)}/#{ERB::Util.url_encode(accessory)}")
    response.success? ? response.parsed_response : nil
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    nil
  end

  def self.scenes(home)
    response = get("/scenes/#{ERB::Util.url_encode(home)}")
    response.success? ? response.parsed_response : []
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    []
  end
end
```

## Dependencies
Add to Gemfile:
```ruby
gem 'httparty'
```

## Success Criteria
- ✅ Can fetch homes from Prefab
- ✅ Can fetch rooms for a home
- ✅ Can fetch accessories for a room
- ✅ Can fetch scenes for a home
- ✅ Handles connection errors gracefully
- ✅ URL-encodes parameters correctly

## Testing

### RSpec Test Cases

**spec/services/prefab_client_spec.rb**
```ruby
require 'rails_helper'
require 'webmock/rspec'

RSpec.describe PrefabClient do
  let(:base_url) { 'http://localhost:8080' }

  before do
    stub_const('ENV', ENV.to_hash.merge('PREFAB_API_URL' => base_url))
  end

  describe '.homes' do
    context 'when request is successful' do
      it 'returns array of homes' do
        homes_data = [
          { 'name' => 'Main House', 'uuid' => 'home-1' },
          { 'name' => 'Cottage', 'uuid' => 'home-2' }
        ]

        stub_request(:get, "#{base_url}/homes")
          .to_return(status: 200, body: homes_data.to_json, headers: { 'Content-Type' => 'application/json' })

        result = described_class.homes

        expect(result).to eq(homes_data)
      end
    end

    context 'when request fails' do
      it 'returns empty array on connection error' do
        stub_request(:get, "#{base_url}/homes")
          .to_raise(Errno::ECONNREFUSED)

        expect(Rails.logger).to receive(:error).with(/PrefabClient error/)
        result = described_class.homes

        expect(result).to eq([])
      end

      it 'returns empty array on timeout' do
        stub_request(:get, "#{base_url}/homes")
          .to_timeout

        expect(Rails.logger).to receive(:error).with(/PrefabClient error/)
        result = described_class.homes

        expect(result).to eq([])
      end

      it 'returns empty array on non-200 status' do
        stub_request(:get, "#{base_url}/homes")
          .to_return(status: 500, body: 'Internal Server Error')

        result = described_class.homes

        expect(result).to eq([])
      end
    end
  end

  describe '.rooms' do
    context 'with simple home name' do
      it 'returns array of rooms' do
        rooms_data = [
          { 'name' => 'Living Room', 'uuid' => 'room-1' },
          { 'name' => 'Bedroom', 'uuid' => 'room-2' }
        ]

        stub_request(:get, "#{base_url}/rooms/Main%20House")
          .to_return(status: 200, body: rooms_data.to_json, headers: { 'Content-Type' => 'application/json' })

        result = described_class.rooms('Main House')

        expect(result).to eq(rooms_data)
      end
    end

    context 'with special characters in home name' do
      it 'URL-encodes the home parameter' do
        stub_request(:get, "#{base_url}/rooms/Mom%27s%20House")
          .to_return(status: 200, body: [].to_json)

        described_class.rooms("Mom's House")

        expect(WebMock).to have_requested(:get, "#{base_url}/rooms/Mom%27s%20House")
      end
    end

    context 'when request fails' do
      it 'returns empty array on error' do
        stub_request(:get, "#{base_url}/rooms/Main%20House")
          .to_raise(StandardError.new('Connection failed'))

        expect(Rails.logger).to receive(:error).with(/PrefabClient error/)
        result = described_class.rooms('Main House')

        expect(result).to eq([])
      end
    end
  end

  describe '.accessories' do
    context 'when request is successful' do
      it 'returns array of accessories' do
        accessories_data = [
          { 'name' => 'Light', 'uuid' => 'acc-1', 'characteristics' => { 'power' => true } },
          { 'name' => 'Thermostat', 'uuid' => 'acc-2', 'characteristics' => { 'temp' => 72 } }
        ]

        stub_request(:get, "#{base_url}/accessories/Main%20House/Living%20Room")
          .to_return(status: 200, body: accessories_data.to_json, headers: { 'Content-Type' => 'application/json' })

        result = described_class.accessories('Main House', 'Living Room')

        expect(result).to eq(accessories_data)
      end
    end

    context 'with special characters' do
      it 'URL-encodes both home and room parameters' do
        stub_request(:get, "#{base_url}/accessories/Mom%27s%20House/Kid%27s%20Room")
          .to_return(status: 200, body: [].to_json)

        described_class.accessories("Mom's House", "Kid's Room")

        expect(WebMock).to have_requested(:get, "#{base_url}/accessories/Mom%27s%20House/Kid%27s%20Room")
      end
    end

    context 'when request fails' do
      it 'returns empty array on error' do
        stub_request(:get, "#{base_url}/accessories/Main%20House/Living%20Room")
          .to_raise(StandardError.new('Connection failed'))

        expect(Rails.logger).to receive(:error).with(/PrefabClient error/)
        result = described_class.accessories('Main House', 'Living Room')

        expect(result).to eq([])
      end
    end
  end

  describe '.accessory_details' do
    context 'when request is successful' do
      it 'returns accessory details' do
        accessory_data = {
          'name' => 'Front Door Lock',
          'uuid' => 'acc-1',
          'characteristics' => {
            'Lock Current State' => 1,
            'Lock Target State' => 1
          }
        }

        stub_request(:get, "#{base_url}/accessories/Main%20House/Entryway/Front%20Door%20Lock")
          .to_return(status: 200, body: accessory_data.to_json, headers: { 'Content-Type' => 'application/json' })

        result = described_class.accessory_details('Main House', 'Entryway', 'Front Door Lock')

        expect(result).to eq(accessory_data)
      end
    end

    context 'when accessory not found' do
      it 'returns nil' do
        stub_request(:get, "#{base_url}/accessories/Main%20House/Living%20Room/NonExistent")
          .to_return(status: 404, body: 'Not Found')

        result = described_class.accessory_details('Main House', 'Living Room', 'NonExistent')

        expect(result).to be_nil
      end
    end

    context 'when request fails' do
      it 'returns nil on error' do
        stub_request(:get, "#{base_url}/accessories/Main%20House/Living%20Room/Light")
          .to_raise(StandardError.new('Connection failed'))

        expect(Rails.logger).to receive(:error).with(/PrefabClient error/)
        result = described_class.accessory_details('Main House', 'Living Room', 'Light')

        expect(result).to be_nil
      end
    end
  end

  describe '.scenes' do
    context 'when request is successful' do
      it 'returns array of scenes' do
        scenes_data = [
          { 'name' => 'Good Night', 'uuid' => 'scene-1' },
          { 'name' => 'Movie Time', 'uuid' => 'scene-2' }
        ]

        stub_request(:get, "#{base_url}/scenes/Main%20House")
          .to_return(status: 200, body: scenes_data.to_json, headers: { 'Content-Type' => 'application/json' })

        result = described_class.scenes('Main House')

        expect(result).to eq(scenes_data)
      end
    end

    context 'when request fails' do
      it 'returns empty array on error' do
        stub_request(:get, "#{base_url}/scenes/Main%20House")
          .to_raise(StandardError.new('Connection failed'))

        expect(Rails.logger).to receive(:error).with(/PrefabClient error/)
        result = described_class.scenes('Main House')

        expect(result).to eq([])
      end
    end
  end

  describe 'configuration' do
    it 'uses default base URL when ENV var not set' do
      stub_const('ENV', ENV.to_hash.except('PREFAB_API_URL'))

      # HTTParty will use the base_uri set in the class
      expect(described_class.base_uri).to eq('http://localhost:8080')
    end

    it 'respects custom PREFAB_API_URL from ENV' do
      custom_url = 'http://custom:9000'
      stub_const('ENV', ENV.to_hash.merge('PREFAB_API_URL' => custom_url))

      stub_request(:get, "#{custom_url}/homes")
        .to_return(status: 200, body: [].to_json)

      # Need to reload the class to pick up new ENV
      load 'app/services/prefab_client.rb'
      described_class.homes

      expect(WebMock).to have_requested(:get, "#{custom_url}/homes")
    end
  end

  describe 'timeout configuration' do
    it 'has 5 second timeout' do
      expect(described_class.default_options[:timeout]).to eq(5)
    end
  end
end
```

### Additional Test Setup

**Gemfile additions for testing**
```ruby
group :test do
  gem 'webmock'
  gem 'rspec-rails'
end
```

### Test Coverage Goals
- ✅ All HTTP methods tested
- ✅ Success cases covered
- ✅ Error handling verified
- ✅ URL encoding tested
- ✅ Timeout behavior tested
- ✅ Custom configuration tested
- ✅ Logging behavior verified

---
**Status**: Ready
**Depends On**: None
**Blocks**: PRD 1.3
