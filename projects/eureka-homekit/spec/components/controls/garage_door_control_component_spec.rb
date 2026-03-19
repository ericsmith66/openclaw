require 'rails_helper'

RSpec.describe Controls::GarageDoorControlComponent, type: :component do
  let(:home) { create(:home) }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room, name: 'Garage Door') }

  describe 'garage door in closed state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '1') # Closed
      create(:sensor, accessory: accessory, characteristic_type: 'Target Door State', current_value: '1', is_writable: true)
    end

    it 'renders accessory name' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Garage Door')
    end

    it 'renders with garage-door-control controller' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('[data-controller="garage-door-control"]')
    end

    it 'shows closed state' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Closed')
    end

    it 'shows closed icon' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:state_icon)).to eq('🔒')
    end

    it 'shows open button' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('button', text: 'Open')
    end

    it 'does not show close button' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_selector('button', text: 'Close')
    end

    it 'renders open confirmation modal' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('dialog', text: 'Open Garage Door?')
    end
  end

  describe 'garage door in open state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '0') # Open
      create(:sensor, accessory: accessory, characteristic_type: 'Target Door State', current_value: '0', is_writable: true)
    end

    it 'shows open state' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Open')
    end

    it 'shows open icon' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:state_icon)).to eq('🔓')
    end

    it 'shows close button' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('button', text: 'Close')
    end

    it 'does not show open button' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_selector('button', text: 'Open')
    end

    it 'renders close confirmation modal' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('dialog', text: 'Close Garage Door?')
    end
  end

  describe 'garage door in opening state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '2') # Opening
      create(:sensor, accessory: accessory, characteristic_type: 'Target Door State', current_value: '0', is_writable: true)
    end

    it 'shows opening state' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Opening')
    end

    it 'shows opening icon' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:state_icon)).to eq('⬆️')
    end

    it 'does not show action buttons' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_selector('button', text: 'Open')
      expect(page).not_to have_selector('button', text: 'Close')
    end
  end

  describe 'garage door in closing state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '3') # Closing
      create(:sensor, accessory: accessory, characteristic_type: 'Target Door State', current_value: '1', is_writable: true)
    end

    it 'shows closing state' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Closing')
    end

    it 'shows closing icon' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:state_icon)).to eq('⬇️')
    end
  end

  describe 'garage door in stopped state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '4') # Stopped
      create(:sensor, accessory: accessory, characteristic_type: 'Target Door State', current_value: '1', is_writable: true)
    end

    it 'shows stopped state' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Stopped')
    end

    it 'shows stopped icon' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:state_icon)).to eq('⏸️')
    end

    it 'shows both action buttons' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_selector('button', text: 'Open')
      expect(page).to have_selector('button', text: 'Close')
    end
  end

  describe 'obstruction detection' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '1')
      create(:sensor, accessory: accessory, characteristic_type: 'Target Door State', current_value: '1', is_writable: true)
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

  describe 'lock detection' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '1')
      create(:sensor, accessory: accessory, characteristic_type: 'Target Door State', current_value: '1', is_writable: true)
      create(:sensor, accessory: accessory, characteristic_type: 'Lock Current State', current_value: '1') # Locked
    end

    it 'shows locked info' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).to have_text('Door is locked')
    end

    it 'detects locked state' do
      component = described_class.new(accessory: accessory)
      expect(component.send(:locked?)).to be true
    end

    it 'does not show action buttons when locked' do
      render_inline(described_class.new(accessory: accessory))
      expect(page).not_to have_selector('button', text: 'Open')
      expect(page).not_to have_selector('button', text: 'Close')
    end
  end

  describe 'offline state' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '1', last_seen_at: 2.hours.ago)
      create(:sensor, accessory: accessory, characteristic_type: 'Target Door State', current_value: '1', is_writable: true, last_seen_at: 2.hours.ago)
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
      expect(page).to have_selector('[data-garage-door-control-offline-value="true"]')
    end
  end

  describe 'state color classes' do
    it 'returns warning color for open state' do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '0')
      component = described_class.new(accessory: accessory)
      expect(component.send(:state_color_class)).to eq('text-warning')
    end

    it 'returns success color for closed state' do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '1')
      component = described_class.new(accessory: accessory)
      expect(component.send(:state_color_class)).to eq('text-success')
    end

    it 'returns error color for stopped state' do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '4')
      component = described_class.new(accessory: accessory)
      expect(component.send(:state_color_class)).to eq('text-error')
    end
  end

  describe 'compact mode' do
    before do
      create(:sensor, accessory: accessory, characteristic_type: 'Current Door State', current_value: '1')
      create(:sensor, accessory: accessory, characteristic_type: 'Target Door State', current_value: '1', is_writable: true)
    end

    it 'renders in compact mode' do
      render_inline(described_class.new(accessory: accessory, compact: true))
      expect(page).to have_selector('.card-compact')
    end
  end
end
