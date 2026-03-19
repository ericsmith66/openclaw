require 'rails_helper'

RSpec.describe HomekitSync do
  let(:service) { described_class.new }

  before do
    # Stub PrefabClient to return predictable data
    allow(PrefabClient).to receive(:homes).and_return([])
    allow(PrefabClient).to receive(:rooms).and_return([])
    allow(PrefabClient).to receive(:accessories).and_return([])
    allow(PrefabClient).to receive(:scenes).and_return([])
  end

  describe '.perform' do
    it 'creates a new instance and calls perform' do
      expect_any_instance_of(described_class).to receive(:perform)
      described_class.perform
    end
  end

  describe '#perform' do
    context 'with no homes' do
      it 'returns empty summary' do
        summary = service.perform

        expect(summary).to include(
          homes: 0,
          rooms: 0,
          accessories: 0,
          scenes: 0,
          deleted: 0,
          sync_skipped: true,
          sync_reason: "no homes returned from Prefab"
        )
      end

      it 'skips cleanup when Prefab returns no homes' do
        home = Home.create!(name: "Existing Home", uuid: "home-xyz")
        Floorplan.create!(home: home, name: "First Floor", level: 1)

        summary = service.perform(cleanup: true)

        expect(summary[:sync_skipped]).to be true
        expect(summary[:sync_reason]).to eq("no homes returned from Prefab")
        expect(summary[:cleanup_skipped]).to be true
        expect(summary[:cleanup_reason]).to eq("no homes returned from Prefab")
        expect(summary[:deleted]).to eq(0)
        expect(Home.count).to eq(1)
        expect(Floorplan.count).to eq(1)
      end

      it 'retries fetching homes before skipping sync' do
        allow(PrefabClient).to receive(:homes).and_return([], [ { 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' } ])
        allow(PrefabClient).to receive(:rooms).and_return([])
        allow(PrefabClient).to receive(:accessories).and_return([])
        allow(PrefabClient).to receive(:scenes).and_return([])

        summary = service.perform

        expect(summary[:sync_skipped]).to be_nil
        expect(summary[:sync_retried]).to be true
        expect(Home.count).to eq(1)
      end
    end

    context 'when Prefab UUID changes for an existing home' do
      let!(:home) { Home.create!(name: "Main House", uuid: "home-old") }
      let!(:floorplan) { Floorplan.create!(home: home, name: "First Floor", level: 1) }

      before do
        allow(PrefabClient).to receive(:homes).and_return([
          { "name" => "Main House", "uuid" => "home-new", "id" => "hk-1" }
        ])
        allow(PrefabClient).to receive(:rooms).and_return([])
        allow(PrefabClient).to receive(:accessories).and_return([])
        allow(PrefabClient).to receive(:scenes).and_return([])
      end

      it 'reuses the existing home and preserves floorplans' do
        expect { service.perform }.not_to change(Home, :count)
        expect(Home.first.uuid).to eq("home-new")
        expect(Floorplan.count).to eq(1)
        expect(Floorplan.first.home_id).to eq(Home.first.id)
      end
    end

    context 'when cleanup targets a home with floorplans' do
      let!(:stale_home) { Home.create!(name: "Stale Home", uuid: "stale-home") }
      let!(:floorplan) { Floorplan.create!(home: stale_home, name: "First Floor", level: 1) }

      before do
        allow(PrefabClient).to receive(:homes).and_return([
          { "name" => "Main House", "uuid" => "home-1", "id" => "hk-1" }
        ])
        allow(PrefabClient).to receive(:rooms).and_return([])
        allow(PrefabClient).to receive(:accessories).and_return([])
        allow(PrefabClient).to receive(:scenes).and_return([])
      end

      it 'does not delete the home with floorplans' do
        service.perform(cleanup: true)

        expect(Home.find_by(uuid: "stale-home")).to be_present
        expect(Floorplan.find_by(home: stale_home)).to be_present
      end
    end

    context 'with complete home structure' do
      let(:homes_data) do
        [ { 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' } ]
      end

      let(:rooms_data) do
        [ { 'name' => 'Living Room', 'uuid' => 'room-1' } ]
      end

      let(:accessories_data) do
        [ {
          'name' => 'Floor Lamp',
          'uuid' => 'acc-1',
          'characteristics' => { 'power' => true, 'brightness' => 80 }
        } ]
      end

      let(:scenes_data) do
        [ {
          'name' => 'Movie Time',
          'uuid' => 'scene-1',
          'accessories' => [ 'acc-1' ]
        } ]
      end

      before do
        allow(PrefabClient).to receive(:homes).and_return(homes_data)
        allow(PrefabClient).to receive(:rooms).and_return(rooms_data)
        allow(PrefabClient).to receive(:accessories).and_return(accessories_data)
        allow(PrefabClient).to receive(:scenes).and_return(scenes_data)
      end

      it 'creates all records' do
        expect { service.perform }.to change(Home, :count).by(1)
          .and change(Room, :count).by(1)
          .and change(Accessory, :count).by(1)
          .and change(Scene, :count).by(1)
      end

      it 'returns correct summary' do
        summary = service.perform

        expect(summary).to eq({
          homes: 1,
          rooms: 1,
          accessories: 1,
          scenes: 1,
          deleted: 0
        })
      end

      it 'creates home with correct attributes' do
        service.perform
        home = Home.last

        expect(home.name).to eq('Main House')
        expect(home.uuid).to eq('home-1')
        expect(home.homekit_home_id).to eq('hk-1')
      end

      it 'creates room associated with home' do
        service.perform
        home = Home.last
        room = Room.last

        expect(room.name).to eq('Living Room')
        expect(room.uuid).to eq('room-1')
        expect(room.home).to eq(home)
      end

      it 'creates accessory with characteristics' do
        service.perform
        accessory = Accessory.last

        expect(accessory.name).to eq('Floor Lamp')
        expect(accessory.uuid).to eq('acc-1')
        expect(accessory.characteristics).to eq({ 'power' => true, 'brightness' => 80 })
      end

      it 'creates scene linked to accessories' do
        service.perform
        scene = Scene.last
        accessory = Accessory.last

        expect(scene.name).to eq('Movie Time')
        expect(scene.uuid).to eq('scene-1')
        expect(scene.accessories).to include(accessory)
      end

      it 'logs progress' do
        expect(Rails.logger).to receive(:info).with('Syncing 1 homes from Prefab (cleanup: false)')
        expect(Rails.logger).to receive(:info).with(/Sync complete:/)

        service.perform
      end
    end

    context 'with multiple homes and rooms' do
      let(:homes_data) do
        [
          { 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' },
          { 'name' => 'Cottage', 'uuid' => 'home-2', 'id' => 'hk-2' }
        ]
      end

      let(:rooms_main) do
        [
          { 'name' => 'Living Room', 'uuid' => 'room-1' },
          { 'name' => 'Bedroom', 'uuid' => 'room-2' }
        ]
      end

      let(:rooms_cottage) do
        [ { 'name' => 'Studio', 'uuid' => 'room-3' } ]
      end

      before do
        allow(PrefabClient).to receive(:homes).and_return(homes_data)
        allow(PrefabClient).to receive(:rooms).with('Main House').and_return(rooms_main)
        allow(PrefabClient).to receive(:rooms).with('Cottage').and_return(rooms_cottage)
      end

      it 'creates all homes and rooms' do
        expect { service.perform }.to change(Home, :count).by(2)
          .and change(Room, :count).by(3)
      end

      it 'returns correct summary' do
        summary = service.perform

        expect(summary[:homes]).to eq(2)
        expect(summary[:rooms]).to eq(3)
      end
    end

    context 'idempotency' do
      let(:homes_data) do
        [ { 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' } ]
      end

      before do
        allow(PrefabClient).to receive(:homes).and_return(homes_data)
      end

      it 'does not create duplicates on second run' do
        service.perform
        initial_count = Home.count

        service.perform

        expect(Home.count).to eq(initial_count)
      end

      it 'updates existing records if data changed' do
        service.perform
        home = Home.first

        # Change the data returned by PrefabClient
        updated_data = [ { 'name' => 'Updated House', 'uuid' => 'home-1', 'id' => 'hk-1' } ]
        allow(PrefabClient).to receive(:homes).and_return(updated_data)

        service.perform
        home.reload

        expect(home.name).to eq('Updated House')
        expect(Home.count).to eq(1) # Still only one home
      end
    end

    context 'scene-accessory associations' do
      let(:homes_data) do
        [ { 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' } ]
      end

      let(:rooms_data) do
        [
          { 'name' => 'Living Room', 'uuid' => 'room-1' },
          { 'name' => 'Bedroom', 'uuid' => 'room-2' }
        ]
      end

      let(:living_room_accessories) do
        [ { 'name' => 'TV Light', 'uuid' => 'acc-1', 'characteristics' => {} } ]
      end

      let(:bedroom_accessories) do
        [ { 'name' => 'Bedside Lamp', 'uuid' => 'acc-2', 'characteristics' => {} } ]
      end

      let(:scenes_data) do
        [ {
          'name' => 'Good Night',
          'uuid' => 'scene-1',
          'accessories' => [ 'acc-1', 'acc-2' ] # References accessories from both rooms
        } ]
      end

      before do
        allow(PrefabClient).to receive(:homes).and_return(homes_data)
        allow(PrefabClient).to receive(:rooms).and_return(rooms_data)
        allow(PrefabClient).to receive(:accessories).with('Main House', 'Living Room').and_return(living_room_accessories)
        allow(PrefabClient).to receive(:accessories).with('Main House', 'Bedroom').and_return(bedroom_accessories)
        allow(PrefabClient).to receive(:scenes).and_return(scenes_data)
      end

      it 'links accessories from multiple rooms to scene' do
        service.perform
        scene = Scene.last

        expect(scene.accessories.count).to eq(2)
        expect(scene.accessories.pluck(:name)).to contain_exactly('TV Light', 'Bedside Lamp')
      end

      it 'clears old associations on re-sync' do
        service.perform
        scene = Scene.last

        # First sync has 2 accessories
        expect(scene.accessories.count).to eq(2)

        # Second sync with only 1 accessory
        updated_scenes = [ {
          'name' => 'Good Night',
          'uuid' => 'scene-1',
          'accessories' => [ 'acc-1' ] # Only one accessory now
        } ]
        allow(PrefabClient).to receive(:scenes).and_return(updated_scenes)

        service.perform
        scene.reload

        expect(scene.accessories.count).to eq(1)
        expect(scene.accessories.first.name).to eq('TV Light')
      end
    end

    context 'partial failures' do
      let(:homes_data) do
        [ { 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' } ]
      end

      before do
        allow(PrefabClient).to receive(:homes).and_return(homes_data)
      end

      it 'continues processing after PrefabClient error' do
        allow(PrefabClient).to receive(:rooms).and_raise(StandardError.new('API Error'))
        allow(PrefabClient).to receive(:scenes).and_return([])

        expect { service.perform }.not_to raise_error

        # Home is still created despite rooms failing
        expect(Home.count).to eq(1)
      end

      it 'handles missing characteristics gracefully' do
        rooms_data = [ { 'name' => 'Living Room', 'uuid' => 'room-1' } ]
        accessories_data = [ { 'name' => 'Light', 'uuid' => 'acc-1' } ] # No characteristics key

        allow(PrefabClient).to receive(:rooms).and_return(rooms_data)
        allow(PrefabClient).to receive(:accessories).and_return(accessories_data)

        service.perform
        accessory = Accessory.last

        expect(accessory.characteristics).to eq({})
      end

      it 'handles scene without accessories' do
        rooms_data = [ { 'name' => 'Living Room', 'uuid' => 'room-1' } ]
        scenes_data = [ { 'name' => 'Empty Scene', 'uuid' => 'scene-1' } ]

        allow(PrefabClient).to receive(:rooms).and_return(rooms_data)
        allow(PrefabClient).to receive(:accessories).and_return([])
        allow(PrefabClient).to receive(:scenes).and_return(scenes_data)

        expect { service.perform }.not_to raise_error

        scene = Scene.last
        expect(scene.accessories).to be_empty
      end
    end
  end

  describe '#extract_sensors' do
    let(:home) { Home.create!(name: 'Main House', uuid: 'home-1') }
    let(:room) { Room.create!(name: 'Living Room', uuid: 'room-1', home: home) }

    it 'includes control characteristics for writable services' do
      accessory = Accessory.create!(
        name: 'Floor Lamp',
        uuid: 'acc-1',
        room: room,
        raw_data: {
          'services' => [
            {
              'typeName' => 'Lightbulb',
              'uniqueIdentifier' => 'svc-1',
              'characteristics' => [
                {
                  'typeName' => 'On',
                  'uniqueIdentifier' => 'char-on',
                  'value' => true,
                  'properties' => [
                    'HMCharacteristicPropertyWritable',
                    'HMCharacteristicPropertySupportsEventNotification'
                  ]
                },
                {
                  'typeName' => 'Brightness',
                  'uniqueIdentifier' => 'char-bright',
                  'value' => 80,
                  'metadata' => { 'format' => 'int' },
                  'properties' => [
                    'HMCharacteristicPropertyWritable',
                    'HMCharacteristicPropertySupportsEventNotification'
                  ]
                }
              ]
            }
          ]
        }
      )

      sensors = service.extract_sensors(accessory)

      expect(sensors.map(&:characteristic_type)).to include('On', 'Brightness')
      expect(sensors.all?(&:is_writable)).to be true
    end

    it 'falls back to description when characteristic type is blank' do
      accessory = Accessory.create!(
        name: 'Custom Sensor',
        uuid: 'acc-2',
        room: room,
        raw_data: {
          'services' => [
            {
              'typeName' => 'Occupancy Sensor',
              'uniqueIdentifier' => 'svc-2',
              'characteristics' => [
                {
                  'typeName' => '',
                  'description' => 'Custom',
                  'uniqueIdentifier' => 'char-custom',
                  'value' => '1',
                  'properties' => [
                    'HMCharacteristicPropertyWritable',
                    'HMCharacteristicPropertySupportsEventNotification'
                  ]
                }
              ]
            }
          ]
        }
      )

      sensors = service.extract_sensors(accessory)

      expect(sensors.map(&:characteristic_type)).to include('Custom')
    end
  end
end
