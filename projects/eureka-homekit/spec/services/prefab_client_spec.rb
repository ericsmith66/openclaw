require 'rails_helper'

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

        allow(described_class).to receive(:execute_curl).and_return([ homes_data.to_json, true, 100, 0 ])

        result = described_class.homes

        expect(result).to eq(homes_data)
      end
    end

    context 'when request fails' do
      it 'returns empty array on connection error' do
        allow(described_class).to receive(:execute_curl).and_return([ '', false, 0, 7 ])

        result = described_class.homes

        expect(result).to eq([])
      end

      it 'returns empty array on timeout' do
        allow(described_class).to receive(:execute_curl).and_return([ '', false, 5000, 28 ])

        result = described_class.homes

        expect(result).to eq([])
      end

      it 'retries once on timeout and returns data if retry succeeds' do
        homes_data = [
          { 'name' => 'Main House', 'uuid' => 'home-1' },
          { 'name' => 'Cottage', 'uuid' => 'home-2' }
        ]

        allow(described_class).to receive(:execute_curl_base).and_return(
          [ '', false, 15000, 28 ],
          [ homes_data.to_json, true, 100, 0 ]
        )

        result = described_class.homes

        expect(result).to eq(homes_data)
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

        allow(described_class).to receive(:execute_curl).and_return([ rooms_data.to_json, true, 50, 0 ])

        result = described_class.rooms('Main House')

        expect(result).to eq(rooms_data)
      end
    end

    context 'with special characters in home name' do
      it 'URL-encodes the home parameter' do
        allow(described_class).to receive(:execute_curl) do |url|
          expect(url).to include("Mom%27s%20House")
          [ [].to_json, true, 0, 0 ]
        end

        described_class.rooms("Mom's House")
      end
    end

    context 'when request fails' do
      it 'returns empty array on error' do
        allow(described_class).to receive(:execute_curl).and_return([ '', false, 0, 1 ])

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

        allow(described_class).to receive(:execute_curl).and_return([ accessories_data.to_json, true, 75, 0 ])

        result = described_class.accessories('Main House', 'Living Room')

        expect(result).to eq(accessories_data)
      end
    end

    context 'with special characters' do
      it 'URL-encodes both home and room parameters' do
        allow(described_class).to receive(:execute_curl) do |url|
          expect(url).to include("Mom%27s%20House")
          expect(url).to include("Kid%27s%20Room")
          [ [].to_json, true, 0, 0 ]
        end

        described_class.accessories("Mom's House", "Kid's Room")
      end
    end

    context 'when request fails' do
      it 'returns empty array on error' do
        allow(described_class).to receive(:execute_curl).and_return([ '', false, 0, 1 ])

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

        allow(described_class).to receive(:execute_curl).and_return([ accessory_data.to_json, true, 100, 0 ])

        result = described_class.accessory_details('Main House', 'Entryway', 'Front Door Lock')

        expect(result).to eq(accessory_data)
      end
    end

    context 'when accessory not found' do
      it 'returns nil' do
        allow(described_class).to receive(:execute_curl).and_return([ '', false, 0, 1 ])

        result = described_class.accessory_details('Main House', 'Living Room', 'NonExistent')

        expect(result).to be_nil
      end
    end

    context 'when request fails' do
      it 'returns nil on error' do
        allow(described_class).to receive(:execute_curl).and_return([ '', false, 0, 1 ])

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

        allow(described_class).to receive(:execute_curl).and_return([ scenes_data.to_json, true, 60, 0 ])

        result = described_class.scenes('Main House')

        expect(result).to eq(scenes_data)
      end
    end

    context 'when request fails' do
      it 'returns empty array on error' do
        allow(described_class).to receive(:execute_curl).and_return([ '', false, 0, 1 ])

        result = described_class.scenes('Main House')

        expect(result).to eq([])
      end
    end
  end

  describe 'configuration' do
    it 'uses default base URL when ENV var not set' do
      allow(ENV).to receive(:fetch).with('PREFAB_API_URL', 'http://localhost:8080').and_return('http://localhost:8080')

      expect(PrefabClient::BASE_URL).to eq('http://localhost:8080')
    end

    it 'uses default 5 second timeout when ENV var not set' do
      expect(PrefabClient::WRITE_TIMEOUT).to eq(5000)
    end
  end

  describe 'write operations' do
    let(:home) { 'Main House' }
    let(:room) { 'Living Room' }
    let(:accessory) { 'Light 1' }
    let(:service_id) { 'svc-123' }
    let(:characteristic_id) { 'char-456' }
    let(:value) { true }

    before do
      stub_const('ENV', ENV.to_hash.merge('PREFAB_API_URL' => base_url))
    end

    describe '.update_characteristic' do
      context 'when successful' do
        it 'returns success response with latency' do
          allow(described_class).to receive(:execute_curl_put).and_return([ '{}', true, 150, 0 ])

          result = described_class.update_characteristic(home, room, accessory, service_id, characteristic_id, value)

          expect(result[:success]).to be true
          expect(result[:latency_ms]).to eq(150)
          expect(result[:value]).to be true
        end
      end

      context 'when failed' do
        it 'returns error with latency' do
          allow(described_class).to receive(:execute_curl_put).and_return([ 'Device offline', false, 200, 22 ])

          result = described_class.update_characteristic(home, room, accessory, service_id, characteristic_id, value)

          expect(result[:success]).to be false
          expect(result[:error]).to eq('Device offline')
          expect(result[:latency_ms]).to eq(200)
          expect(result[:exit_status]).to eq(22)
        end
      end

      it 'URL-encodes parameters' do
        allow(described_class).to receive(:execute_curl_put) do |url, payload|
          expect(url).to include("Mom%27s%20House")
          expect(url).to include("Kid%27s%20Room")
          expect(url).to include("Light%201")
          expect(url).not_to include("On")

          parsed_payload = JSON.parse(payload)
          expect(parsed_payload).to include(
            "serviceId" => service_id,
            "characteristicId" => characteristic_id,
            "value" => "true"
          )

          [ {}, true, 100, 0 ]
        end

        described_class.update_characteristic("Mom's House", "Kid's Room", 'Light 1', service_id, characteristic_id, value)
      end

      it 'logs success to Rails.logger' do
        logger = double('logger')
        expect(logger).to receive(:info).with(/update_characteristic success/)

        allow(Rails).to receive(:logger).and_return(logger)
        allow(described_class).to receive(:execute_curl_put).and_return([ '{}', true, 100, 0 ])

        described_class.update_characteristic(home, room, accessory, service_id, characteristic_id, value)
      end
    end

    describe '.execute_scene' do
      let(:scene_uuid) { 'scene-123' }

      context 'when successful' do
        it 'returns success response with latency' do
          allow(described_class).to receive(:execute_curl_post).and_return([ '{}', true, 200, 0 ])

          result = described_class.execute_scene(home, scene_uuid)

          expect(result[:success]).to be true
          expect(result[:latency_ms]).to eq(200)
        end
      end

      context 'when scene not found' do
        it 'returns error with latency' do
          allow(described_class).to receive(:execute_curl_post).and_return([ 'Scene not found', false, 180, 404 ])

          result = described_class.execute_scene(home, scene_uuid)

          expect(result[:success]).to be false
          expect(result[:error]).to eq('Scene not found')
        end
      end

      it 'URL-encodes parameters' do
        allow(described_class).to receive(:execute_curl_post) do |url|
          expect(url).to include("Mom%27s%20House")
          expect(url).to include("scene-123")
          [ {}, true, 100, 0 ]
        end

        described_class.execute_scene("Mom's House", scene_uuid)
      end

      it 'logs success to Rails.logger' do
        logger = double('logger')
        expect(logger).to receive(:info).with(/execute_scene success/)

        allow(Rails).to receive(:logger).and_return(logger)
        allow(described_class).to receive(:execute_curl_post).and_return([ '{}', true, 100, 0 ])

        described_class.execute_scene(home, scene_uuid)
      end
    end
  end
end
