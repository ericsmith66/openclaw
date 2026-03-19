# PRD 1.3: HomeKit Sync Service & Rake Task

## Epic
Epic 1: Initial Rails Server Setup with Prefab Integration

## Objective
Create service to sync HomeKit structure from Prefab API into database.

## Requirements

### Service Class: `HomekitSync`
Location: `app/services/homekit_sync.rb`

#### Purpose
Fetch complete HomeKit structure from Prefab and populate database.

#### Logic Flow
1. Fetch all homes from `PrefabClient.homes`
2. For each home:
   - Create/update `Home` record
   - Fetch rooms for home
   - For each room:
     - Create/update `Room` record
     - Fetch accessories for room
     - For each accessory:
       - Create/update `Accessory` record with characteristics
   - Fetch scenes for home
   - For each scene:
     - Create/update `Scene` record
     - Link accessories to scene via `SceneAccessory` join table

#### Features
- Use `find_or_initialize_by(uuid:)` to avoid duplicates
- Update existing records if data changed
- Handle scenes that reference accessories across multiple rooms
- Clear old scene-accessory associations before rebuilding
- Log progress (homes, rooms, accessories, scenes processed)
- Return summary hash: `{ homes: 2, rooms: 5, accessories: 12, scenes: 3 }`

## Implementation Example

```ruby
class HomekitSync
  def self.perform
    new.perform
  end

  def perform
    summary = { homes: 0, rooms: 0, accessories: 0, scenes: 0 }

    homes_data = PrefabClient.homes
    Rails.logger.info("Syncing #{homes_data.size} homes from Prefab")

    homes_data.each do |home_data|
      home = sync_home(home_data)
      summary[:homes] += 1

      # Sync rooms and accessories
      rooms_data = PrefabClient.rooms(home.name)
      rooms_data.each do |room_data|
        room = sync_room(home, room_data)
        summary[:rooms] += 1

        accessories_data = PrefabClient.accessories(home.name, room.name)
        accessories_data.each do |accessory_data|
          sync_accessory(room, accessory_data)
          summary[:accessories] += 1
        end
      end

      # Sync scenes (home-level, can reference accessories across rooms)
      scenes_data = PrefabClient.scenes(home.name)
      scenes_data.each do |scene_data|
        sync_scene(home, scene_data)
        summary[:scenes] += 1
      end
    end

    Rails.logger.info("Sync complete: #{summary}")
    summary
  end

  private

  def sync_home(data)
    home = Home.find_or_initialize_by(uuid: data['uuid'])
    home.assign_attributes(
      name: data['name'],
      homekit_home_id: data['id']
    )
    home.save!
    home
  end

  def sync_room(home, data)
    room = Room.find_or_initialize_by(uuid: data['uuid'])
    room.assign_attributes(
      name: data['name'],
      home: home
    )
    room.save!
    room
  end

  def sync_accessory(room, data)
    accessory = Accessory.find_or_initialize_by(uuid: data['uuid'])
    accessory.assign_attributes(
      name: data['name'],
      room: room,
      characteristics: data['characteristics'] || {}
    )
    accessory.save!
    accessory
  end

  def sync_scene(home, data)
    scene = Scene.find_or_initialize_by(uuid: data['uuid'])
    scene.assign_attributes(
      name: data['name'],
      home: home,
      metadata: data['metadata'] || {}
    )
    scene.save!

    # Clear existing associations and rebuild
    scene.scene_accessories.destroy_all

    # Link accessories if provided (by name or UUID)
    if data['accessories'].present?
      data['accessories'].each do |accessory_ref|
        accessory = home.rooms.joins(:accessories).find_by(
          accessories: { uuid: accessory_ref }
        ) || home.rooms.joins(:accessories).find_by(
          accessories: { name: accessory_ref }
        )

        scene.accessories << accessory if accessory
      end
    end

    scene
  end
end
```

### Rake Task
Location: `lib/tasks/homekit.rake`

```ruby
namespace :homekit do
  desc "Sync HomeKit structure from Prefab"
  task sync: :environment do
    puts "Starting HomeKit sync from Prefab..."
    summary = HomekitSync.perform
    puts "✅ Sync complete!"
    puts "   Homes: #{summary[:homes]}"
    puts "   Rooms: #{summary[:rooms]}"
    puts "   Accessories: #{summary[:accessories]}"
    puts "   Scenes: #{summary[:scenes]}"
  end
end
```

## Usage
```bash
rails homekit:sync
```

## Success Criteria
- ✅ Task syncs all homes, rooms, accessories, and scenes
- ✅ Scenes correctly linked to accessories via join table
- ✅ Handles scenes that reference accessories across different rooms
- ✅ Handles missing data gracefully
- ✅ Doesn't create duplicates
- ✅ Updates existing records
- ✅ Clears and rebuilds scene-accessory associations on each sync
- ✅ Logs progress and summary

## Testing

### RSpec Test Cases

