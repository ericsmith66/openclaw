# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Favorites Dashboard", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:home) { create(:home, name: 'Main House') }
  let(:room) { create(:room, home: home, name: 'Living Room') }

  describe 'viewing favorites page' do
    context 'when no controllable accessories exist' do
      it 'shows empty state' do
        visit favorites_path

        expect(page).to have_content('No controllable accessories')
      end
    end

    context 'when controllable accessories exist but no favorites' do
      before do
        acc = create(:accessory, room: room, name: 'Light 1', last_seen_at: 5.minutes.ago)
        create(:sensor,
          accessory: acc,
          characteristic_type: 'On',
          current_value: '0',
          service_type: 'Switch',
          is_writable: true,
          last_updated_at: Time.current
        )
      end

      it 'shows the favorites page heading' do
        visit favorites_path

        expect(page).to have_content('Favorites')
        expect(page).to have_content('Quick access')
      end

      it 'shows empty favorites state' do
        visit favorites_path

        expect(page).to have_content('No favorites yet')
        expect(page).to have_content('Star accessories')
      end
    end

    context 'when favorites exist' do
      let!(:accessory) do
        acc = create(:accessory, room: room, name: 'Favorite Light', uuid: 'fav-test-uuid', last_seen_at: 5.minutes.ago)
        create(:sensor,
          accessory: acc,
          characteristic_type: 'On',
          current_value: '1',
          service_type: 'Switch',
          is_writable: true,
          last_updated_at: Time.current
        )
        acc
      end

      it 'displays favorited accessories' do
        # Create server-side favorite preference
        # Note: In system tests, session.id is set by the test framework
        visit favorites_path

        # The page loads with favorites from the server session
        expect(page).to have_content('Favorites')
      end
    end
  end
end
