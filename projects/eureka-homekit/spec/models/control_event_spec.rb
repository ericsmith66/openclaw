require 'rails_helper'

RSpec.describe ControlEvent, type: :model do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room) }
  let(:scene) { create(:scene, home: home) }

  describe 'validations' do
    it 'validates presence of action_type' do
      event = ControlEvent.new(success: true)
      expect(event).not_to be_valid
      expect(event.errors[:action_type]).to include("can't be blank")
    end

    it 'validates action_type inclusion' do
      event = ControlEvent.new(action_type: 'invalid', success: true)
      expect(event).not_to be_valid
      expect(event.errors[:action_type]).to include('is not included in the list')
    end

    it 'validates success inclusion' do
      event = ControlEvent.new(action_type: 'set_characteristic', success: nil)
      expect(event).not_to be_valid
      expect(event.errors[:success]).to include('is not included in the list')
    end

    it 'is valid with valid attributes' do
      event = ControlEvent.new(
        action_type: 'set_characteristic',
        success: true,
        accessory: accessory,
        characteristic: 'On',
        new_value: 'true'
      )
      expect(event).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to accessory optionally' do
      event = ControlEvent.create!(action_type: 'execute_scene', success: true, scene: scene)
      expect(event.accessory).to be_nil
      expect(event).to be_valid
    end

    it 'belongs to scene optionally' do
      event = ControlEvent.create!(action_type: 'set_characteristic', success: true, accessory: accessory)
      expect(event.scene).to be_nil
      expect(event).to be_valid
    end
  end

  describe 'scopes' do
    before do
      # Create mix of successful and failed events
      3.times do
        ControlEvent.create!(
          action_type: 'set_characteristic',
          success: true,
          accessory: accessory,
          characteristic: 'On',
          new_value: 'true',
          latency_ms: 100
        )
      end

      2.times do
        ControlEvent.create!(
          action_type: 'set_characteristic',
          success: false,
          accessory: accessory,
          characteristic: 'On',
          error_message: 'Failed',
          latency_ms: 200
        )
      end

      # Create old event
      ControlEvent.create!(
        action_type: 'set_characteristic',
        success: true,
        accessory: accessory,
        created_at: 2.days.ago
      )
    end

    describe '.successful' do
      it 'returns only successful events' do
        expect(ControlEvent.successful.count).to eq(4) # 3 recent + 1 old
        expect(ControlEvent.successful.all?(&:success)).to be true
      end
    end

    describe '.failed' do
      it 'returns only failed events' do
        expect(ControlEvent.failed.count).to eq(2)
        expect(ControlEvent.failed.all? { |e| !e.success }).to be true
      end
    end

    describe '.recent' do
      it 'returns up to 100 most recent events ordered by created_at desc' do
        events = ControlEvent.recent
        expect(events.count).to eq(6)
        expect(events.first.created_at).to be >= events.last.created_at
      end
    end

    describe '.for_accessory' do
      let(:other_accessory) { create(:accessory, room: room) }

      it 'returns events for specified accessory' do
        ControlEvent.create!(action_type: 'set_characteristic', success: true, accessory: other_accessory)

        events = ControlEvent.for_accessory(accessory.id)
        expect(events.count).to eq(6)
        expect(events.all? { |e| e.accessory_id == accessory.id }).to be true
      end
    end

    describe '.for_scene' do
      it 'returns events for specified scene' do
        ControlEvent.create!(action_type: 'execute_scene', success: true, scene: scene)

        events = ControlEvent.for_scene(scene.id)
        expect(events.count).to eq(1)
        expect(events.first.scene_id).to eq(scene.id)
      end
    end

    describe '.from_source' do
      before do
        ControlEvent.create!(action_type: 'set_characteristic', success: true, accessory: accessory, source: 'web')
        ControlEvent.create!(action_type: 'set_characteristic', success: true, accessory: accessory, source: 'mobile')
      end

      it 'returns events from specified source' do
        events = ControlEvent.from_source('web')
        expect(events.count).to eq(1)
        expect(events.first.source).to eq('web')
      end
    end

    describe '.recent_within' do
      it 'returns events within specified time range' do
        events = ControlEvent.recent_within(24.hours.ago)
        expect(events.count).to eq(5) # Excludes 2-day-old event
      end

      it 'defaults to 24 hours ago' do
        events = ControlEvent.recent_within
        expect(events.count).to eq(5)
      end
    end
  end

  describe 'class methods' do
    before do
      # Create events with known latencies
      ControlEvent.create!(
        action_type: 'set_characteristic',
        success: true,
        accessory: accessory,
        latency_ms: 100,
        created_at: 1.hour.ago
      )

      ControlEvent.create!(
        action_type: 'set_characteristic',
        success: true,
        accessory: accessory,
        latency_ms: 200,
        created_at: 1.hour.ago
      )

      ControlEvent.create!(
        action_type: 'set_characteristic',
        success: false,
        accessory: accessory,
        latency_ms: 300,
        created_at: 1.hour.ago
      )

      # Old event outside time range
      ControlEvent.create!(
        action_type: 'set_characteristic',
        success: false,
        accessory: accessory,
        latency_ms: 1000,
        created_at: 2.days.ago
      )
    end

    describe '.success_rate' do
      it 'calculates success rate within time range' do
        rate = ControlEvent.success_rate(24.hours.ago)
        expect(rate).to eq(66.67) # 2 successful out of 3 total = 66.67%
      end

      it 'returns 0.0 when no events exist' do
        ControlEvent.destroy_all
        expect(ControlEvent.success_rate).to eq(0.0)
      end

      it 'defaults to 24 hours ago' do
        rate = ControlEvent.success_rate
        expect(rate).to eq(66.67)
      end
    end

    describe '.average_latency' do
      it 'calculates average latency within time range' do
        avg = ControlEvent.average_latency(24.hours.ago)
        expect(avg).to eq(200.0) # (100 + 200 + 300) / 3 = 200
      end

      it 'returns 0.0 when no events exist' do
        ControlEvent.destroy_all
        expect(ControlEvent.average_latency).to eq(0.0)
      end

      it 'defaults to 24 hours ago' do
        avg = ControlEvent.average_latency
        expect(avg).to eq(200.0)
      end
    end
  end
end