**spec/services/homekit_sync_spec.rb**
```ruby
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

        expect(summary).to eq({ homes: 0, rooms: 0, accessories: 0, scenes: 0 })
      end
    end

    context 'with complete home structure' do
      let(:homes_data) do
        [{ 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' }]
      end

      let(:rooms_data) do
        [{ 'name' => 'Living Room', 'uuid' => 'room-1' }]
      end

      let(:accessories_data) do
        [{
          'name' => 'Floor Lamp',
          'uuid' => 'acc-1',
          'characteristics' => { 'power' => true, 'brightness' => 80 }
        }]
      end

      let(:scenes_data) do
        [{
          'name' => 'Movie Time',
          'uuid' => 'scene-1',
          'accessories' => ['acc-1']
        }]
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
          scenes: 1
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
        expect(Rails.logger).to receive(:info).with('Syncing 1 homes from Prefab')
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
        [{ 'name' => 'Studio', 'uuid' => 'room-3' }]
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
        [{ 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' }]
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
        updated_data = [{ 'name' => 'Updated House', 'uuid' => 'home-1', 'id' => 'hk-1' }]
        allow(PrefabClient).to receive(:homes).and_return(updated_data)

        service.perform
        home.reload

        expect(home.name).to eq('Updated House')
        expect(Home.count).to eq(1) # Still only one home
      end
    end

    context 'scene-accessory associations' do
      let(:homes_data) do
        [{ 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' }]
      end

      let(:rooms_data) do
        [
          { 'name' => 'Living Room', 'uuid' => 'room-1' },
          { 'name' => 'Bedroom', 'uuid' => 'room-2' }
        ]
      end

      let(:living_room_accessories) do
        [{ 'name' => 'TV Light', 'uuid' => 'acc-1', 'characteristics' => {} }]
      end

      let(:bedroom_accessories) do
        [{ 'name' => 'Bedside Lamp', 'uuid' => 'acc-2', 'characteristics' => {} }]
      end

      let(:scenes_data) do
        [{
          'name' => 'Good Night',
          'uuid' => 'scene-1',
          'accessories' => ['acc-1', 'acc-2'] # References accessories from both rooms
        }]
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
        updated_scenes = [{
          'name' => 'Good Night',
          'uuid' => 'scene-1',
          'accessories' => ['acc-1'] # Only one accessory now
        }]
        allow(PrefabClient).to receive(:scenes).and_return(updated_scenes)

        service.perform
        scene.reload

        expect(scene.accessories.count).to eq(1)
        expect(scene.accessories.first.name).to eq('TV Light')
      end
    end

    context 'partial failures' do
      let(:homes_data) do
        [{ 'name' => 'Main House', 'uuid' => 'home-1', 'id' => 'hk-1' }]
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
        rooms_data = [{ 'name' => 'Living Room', 'uuid' => 'room-1' }]
        accessories_data = [{ 'name' => 'Light', 'uuid' => 'acc-1' }] # No characteristics key

        allow(PrefabClient).to receive(:rooms).and_return(rooms_data)
        allow(PrefabClient).to receive(:accessories).and_return(accessories_data)

        service.perform
        accessory = Accessory.last

        expect(accessory.characteristics).to eq({})
      end

      it 'handles scene without accessories' do
        rooms_data = [{ 'name' => 'Living Room', 'uuid' => 'room-1' }]
        scenes_data = [{ 'name' => 'Empty Scene', 'uuid' => 'scene-1' }]

        allow(PrefabClient).to receive(:rooms).and_return(rooms_data)
        allow(PrefabClient).to receive(:accessories).and_return([])
        allow(PrefabClient).to receive(:scenes).and_return(scenes_data)

        expect { service.perform }.not_to raise_error

        scene = Scene.last
        expect(scene.accessories).to be_empty
      end
    end
  end
end
```

**spec/tasks/homekit_rake_spec.rb**
```ruby
require 'rails_helper'
require 'rake'

RSpec.describe 'homekit:sync rake task' do
  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  it 'invokes HomekitSync.perform' do
    summary = { homes: 2, rooms: 5, accessories: 10, scenes: 3 }
    expect(HomekitSync).to receive(:perform).and_return(summary)

    expect { Rake::Task['homekit:sync'].invoke }.to output(
      /Starting HomeKit sync from Prefab/
    ).to_stdout
  end

  it 'displays summary after completion' do
    summary = { homes: 2, rooms: 5, accessories: 10, scenes: 3 }
    allow(HomekitSync).to receive(:perform).and_return(summary)

    expect { Rake::Task['homekit:sync'].invoke }.to output(
      /Homes: 2.*Rooms: 5.*Accessories: 10.*Scenes: 3/m
    ).to_stdout
  end
end
```

### Test Coverage Goals
- ✅ Full sync workflow tested
- ✅ Idempotency verified
- ✅ Multiple homes/rooms handled
- ✅ Scene-accessory associations tested
- ✅ Association clearing/rebuilding tested
- ✅ Partial failures handled
- ✅ Logging behavior verified
- ✅ Rake task tested

---
**Status**: Ready
**Depends On**: PRD 1.1, PRD 1.2
**Blocks**: None
