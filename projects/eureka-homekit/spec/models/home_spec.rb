require 'rails_helper'

RSpec.describe Home, type: :model do
  describe 'associations' do
    it { should have_many(:rooms).dependent(:destroy) }
    it { should have_many(:scenes).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:home) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:uuid) }
    it { should validate_uniqueness_of(:uuid) }
  end

  describe 'cascade deletion' do
    it 'destroys associated rooms when home is destroyed' do
      home = create(:home)
      room = create(:room, home: home)

      expect { home.destroy }.to change(Room, :count).by(-1)
    end

    it 'destroys associated scenes when home is destroyed' do
      home = create(:home)
      scene = create(:scene, home: home)

      expect { home.destroy }.to change(Scene, :count).by(-1)
    end
  end
end
