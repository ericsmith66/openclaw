# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Thermostat Controls", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:home) { create(:home, name: 'Main House') }
  let(:room) { create(:room, home: home, name: 'Living Room') }
  let!(:thermostat) do
    acc = create(:accessory, room: room, name: 'Nest Thermostat', last_seen_at: 5.minutes.ago)
    create(:sensor,
      accessory: acc,
      characteristic_type: 'Current Temperature',
      current_value: '22.0',
      service_type: 'Thermostat',
      is_writable: false,
      last_updated_at: Time.current
    )
    create(:sensor,
      accessory: acc,
      characteristic_type: 'Target Temperature',
      current_value: '21.0',
      service_type: 'Thermostat',
      is_writable: true,
      last_updated_at: Time.current
    )
    create(:sensor,
      accessory: acc,
      characteristic_type: 'Target Heating/Cooling State',
      current_value: '1',
      service_type: 'Thermostat',
      is_writable: true,
      last_updated_at: Time.current
    )
    acc
  end

  describe 'viewing thermostat controls on room page' do
    it 'displays the thermostat accessory' do
      visit room_path(room)

      expect(page).to have_content('Nest Thermostat')
    end
  end
end
