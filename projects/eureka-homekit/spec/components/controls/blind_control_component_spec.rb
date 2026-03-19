require 'rails_helper'

RSpec.describe Controls::BlindControlComponent, type: :component do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room, name: 'Living Room Blinds') }

  describe 'basic blind' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Target Position', current_value: '50', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Current Position', current_value: '50')
    end

    it 'renders accessory name' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Living Room Blinds')
    end

    it 'renders with blind-control controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('[data-controller="blind-control"]')
    end

    it 'shows quick action buttons' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('button', text: 'Open')
      expect(page).to have_selector('button', text: '50%')
      expect(page).to have_selector('button', text: 'Close')
    end

    it 'shows position slider' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('input[type="range"][min="0"][max="100"]')
    end

    it 'displays current position' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('50%')
    end

    it 'passes accessory UUID to controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector("[data-blind-control-accessory-id-value='#{accessory.uuid}']")
    end

    it 'does not show tilt slider' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_text('Tilt')
    end
  end

  describe 'blind with tilt control' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Target Position', current_value: '50', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Current Position', current_value: '50')
      create(:sensor, accessory: accessory, characteristic_type: 'Target Horizontal Tilt Angle', current_value: '0', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Current Horizontal Tilt Angle', current_value: '0')
    end

    it 'shows tilt slider' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Tilt')
      expect(page).to have_selector('input[type="range"][min="-90"][max="90"]')
    end

    it 'displays current tilt angle' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('0°')
    end

    it 'has tilt capability' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:has_tilt?)).to be true
    end
  end

  describe 'blind with obstruction detected' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Target Position', current_value: '50', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Current Position', current_value: '50')
      create(:sensor, accessory: accessory, characteristic_type: 'Obstruction Detected', current_value: 'true')
    end

    it 'shows obstruction warning' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Obstruction detected')
    end

    it 'detects obstruction' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:obstruction_detected?)).to be true
    end
  end

  describe 'offline state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Target Position', current_value: '50', is_writable: true, last_seen_at: 2.hours.ago)
      create(:sensor, accessory: accessory, characteristic_type: 'Current Position', current_value: '50', last_seen_at: 2.hours.ago)
    end

    it 'shows offline badge' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Offline')
    end

    it 'disables controls' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('button[disabled]')
      expect(page).to have_selector('input[disabled]')
    end

    it 'passes offline value to controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('[data-blind-control-offline-value="true"]')
    end
  end

  describe 'position values' do
    it 'correctly reports position' do
      create(:sensor, accessory: accessory, characteristic_type: 'Target Position', current_value: '75', is_writable: true)

      component = described_class.new(accessory: accessory)
      expect(component.send(:current_position)).to eq(75)
    end

    it 'returns 0 when no position sensor' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:current_position)).to eq(0)
    end
  end

  describe 'compact mode' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Target Position', current_value: '50', is_writable: true)
    end

    it 'renders in compact mode' do
      render_inline(described_class.new(accessory: accessory, compact: true))
      expect(page).to have_selector('.card-compact')
    end
  end
end
