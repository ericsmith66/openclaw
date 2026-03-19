# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScenesController, type: :controller do
  render_views

  let(:home) { create(:home, name: 'Main House') }
  let(:home2) { create(:home, name: 'Beach House') }
  let(:room) { create(:room, home: home, name: 'Living Room') }
  let(:accessory) { create(:accessory, room: room, name: 'Light 1') }

  let!(:scene1) { create(:scene, name: 'Good Morning', home: home) }
  let!(:scene2) { create(:scene, name: 'Good Night', home: home) }
  let!(:scene3) { create(:scene, name: 'Movie Time', home: home2) }

  before do
    SceneAccessory.create!(scene: scene1, accessory: accessory)
  end

  describe 'GET #index' do
    it 'returns HTTP 200' do
      get :index
      expect(response).to have_http_status(:ok)
    end

    it 'renders all scenes' do
      get :index
      expect(response.body).to include('Good Morning')
      expect(response.body).to include('Good Night')
      expect(response.body).to include('Movie Time')
    end

    context 'when filtering by home_id' do
      it 'returns only scenes for the specified home' do
        get :index, params: { home_id: home.id }
        expect(response.body).to include('Good Morning')
        expect(response.body).to include('Good Night')
        expect(response.body).not_to include('Movie Time')
      end
    end

    context 'when searching by name' do
      it 'returns matching scenes (case-insensitive)' do
        get :index, params: { search: 'morning' }
        expect(response.body).to include('Good Morning')
        expect(response.body).not_to include('Movie Time')
      end

      it 'returns partial matches' do
        get :index, params: { search: 'Good' }
        expect(response.body).to include('Good Morning')
        expect(response.body).to include('Good Night')
      end

      it 'shows empty state when no scenes match' do
        get :index, params: { search: 'nonexistent' }
        expect(response.body).to include('No scenes configured')
      end
    end

    context 'when combining filters' do
      it 'filters by both home_id and search' do
        get :index, params: { home_id: home.id, search: 'morning' }
        expect(response.body).to include('Good Morning')
        expect(response.body).not_to include('Good Night')
        expect(response.body).not_to include('Movie Time')
      end
    end
  end

  describe 'GET #show' do
    it 'returns HTTP 200' do
      get :show, params: { id: scene1.id }
      expect(response).to have_http_status(:ok)
    end

    it 'renders the scene details' do
      get :show, params: { id: scene1.id }
      expect(response.body).to include('Good Morning')
      expect(response.body).to include('Main House')
      expect(response.body).to include('Light 1')
    end

    it 'renders execution history' do
      ControlEvent.create!(
        scene: scene1,
        action_type: 'execute_scene',
        success: true,
        latency_ms: 150.0,
        source: 'web',
        request_id: SecureRandom.uuid
      )

      get :show, params: { id: scene1.id }
      expect(response.body).to include('150')
      expect(response.body).to include('Success')
    end

    it 'shows empty history message when no events' do
      get :show, params: { id: scene1.id }
      expect(response.body).to include('No execution history')
    end

    it 'returns 404 for nonexistent scene' do
      expect {
        get :show, params: { id: 999999 }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST #execute' do
    context 'when successful' do
      before do
        allow(PrefabControlService).to receive(:trigger_scene).and_return(
          { success: true }
        )
      end

      it 'returns JSON with success true' do
        post :execute, params: { id: scene1.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['message']).to include(scene1.name)
      end

      it 'calls PrefabControlService.trigger_scene with correct args' do
        expect(PrefabControlService).to receive(:trigger_scene).with(
          scene: scene1,
          user_ip: '0.0.0.0'
        )

        post :execute, params: { id: scene1.id }
      end
    end

    context 'when PrefabControlService returns failure' do
      before do
        allow(PrefabControlService).to receive(:trigger_scene).and_return(
          { success: false, error: 'Prefab connection failed' }
        )
      end

      it 'returns 422 with error message' do
        post :execute, params: { id: scene1.id }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to eq('Prefab connection failed')
      end
    end

    context 'when an unexpected exception occurs' do
      before do
        allow(PrefabControlService).to receive(:trigger_scene).and_raise(StandardError, 'Something went wrong')
      end

      it 'returns 500 with generic error message' do
        post :execute, params: { id: scene1.id }

        expect(response).to have_http_status(:internal_server_error)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to eq('Unexpected error')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Scene execution error/)

        post :execute, params: { id: scene1.id }
      end
    end

    it 'returns 500 for nonexistent scene (caught by rescue)' do
      post :execute, params: { id: 999999 }

      expect(response).to have_http_status(:internal_server_error)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['error']).to eq('Unexpected error')
    end
  end
end
