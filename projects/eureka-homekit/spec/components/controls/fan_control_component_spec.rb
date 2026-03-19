require 'rails_helper'

RSpec.describe Controls::FanControlComponent, type: :component do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room, name: 'Ceiling Fan') }

  describe 'basic fan' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Active', current_value: '1', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Rotation Speed', current_value: '50', is_writable: true)
    end

    it 'renders accessory name' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Ceiling Fan')
    end

    it 'renders with fan-control controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('[data-controller="fan-control"]')
    end

    it 'shows active toggle' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('input[type="checkbox"]')
    end

    it 'shows speed slider' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('input[type="range"][min="0"][max="100"]')
    end

    it 'displays current speed' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('50%')
    end

    it 'passes accessory UUID to controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector("[data-fan-control-accessory-id-value='#{accessory.uuid}']")
    end
  end

  describe 'fan with direction control' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Active', current_value: '1', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Rotation Speed', current_value: '50', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Rotation Direction', current_value: '0', is_writable: true)
    end

    it 'shows direction buttons' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('button', text: /clockwise/i)
    end

    it 'has direction capability' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:has_direction?)).to be true
    end
  end

  describe 'fan with oscillation' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Active', current_value: '1', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Rotation Speed', current_value: '50', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Swing Mode', current_value: '1', is_writable: true)
    end

    it 'shows oscillation toggle' do
      render_inline(described_class.new(accessory: accessory))
      # Should have multiple checkboxes (active + oscillation)
      expect(page).to have_selector('input[type="checkbox"]', count: 2)
    end

    it 'has oscillation capability' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:has_oscillation?)).to be true
    end
  end

  describe 'offline state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Active', current_value: '1', is_writable: true, last_seen_at: 2.hours.ago)
      create(:sensor, accessory: accessory, characteristic_type: 'Rotation Speed', current_value: '50', is_writable: true, last_seen_at: 2.hours.ago)
    end

    it 'shows offline badge' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Offline')
    end

    it 'disables controls' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('input[disabled]')
    end

    it 'passes offline value to controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('[data-fan-control-offline-value="true"]')
    end
  end

  describe 'active state' do
    context 'when fan is active' do
      before do
        create(:sensor, accessory: accessory, characteristic_type: 'Active', current_value: '1', is_writable: true)
        create(:sensor, accessory: accessory, characteristic_type: 'Rotation Speed', current_value: '50', is_writable: true)
      end

      it 'shows active state' do
        component = described_class.new(accessory: accessory)
        expect(component.send(:active?)).to be true
      end
    end

    context 'when fan is inactive' do
      before do
        create(:sensor, accessory: accessory, characteristic_type: 'Active', current_value: '0', is_writable: true)
        create(:sensor, accessory: accessory, characteristic_type: 'Rotation Speed', current_value: '0', is_writable: true)
      end

      it 'shows inactive state' do
        component = described_class.new(accessory: accessory)
        expect(component.send(:active?)).to be false
      end
    end
  end

  describe 'state text' do
    it 'returns correct state text for active fan' do
      create(:sensor, accessory: accessory, characteristic_type: 'Active', current_value: '1', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Rotation Speed', current_value: '75', is_writable: true)

      component = described_class.new(accessory: accessory)
      expect(component.send(:state_text)).to eq('On - 75%')
    end

    it 'returns correct state text for inactive fan' do
      create(:sensor, accessory: accessory, characteristic_type: 'Active', current_value: '0', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Rotation Speed', current_value: '0', is_writable: true)

      component = described_class.new(accessory: accessory)
      expect(component.send(:state_text)).to eq('Off')
    end
  end

  describe 'compact mode' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Active', current_value: '1', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Rotation Speed', current_value: '50', is_writable: true)
    end

    it 'renders in compact mode' do
      render_inline(described_class.new(accessory: accessory, compact: true))
      expect(page).to have_selector('.card-compact')
    end
  end
end
