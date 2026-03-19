# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CleanupControlEventsJob, type: :job do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room) }

  describe '#perform' do
    it 'deletes control events older than 30 days' do
      old_event = ControlEvent.create!(
        accessory: accessory,
        action_type: 'set_characteristic',
        success: true,
        latency_ms: 100.0,
        source: 'web',
        request_id: SecureRandom.uuid,
        created_at: 31.days.ago
      )

      recent_event = ControlEvent.create!(
        accessory: accessory,
        action_type: 'set_characteristic',
        success: true,
        latency_ms: 100.0,
        source: 'web',
        request_id: SecureRandom.uuid,
        created_at: 1.day.ago
      )

      described_class.new.perform

      expect(ControlEvent.exists?(old_event.id)).to be false
      expect(ControlEvent.exists?(recent_event.id)).to be true
    end

    it 'returns the count of deleted records' do
      3.times do
        ControlEvent.create!(
          accessory: accessory,
          action_type: 'set_characteristic',
          success: true,
          latency_ms: 100.0,
          source: 'web',
          request_id: SecureRandom.uuid,
          created_at: 35.days.ago
        )
      end

      result = described_class.new.perform
      expect(result).to eq(3)
    end

    it 'returns 0 when no old events exist' do
      ControlEvent.create!(
        accessory: accessory,
        action_type: 'set_characteristic',
        success: true,
        latency_ms: 100.0,
        source: 'web',
        request_id: SecureRandom.uuid,
        created_at: 1.hour.ago
      )

      result = described_class.new.perform
      expect(result).to eq(0)
    end

    it 'preserves events less than 30 days old' do
      recent_enough = ControlEvent.create!(
        accessory: accessory,
        action_type: 'set_characteristic',
        success: true,
        latency_ms: 100.0,
        source: 'web',
        request_id: SecureRandom.uuid,
        created_at: 29.days.ago
      )

      described_class.new.perform
      expect(ControlEvent.exists?(recent_enough.id)).to be true
    end

    it 'logs the deletion count' do
      expect(Rails.logger).to receive(:info).with(/Deleted 0 control events/)
      described_class.new.perform
    end
  end

  describe 'queue configuration' do
    it 'uses the low queue' do
      expect(described_class.new.queue_name).to eq('low')
    end
  end
end
