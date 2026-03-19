require 'rails_helper'

RSpec.describe Controls::LightControlComponent, type: :component do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room, name: 'Living Room Light') }

  describe 'basic on/off light' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: 'true', is_writable: true)
    end

    it 'renders accessory name' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Living Room Light')
    end

    it 'renders with light-control controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('[data-controller="light-control"]')
    end

    it 'shows toggle button' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('button', text: /on|off/i)
    end

    it 'does not show brightness slider' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_selector('input[type="range"]')
    end

    it 'does not show color button' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_selector('button', text: /color/i)
    end

    it 'passes accessory UUID to controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector("[data-light-control-accessory-id-value='#{accessory.uuid}']")
    end
  end

  describe 'dimmable light' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: 'true', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Brightness', current_value: '75', is_writable: true)
    end

    it 'shows brightness slider' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('input[type="range"]')
    end

    it 'displays current brightness value' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('75%')
    end

    it 'slider has correct attributes' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('input[type="range"][min="0"][max="100"]')
    end
  end

  describe 'color light' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: 'true', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Hue', current_value: '180', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Saturation', current_value: '100', is_writable: true)
    end

    it 'shows color button' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('button[data-action*="light-control#open_color_picker"]')
    end

    it 'has color capability' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:has_color?)).to be true
    end
  end

  describe 'offline state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: 'true', is_writable: true, last_seen_at: 2.hours.ago)
    end

    it 'shows offline badge' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Offline')
    end

    it 'disables controls' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('button[disabled]')
    end

    it 'passes offline value to controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('[data-light-control-offline-value="true"]')
    end
  end

  describe 'online state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: 'true', is_writable: true, last_seen_at: 5.minutes.ago)
    end

    it 'does not show offline badge' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_text('Offline')
    end

    it 'does not disable controls' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_selector('button[disabled]')
    end
  end

  describe 'compact mode' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: 'true', is_writable: true)
    end

    it 'renders in compact mode' do
      render_inline(described_class.new(accessory: accessory, compact: true))
      expect(page).to have_selector('.card-compact')
    end

    it 'renders in normal mode by default' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_selector('.card-compact')
    end
  end

  describe 'light state' do
    context 'when light is on' do
      before do
        create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: 'true', is_writable: true)
      end

      it 'reflects on state in component' do
        component = described_class.new(accessory: accessory)
        expect(component.send(:current_on_state)).to be true
      end
    end

    context 'when light is off' do
      before do
        create(:sensor, accessory: accessory, characteristic_type: 'On', current_value: 'false', is_writable: true)
      end

      it 'reflects off state in component' do
        component = described_class.new(accessory: accessory)
        expect(component.send(:current_on_state)).to be false
      end
    end
  end
end
