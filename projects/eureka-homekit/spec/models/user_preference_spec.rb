# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserPreference, type: :model do
  describe 'validations' do
    it 'requires session_id' do
      pref = UserPreference.new(session_id: nil)
      expect(pref).not_to be_valid
      expect(pref.errors[:session_id]).to include("can't be blank")
    end

    it 'requires unique session_id' do
      create(:user_preference, session_id: 'unique-session')
      duplicate = build(:user_preference, session_id: 'unique-session')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:session_id]).to include('has already been taken')
    end

    it 'is valid with a session_id' do
      pref = build(:user_preference)
      expect(pref).to be_valid
    end
  end

  describe '.for_session' do
    it 'creates a new preference for a new session' do
      expect {
        UserPreference.for_session('new-session-123')
      }.to change(UserPreference, :count).by(1)
    end

    it 'returns existing preference for known session' do
      existing = create(:user_preference, session_id: 'existing-session')
      result = UserPreference.for_session('existing-session')
      expect(result).to eq(existing)
    end

    it 'converts session_id to string' do
      pref = UserPreference.for_session(12345)
      expect(pref.session_id).to eq('12345')
    end

    it 'initializes with empty favorites' do
      pref = UserPreference.for_session('fresh-session')
      expect(pref.favorites).to eq([])
      expect(pref.favorites_order).to eq([])
    end
  end

  describe '#add_favorite' do
    let(:pref) { create(:user_preference) }

    it 'adds an accessory UUID to favorites' do
      pref.add_favorite('acc-uuid-1')
      expect(pref.reload.favorites).to include('acc-uuid-1')
    end

    it 'adds to favorites_order as well' do
      pref.add_favorite('acc-uuid-1')
      expect(pref.reload.favorites_order).to include('acc-uuid-1')
    end

    it 'does not add duplicate favorites' do
      pref.add_favorite('acc-uuid-1')
      pref.add_favorite('acc-uuid-1')
      expect(pref.reload.favorites.count('acc-uuid-1')).to eq(1)
    end

    it 'preserves existing favorites' do
      pref.add_favorite('acc-uuid-1')
      pref.add_favorite('acc-uuid-2')
      expect(pref.reload.favorites).to eq([ 'acc-uuid-1', 'acc-uuid-2' ])
    end

    it 'persists to database' do
      pref.add_favorite('acc-uuid-1')
      expect(pref.reload.favorites).to include('acc-uuid-1')
    end
  end

  describe '#remove_favorite' do
    let(:pref) { create(:user_preference, favorites: [ 'acc-1', 'acc-2', 'acc-3' ], favorites_order: [ 'acc-1', 'acc-2', 'acc-3' ]) }

    it 'removes the UUID from favorites' do
      pref.remove_favorite('acc-2')
      expect(pref.reload.favorites).to eq([ 'acc-1', 'acc-3' ])
    end

    it 'removes the UUID from favorites_order' do
      pref.remove_favorite('acc-2')
      expect(pref.reload.favorites_order).to eq([ 'acc-1', 'acc-3' ])
    end

    it 'does nothing when UUID is not in favorites' do
      pref.remove_favorite('nonexistent')
      expect(pref.reload.favorites).to eq([ 'acc-1', 'acc-2', 'acc-3' ])
    end

    it 'persists to database' do
      pref.remove_favorite('acc-1')
      expect(pref.reload.favorites).not_to include('acc-1')
    end
  end

  describe '#reorder_favorites' do
    let(:pref) { create(:user_preference, favorites: [ 'acc-1', 'acc-2', 'acc-3' ], favorites_order: [ 'acc-1', 'acc-2', 'acc-3' ]) }

    it 'sets the favorites_order to the new order' do
      pref.reorder_favorites([ 'acc-3', 'acc-1', 'acc-2' ])
      expect(pref.reload.favorites_order).to eq([ 'acc-3', 'acc-1', 'acc-2' ])
    end

    it 'filters out UUIDs not in favorites' do
      pref.reorder_favorites([ 'acc-3', 'nonexistent', 'acc-1' ])
      expect(pref.reload.favorites_order).to eq([ 'acc-3', 'acc-1' ])
    end

    it 'persists to database' do
      pref.reorder_favorites([ 'acc-2', 'acc-1', 'acc-3' ])
      expect(pref.reload.favorites_order).to eq([ 'acc-2', 'acc-1', 'acc-3' ])
    end
  end

  describe '#ordered_favorites' do
    it 'returns empty array when no favorites' do
      pref = create(:user_preference)
      expect(pref.ordered_favorites).to eq([])
    end

    it 'returns favorites in order when favorites_order is set' do
      pref = create(:user_preference,
        favorites: [ 'acc-1', 'acc-2', 'acc-3' ],
        favorites_order: [ 'acc-3', 'acc-1', 'acc-2' ]
      )
      expect(pref.ordered_favorites).to eq([ 'acc-3', 'acc-1', 'acc-2' ])
    end

    it 'returns favorites as-is when no order is set' do
      pref = create(:user_preference,
        favorites: [ 'acc-1', 'acc-2' ],
        favorites_order: []
      )
      expect(pref.ordered_favorites).to eq([ 'acc-1', 'acc-2' ])
    end

    it 'appends unordered favorites to the end' do
      pref = create(:user_preference,
        favorites: [ 'acc-1', 'acc-2', 'acc-3' ],
        favorites_order: [ 'acc-2' ]
      )
      expect(pref.ordered_favorites).to eq([ 'acc-2', 'acc-1', 'acc-3' ])
    end

    it 'excludes ordered UUIDs that are no longer in favorites' do
      pref = create(:user_preference,
        favorites: [ 'acc-1', 'acc-3' ],
        favorites_order: [ 'acc-3', 'acc-2', 'acc-1' ]
      )
      expect(pref.ordered_favorites).to eq([ 'acc-3', 'acc-1' ])
    end
  end
end
