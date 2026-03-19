# frozen_string_literal: true

require "test_helper"

class SavedAccountFilterTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  test "requires name" do
    filter = @user.saved_account_filters.new(criteria: { "ownership_types" => [ "Trust" ] })
    assert_not filter.valid?
    assert_includes filter.errors[:name], "can't be blank"
  end

  test "requires criteria with at least one supported key" do
    filter = @user.saved_account_filters.new(name: "Empty", criteria: {})
    assert_not filter.valid?
    assert_includes filter.errors[:criteria], "must include at least one filter criteria"
  end

  test "enforces name uniqueness per user" do
    @user.saved_account_filters.create!(name: "My Filter", criteria: { "ownership_types" => [ "Trust" ] })

    dupe = @user.saved_account_filters.new(name: "My Filter", criteria: { "ownership_types" => [ "Individual" ] })
    assert_not dupe.valid?
    assert_includes dupe.errors[:name], "has already been taken"
  end

  test "allows same name for different users" do
    @user.saved_account_filters.create!(name: "Same Name", criteria: { "ownership_types" => [ "Trust" ] })

    other = users(:two)
    ok = other.saved_account_filters.new(name: "Same Name", criteria: { "ownership_types" => [ "Trust" ] })
    assert ok.valid?
  end
end
