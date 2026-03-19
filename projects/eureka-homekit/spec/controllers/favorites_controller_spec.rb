# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FavoritesController, type: :controller do
  render_views

  let(:home) { create(:home, name: 'Main House') }
  let(:room) { create(:room, home: home, name: 'Living Room') }
  let(:accessory1) { create(:accessory, room: room, name: 'Light 1', uuid: 'fav-light-1') }
  let(:accessory2) { create(:accessory, room: room, name: 'Light 2', uuid: 'fav-light-2') }
  let(:accessory3) { create(:accessory, room: room, name: 'Fan 1', uuid: 'fav-fan-1') }

  before do
    # Create writable sensors so accessories are controllable
    [ accessory1, accessory2, accessory3 ].each do |acc|
      create(:sensor,
        accessory: acc,
        characteristic_type: 'On',
        current_value: '0',
        service_type: 'Switch',
        is_writable: true
      )
    end
  end

  describe 'GET #index' do
    it 'returns HTTP 200' do
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'renders controllable accessories' do
      get :index
      expect(response.body).to include('Light 1')
      expect(response.body).to include('Light 2')
      expect(response.body).to include('Fan 1')
    end

    it 'renders empty favorites state when none favorited' do
      get :index
      expect(response.body).to include('No favorites yet')
    end

    it 'excludes non-writable accessories' do
      non_writable = create(:accessory, room: room, name: 'Sensor Only', uuid: 'sensor-only')
      create(:sensor, accessory: non_writable, characteristic_type: 'Current Temperature',
             current_value: '22.5', service_type: 'Temperature Sensor', is_writable: false)

      get :index
      expect(response.body).not_to include('Sensor Only')
    end
  end

  describe 'POST #toggle' do
    context 'when adding a favorite' do
      it 'returns success with favorited: true' do
        post :toggle, params: { accessory_uuid: 'fav-light-1' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['favorited']).to be true
      end

      it 'persists the favorite in UserPreference' do
        post :toggle, params: { accessory_uuid: 'fav-light-1' }

        pref = UserPreference.for_session(session.id.to_s)
        expect(pref.favorites).to include('fav-light-1')
      end
    end

    context 'when removing a favorite' do
      before do
        pref = UserPreference.for_session(session.id.to_s)
        pref.add_favorite('fav-light-1')
      end

      it 'returns success with favorited: false' do
        post :toggle, params: { accessory_uuid: 'fav-light-1' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['favorited']).to be false
      end

      it 'removes the favorite from UserPreference' do
        post :toggle, params: { accessory_uuid: 'fav-light-1' }

        pref = UserPreference.for_session(session.id.to_s)
        expect(pref.favorites).not_to include('fav-light-1')
      end
    end

    context 'when accessory_uuid is missing' do
      it 'returns 400 error' do
        post :toggle, params: {}

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to include('Missing')
      end
    end
  end

  describe 'PATCH #reorder' do
    before do
      pref = UserPreference.for_session(session.id.to_s)
      pref.add_favorite('fav-light-1')
      pref.add_favorite('fav-light-2')
      pref.add_favorite('fav-fan-1')
    end

    it 'returns success' do
      patch :reorder, params: { ordered_uuids: [ 'fav-fan-1', 'fav-light-2', 'fav-light-1' ] }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
    end

    it 'persists the new order' do
      patch :reorder, params: { ordered_uuids: [ 'fav-fan-1', 'fav-light-2', 'fav-light-1' ] }

      pref = UserPreference.for_session(session.id.to_s)
      expect(pref.favorites_order).to eq([ 'fav-fan-1', 'fav-light-2', 'fav-light-1' ])
    end

    it 'ignores UUIDs not in favorites' do
      patch :reorder, params: { ordered_uuids: [ 'fav-fan-1', 'nonexistent-uuid', 'fav-light-1' ] }

      pref = UserPreference.for_session(session.id.to_s)
      expect(pref.favorites_order).to eq([ 'fav-fan-1', 'fav-light-1' ])
    end

    context 'when ordered_uuids is not an array' do
      it 'returns 400 error' do
        patch :reorder, params: { ordered_uuids: 'not-an-array' }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
      end
    end
  end
end
