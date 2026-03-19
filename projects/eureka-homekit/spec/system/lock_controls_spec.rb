# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Lock Controls", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:home) { create(:home, name: 'Main House') }
  let(:room) { create(:room, home: home, name: 'Front Door') }
  let!(:lock) do
    acc = create(:accessory, room: room, name: 'Front Lock', last_seen_at: 5.minutes.ago)
    create(:sensor,
      accessory: acc,
      characteristic_type: 'Lock Current State',
      current_value: '1',
      service_type: 'Lock Mechanism',
      is_writable: false,
      last_updated_at: Time.current
    )
    create(:sensor,
      accessory: acc,
      characteristic_type: 'Lock Target State',
      current_value: '1',
      service_type: 'Lock Mechanism',
      is_writable: true,
      last_updated_at: Time.current
    )
    acc
  end

  describe 'viewing lock controls on room page' do
    it 'displays the lock accessory' do
      visit room_path(room)

      expect(page).to have_content('Front Lock')
    end
  end
end
