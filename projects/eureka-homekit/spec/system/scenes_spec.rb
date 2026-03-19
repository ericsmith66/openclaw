# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Scene Management", type: :system do
  before do
    driven_by(:rack_test)
  end

  let(:home) { create(:home, name: 'Main House') }
  let(:room) { create(:room, home: home) }
  let(:accessory) { create(:accessory, room: room, name: 'Living Room Light') }
  let!(:scene1) { create(:scene, name: 'Good Morning', home: home) }
  let!(:scene2) { create(:scene, name: 'Movie Night', home: home) }

  before do
    SceneAccessory.create!(scene: scene1, accessory: accessory)
  end

  describe 'viewing scenes index' do
    it 'displays all scenes' do
      visit scenes_path

      expect(page).to have_content('Scenes')
      expect(page).to have_content('Good Morning')
      expect(page).to have_content('Movie Night')
    end

    it 'shows scene card details' do
      visit scenes_path

      expect(page).to have_content('1 accessories')
      expect(page).to have_button('Execute')
    end

    it 'displays empty state when no scenes' do
      Scene.destroy_all
      visit scenes_path

      expect(page).to have_content('No scenes configured')
      expect(page).to have_content('Apple Home app')
    end

    it 'filters by home' do
      home2 = create(:home, name: 'Beach House')
      create(:scene, name: 'Beach Party', home: home2)

      visit scenes_path

      expect(page).to have_content('Good Morning')
      expect(page).to have_content('Beach Party')

      visit scenes_path(home_id: home.id)

      expect(page).to have_content('Good Morning')
      expect(page).not_to have_content('Beach Party')
    end

    it 'searches by name' do
      visit scenes_path(search: 'Morning')

      expect(page).to have_content('Good Morning')
      expect(page).not_to have_content('Movie Night')
    end
  end

  describe 'viewing scene details' do
    it 'displays scene information' do
      visit scene_path(scene1)

      expect(page).to have_content('Good Morning')
      expect(page).to have_content('Main House')
      expect(page).to have_content('Living Room Light')
      expect(page).to have_content(scene1.uuid)
    end

    it 'shows execution history' do
      ControlEvent.create!(
        scene: scene1,
        action_type: 'execute_scene',
        success: true,
        latency_ms: 150.0,
        source: 'web',
        request_id: SecureRandom.uuid
      )

      visit scene_path(scene1)

      expect(page).to have_content('Execution History')
      expect(page).to have_content('Success')
      expect(page).to have_content('150')
    end

    it 'shows empty history message' do
      visit scene_path(scene1)

      expect(page).to have_content('No execution history')
    end
  end
end
