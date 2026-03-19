# PRD 1.1: Database Schema for HomeKit Data

## Epic
Epic 1: Initial Rails Server Setup with Prefab Integration

## Objective
Create database schema to store HomeKit homes, rooms, accessories, and events.

## Requirements

### Models & Migrations
Create 6 models with migrations:

1. **Home**
   - `name` (string, indexed)
   - `uuid` (string, unique, indexed)
   - `homekit_home_id` (string)
   - timestamps

2. **Room**
   - `name` (string, indexed)
   - `uuid` (string, unique, indexed)
   - `home_id` (bigint, foreign key, indexed)
   - timestamps

3. **Accessory**
   - `name` (string, indexed)
   - `uuid` (string, unique, indexed)
   - `room_id` (bigint, foreign key, indexed)
   - `characteristics` (jsonb, default: {})
   - timestamps

4. **Scene**
   - `name` (string, indexed)
   - `uuid` (string, unique, indexed)
   - `home_id` (bigint, foreign key, indexed)
   - `metadata` (jsonb, default: {})
   - timestamps

5. **SceneAccessory** (join table)
   - `scene_id` (bigint, foreign key, indexed)
   - `accessory_id` (bigint, foreign key, indexed)
   - timestamps

6. **HomekitEvent**
   - `event_type` (string, indexed)
   - `accessory_name` (string, indexed)
   - `characteristic` (string)
   - `value` (jsonb)
   - `raw_payload` (jsonb)
   - `timestamp` (datetime, indexed)
   - timestamps

### Associations
- `Home` has_many `rooms`, dependent: :destroy
- `Home` has_many `scenes`, dependent: :destroy
- `Room` belongs_to `home`, has_many `accessories`, dependent: :destroy
- `Accessory` belongs_to `room`
- `Accessory` has_many `scene_accessories`, has_many `scenes`, through: :scene_accessories
- `Scene` belongs_to `home`
- `Scene` has_many `scene_accessories`, has_many `accessories`, through: :scene_accessories
- `SceneAccessory` belongs_to `scene`, belongs_to `accessory`
- No associations for `HomekitEvent` (logging table)

### Validations
- `Home`: presence of name, uuid; uniqueness of uuid
- `Room`: presence of name, uuid; uniqueness of uuid
- `Accessory`: presence of name, uuid; uniqueness of uuid
- `Scene`: presence of name, uuid; uniqueness of uuid
- `SceneAccessory`: presence of scene_id, accessory_id
- `HomekitEvent`: presence of event_type, timestamp

## Success Criteria
- ✅ All migrations run successfully
- ✅ Models have correct associations
- ✅ Validations in place
- ✅ Database ready for data sync

## Commands
```bash
rails generate model Home name:string uuid:string:uniq homekit_home_id:string
rails generate model Room name:string uuid:string:uniq home:references
rails generate model Accessory name:string uuid:string:uniq room:references characteristics:jsonb
rails generate model Scene name:string uuid:string:uniq home:references metadata:jsonb
rails generate model SceneAccessory scene:references accessory:references
rails generate model HomekitEvent event_type:string accessory_name:string characteristic:string value:jsonb raw_payload:jsonb timestamp:datetime
rails db:migrate
```

## Database Rationale

### Why Scenes Have Many-to-Many with Accessories
- A scene can control multiple accessories across different rooms (e.g., "Good Night" turns off all lights)
- An accessory can be part of multiple scenes (e.g., "Living Room Light" in both "Movie Time" and "Dinner" scenes)
- Scenes belong to a Home, not a Room (they're home-level constructs in HomeKit)

## Testing

### RSpec Test Cases

#### Model Specs

**spec/models/home_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe Home, type: :model do
  describe 'associations' do
    it { should have_many(:rooms).dependent(:destroy) }
    it { should have_many(:scenes).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:home) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:uuid) }
    it { should validate_uniqueness_of(:uuid) }
  end

  describe 'cascade deletion' do
    it 'destroys associated rooms when home is destroyed' do
      home = create(:home)
      room = create(:room, home: home)

      expect { home.destroy }.to change(Room, :count).by(-1)
    end

    it 'destroys associated scenes when home is destroyed' do
      home = create(:home)
      scene = create(:scene, home: home)

      expect { home.destroy }.to change(Scene, :count).by(-1)
    end
  end
