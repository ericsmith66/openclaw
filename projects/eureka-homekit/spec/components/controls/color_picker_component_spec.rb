require 'rails_helper'

RSpec.describe Controls::ColorPickerComponent, type: :component do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room, name: 'Color Light') }

  describe 'color picker modal' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Hue', current_value: '180', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Saturation', current_value: '50', is_writable: true)
    end

    it 'renders with color-picker controller' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_selector('[data-controller="color-picker"]')
    end

    it 'shows hue slider' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_selector('input[type="range"][min="0"][max="360"]')
    end

    it 'shows saturation slider' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_selector('input[type="range"][min="0"][max="100"]', count: 1)
    end

    it 'displays current hue value' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_text('180')
    end

    it 'displays current saturation value' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_text('50%')
    end

    it 'shows preview swatch' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_selector('[data-color-picker-target="previewSwatch"]')
    end

    it 'shows apply button' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_selector('button', text: 'Apply')
    end

    it 'shows cancel button' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_selector('button', text: 'Cancel')
    end
  end

  describe 'offline state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Hue', current_value: '180', is_writable: true, last_seen_at: 2.hours.ago)
      create(:sensor, accessory: accessory, characteristic_type: 'Saturation', current_value: '50', is_writable: true, last_seen_at: 2.hours.ago)
    end

    it 'disables sliders when offline' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50, offline: true))
      expect(page).to have_selector('input[disabled]', count: 2)
    end

    it 'disables apply button when offline' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50, offline: true))
      expect(page).to have_selector('button[disabled]', text: 'Apply')
    end
  end

  describe 'slider ranges' do
    it 'hue slider has correct range' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_selector('input[type="range"][min="0"][max="360"]')
    end

    it 'saturation slider has correct range' do
      render_inline(described_class.new(accessory: accessory, current_hue: 180, current_saturation: 50))
      expect(page).to have_selector('input[type="range"][min="0"][max="100"]')
    end
  end

  describe 'preview swatch style' do
    it 'renders preview swatch element' do
      render_inline(described_class.new(accessory: accessory, current_hue: 120, current_saturation: 100))
      expect(page).to have_selector('[data-color-picker-target="previewSwatch"]')
    end
  end
end
