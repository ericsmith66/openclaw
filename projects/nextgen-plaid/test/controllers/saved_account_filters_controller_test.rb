# frozen_string_literal: true

require "test_helper"

class SavedAccountFiltersControllerTest < ActionDispatch::IntegrationTest
  test "index requires authentication" do
    get saved_account_filters_path
    assert_response :redirect
  end

  test "user cannot edit another user's filter" do
    user = users(:one)
    other = users(:two)

    filter = other.saved_account_filters.create!(
      name: "Other User Filter",
      criteria: { "ownership_types" => [ "Trust" ] }
    )

    sign_in user

    get edit_saved_account_filter_path(filter)
    assert_response :not_found
  end

  test "create parses criteria json" do
    user = users(:one)
    sign_in user

    assert_difference "SavedAccountFilter.count", 1 do
      post saved_account_filters_path, params: {
        saved_account_filter: {
          name: "Trust Accounts",
          context: "net_worth_holdings",
          criteria_json: { ownership_types: [ "Trust" ] }.to_json
        }
      }
    end

    filter = user.saved_account_filters.order(:created_at).last
    assert_equal [ "Trust" ], filter.criteria["ownership_types"]
  end

  test "create rejects invalid criteria json" do
    user = users(:one)
    sign_in user

    assert_no_difference "SavedAccountFilter.count" do
      post saved_account_filters_path, params: {
        saved_account_filter: {
          name: "Bad JSON",
          criteria_json: "{not json"
        }
      }
      assert_response :unprocessable_entity
    end
  end
end