end
```

**spec/models/room_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe Room, type: :model do
  describe 'associations' do
    it { should belong_to(:home) }
    it { should have_many(:accessories).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:room) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:uuid) }
    it { should validate_uniqueness_of(:uuid) }
  end

  describe 'cascade deletion' do
    it 'destroys associated accessories when room is destroyed' do
      room = create(:room)
      accessory = create(:accessory, room: room)

      expect { room.destroy }.to change(Accessory, :count).by(-1)
    end
  end
end
```

**spec/models/accessory_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe Accessory, type: :model do
  describe 'associations' do
    it { should belong_to(:room) }
    it { should have_many(:scene_accessories) }
    it { should have_many(:scenes).through(:scene_accessories) }
  end

  describe 'validations' do
    subject { build(:accessory) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:uuid) }
    it { should validate_uniqueness_of(:uuid) }
  end

  describe 'characteristics' do
    it 'defaults to empty hash' do
      accessory = create(:accessory, characteristics: nil)
      expect(accessory.characteristics).to eq({})
    end

    it 'stores jsonb data' do
      characteristics = { 'power' => true, 'brightness' => 80 }
      accessory = create(:accessory, characteristics: characteristics)

      expect(accessory.characteristics).to eq(characteristics)
    end
  end

  describe 'scene associations' do
    it 'can be part of multiple scenes' do
      accessory = create(:accessory)
      scene1 = create(:scene)
      scene2 = create(:scene)

      accessory.scenes << scene1
      accessory.scenes << scene2

      expect(accessory.scenes.count).to eq(2)
    end
  end
end
```

**spec/models/scene_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe Scene, type: :model do
  describe 'associations' do
    it { should belong_to(:home) }
    it { should have_many(:scene_accessories) }
    it { should have_many(:accessories).through(:scene_accessories) }
  end

  describe 'validations' do
    subject { build(:scene) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:uuid) }
    it { should validate_uniqueness_of(:uuid) }
  end

  describe 'metadata' do
    it 'defaults to empty hash' do
      scene = create(:scene, metadata: nil)
      expect(scene.metadata).to eq({})
    end

    it 'stores jsonb data' do
      metadata = { 'icon' => 'moon', 'color' => '#1E3A8A' }
      scene = create(:scene, metadata: metadata)

      expect(scene.metadata).to eq(metadata)
    end
  end

  describe 'accessory associations' do
    it 'can contain multiple accessories from different rooms' do
      home = create(:home)
      room1 = create(:room, home: home)
      room2 = create(:room, home: home)
      accessory1 = create(:accessory, room: room1)
      accessory2 = create(:accessory, room: room2)
      scene = create(:scene, home: home)

      scene.accessories << accessory1
      scene.accessories << accessory2

      expect(scene.accessories.count).to eq(2)
      expect(scene.accessories).to include(accessory1, accessory2)
    end
  end
end
```

**spec/models/scene_accessory_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe SceneAccessory, type: :model do
  describe 'associations' do
    it { should belong_to(:scene) }
    it { should belong_to(:accessory) }
  end

  describe 'validations' do
    it { should validate_presence_of(:scene_id) }
    it { should validate_presence_of(:accessory_id) }
  end

  describe 'join table functionality' do
    it 'creates valid many-to-many relationship' do
      scene = create(:scene)
      accessory = create(:accessory)

      scene_accessory = SceneAccessory.create!(
        scene: scene,
        accessory: accessory
      )

      expect(scene_accessory).to be_persisted
      expect(scene.accessories).to include(accessory)
      expect(accessory.scenes).to include(scene)
    end
  end
