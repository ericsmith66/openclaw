# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Batch Controls", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:home) { create(:home, name: 'Main House') }
  let(:room) { create(:room, home: home, name: 'Living Room') }

  before do
    3.times do |i|
      acc = create(:accessory, room: room, name: "Light #{i + 1}", last_seen_at: 5.minutes.ago)
      create(:sensor,
        accessory: acc,
        characteristic_type: 'On',
        current_value: '0',
        service_type: 'Lightbulb',
        is_writable: true,
        last_updated_at: Time.current
      )
    end
  end

  describe 'viewing room with multiple controllable accessories' do
    it 'displays all accessories' do
      visit room_path(room)

      expect(page).to have_content('Light 1')
      expect(page).to have_content('Light 2')
      expect(page).to have_content('Light 3')
    end
  end
end
