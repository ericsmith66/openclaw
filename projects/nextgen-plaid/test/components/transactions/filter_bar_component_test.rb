# frozen_string_literal: true

require "test_helper"

module Transactions
  class FilterBarComponentTest < ViewComponent::TestCase
    test "renders filter form with default values" do
      render_inline(FilterBarComponent.new)
      assert_selector "form[method='get']"
      assert_selector "input[name='search_term']"
      assert_no_selector "select[name='type_filter']" # Removed in Phase 4C
      assert_selector "input[name='date_from']"
      assert_selector "input[name='date_to']"
      assert_selector "input[type='submit'][value='Apply']"
      assert_selector "a", text: "Clear"
    end

    test "account filter is no longer in filter bar (moved to SavedAccountFilterSelectorComponent)" do
      render_inline(FilterBarComponent.new)
      assert_no_selector "select[name='account']"
    end

    test "no account dropdown rendered in filter bar" do
      render_inline(FilterBarComponent.new)
      assert_no_selector "select[name='account']"
    end

    test "search placeholder changes based on view type for cash" do
      render_inline(FilterBarComponent.new(view_type: "cash"))
      assert_selector "input[name='search_term'][placeholder='Search by name, merchant…']"
    end

    test "search placeholder changes based on view type for investments" do
      render_inline(FilterBarComponent.new(view_type: "investments"))
      assert_selector "input[name='search_term'][placeholder='Search by name, security…']"
    end

    test "search placeholder changes based on view type for credit" do
      render_inline(FilterBarComponent.new(view_type: "credit"))
      assert_selector "input[name='search_term'][placeholder='Search by name, merchant…']"
    end

    test "search placeholder changes based on view type for transfers" do
      render_inline(FilterBarComponent.new(view_type: "transfers"))
      assert_selector "input[name='search_term'][placeholder='Search by name, merchant…']"
    end

    test "filter bar is sticky" do
      render_inline(FilterBarComponent.new)
      assert_selector "div.sticky"
    end

    test "populates form with provided values" do
      render_inline(
        FilterBarComponent.new(
          search_term: "test",
          date_from: "2026-01-01",
          date_to: "2026-01-31"
        )
      )

      assert_selector "input[name='search_term'][value='test']"
      assert_no_selector "select[name='type_filter']" # Removed in Phase 4C
      assert_selector "input[name='date_from'][value='2026-01-01']"
      assert_selector "input[name='date_to'][value='2026-01-31']"
      assert_no_selector "select[name='account']"
    end
  end
end
