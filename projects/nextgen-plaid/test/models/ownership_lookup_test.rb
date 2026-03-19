require "test_helper"

class OwnershipLookupTest < ActiveSupport::TestCase
  test "ownership_type defaults to Other" do
    lookup = OwnershipLookup.create!(name: "Default Type")
    assert_equal "Other", lookup.ownership_type
  end

  test "ownership_type must be in the allowed list" do
    lookup = OwnershipLookup.new(name: "Bad Type", ownership_type: "Nope")
    assert_not lookup.valid?
    assert_includes lookup.errors[:ownership_type], "is not included in the list"
  end
end
