# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Light Controls", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:home) { create(:home, name: 'Main House') }
  let(:room) { create(:room, home: home, name: 'Living Room') }
  let!(:light) do
    acc = create(:accessory, room: room, name: 'Ceiling Light', last_seen_at: 5.minutes.ago)
    create(:sensor,
      accessory: acc,
      characteristic_type: 'On',
      current_value: '1',
      service_type: 'Lightbulb',
      is_writable: true,
      last_updated_at: Time.current
    )
    create(:sensor,
      accessory: acc,
      characteristic_type: 'Brightness',
      current_value: '75',
      service_type: 'Lightbulb',
      is_writable: true,
      last_updated_at: Time.current
    )
    acc
  end

  describe 'viewing light controls on room page' do
    it 'displays the light accessory with controls' do
      visit room_path(room)

      expect(page).to have_content('Ceiling Light')
    end
  end
end