end
```

**spec/models/homekit_event_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe HomekitEvent, type: :model do
  describe 'associations' do
    it 'has no associations' do
      expect(described_class.reflect_on_all_associations).to be_empty
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:event_type) }
    it { should validate_presence_of(:timestamp) }
  end

  describe 'jsonb columns' do
    it 'stores value as jsonb' do
      event = create(:homekit_event, value: { 'state' => 1 })
      expect(event.value).to eq({ 'state' => 1 })
    end

    it 'stores raw_payload as jsonb' do
      payload = { 'type' => 'update', 'data' => { 'value' => 1 } }
      event = create(:homekit_event, raw_payload: payload)
      expect(event.raw_payload).to eq(payload)
    end
  end
end
```

#### Factory Definitions

**spec/factories/homes.rb**
```ruby
FactoryBot.define do
  factory :home do
    sequence(:name) { |n| "Home #{n}" }
    sequence(:uuid) { |n| "home-uuid-#{n}" }
    homekit_home_id { SecureRandom.uuid }
  end
end
```

**spec/factories/rooms.rb**
```ruby
FactoryBot.define do
  factory :room do
    sequence(:name) { |n| "Room #{n}" }
    sequence(:uuid) { |n| "room-uuid-#{n}" }
    association :home
  end
end
```

**spec/factories/accessories.rb**
```ruby
FactoryBot.define do
  factory :accessory do
    sequence(:name) { |n| "Accessory #{n}" }
    sequence(:uuid) { |n| "accessory-uuid-#{n}" }
    association :room
    characteristics { {} }
  end
end
```

**spec/factories/scenes.rb**
```ruby
FactoryBot.define do
  factory :scene do
    sequence(:name) { |n| "Scene #{n}" }
    sequence(:uuid) { |n| "scene-uuid-#{n}" }
    association :home
    metadata { {} }
  end
end
```

**spec/factories/homekit_events.rb**
```ruby
FactoryBot.define do
  factory :homekit_event do
    event_type { 'characteristic_updated' }
    accessory_name { 'Front Door' }
    characteristic { 'Lock Current State' }
    value { { 'state' => 1 } }
    raw_payload { { 'type' => 'characteristic_updated' } }
    timestamp { Time.current }
  end
end
```

#### Migration Specs

**spec/db/schema_spec.rb**
```ruby
require 'rails_helper'

RSpec.describe 'Database Schema' do
  it 'has correct indexes on homes' do
    expect(ActiveRecord::Base.connection.index_exists?(:homes, :name)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:homes, :uuid, unique: true)).to be true
  end

  it 'has correct indexes on rooms' do
    expect(ActiveRecord::Base.connection.index_exists?(:rooms, :name)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:rooms, :uuid, unique: true)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:rooms, :home_id)).to be true
  end

  it 'has correct indexes on accessories' do
    expect(ActiveRecord::Base.connection.index_exists?(:accessories, :name)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:accessories, :uuid, unique: true)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:accessories, :room_id)).to be true
  end

  it 'has correct indexes on scenes' do
    expect(ActiveRecord::Base.connection.index_exists?(:scenes, :name)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:scenes, :uuid, unique: true)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:scenes, :home_id)).to be true
  end

  it 'has correct indexes on scene_accessories' do
    expect(ActiveRecord::Base.connection.index_exists?(:scene_accessories, :scene_id)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:scene_accessories, :accessory_id)).to be true
  end

  it 'has correct indexes on homekit_events' do
    expect(ActiveRecord::Base.connection.index_exists?(:homekit_events, :event_type)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:homekit_events, :accessory_name)).to be true
    expect(ActiveRecord::Base.connection.index_exists?(:homekit_events, :timestamp)).to be true
  end
end
```

---
**Status**: Ready
**Depends On**: None
**Blocks**: PRD 1.2, 1.3
