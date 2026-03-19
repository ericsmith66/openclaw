# frozen_string_literal: true

require "test_helper"

class SavedAccountFilterSelectorComponentTest < ViewComponent::TestCase
  def test_renders_all_accounts_and_filters
    user = users(:one)
    f1 = user.saved_account_filters.create!(name: "Trust", criteria: { "ownership_types" => [ "Trust" ] })
    f2 = user.saved_account_filters.create!(name: "Individual", criteria: { "ownership_types" => [ "Individual" ] })

    rendered = render_inline(SavedAccountFilterSelectorComponent.new(
      saved_account_filters: [ f1, f2 ],
      selected_id: f2.id,
      base_params: { expanded: true, sort: "value", dir: "desc" },
      turbo_frame_id: "holdings-summary-frame"
    ))

    assert_includes rendered.text, "Accounts:"
    assert_includes rendered.text, "All Accounts"
    assert_includes rendered.text, "Trust"
    assert_includes rendered.text, "Individual"
  end

  def test_renders_with_path_helper
    user = users(:one)
    f1 = user.saved_account_filters.create!(name: "Test", criteria: { "account_ids" => [ "1" ] })

    rendered = render_inline(SavedAccountFilterSelectorComponent.new(
      saved_account_filters: [ f1 ],
      selected_id: nil,
      base_params: {},
      turbo_frame_id: "test-frame",
      path_helper: :transactions_regular_path
    ))

    assert_includes rendered.text, "All Accounts"
    assert_includes rendered.text, "Test"
  end

  def test_all_accounts_link_href_excludes_filter_id
    user = users(:one)
    f1 = user.saved_account_filters.create!(name: "Trust", criteria: { "ownership_types" => [ "Trust" ] })

    rendered = render_inline(SavedAccountFilterSelectorComponent.new(
      saved_account_filters: [ f1 ],
      selected_id: f1.id,
      base_params: { saved_account_filter_id: f1.id.to_s },
      turbo_frame_id: "holdings-summary-frame"
    ))

    all_accounts_link = rendered.css("a").find { |a| a.text.strip == "All Accounts" }
    assert all_accounts_link, "Expected 'All Accounts' link"
    refute_includes all_accounts_link["href"], "saved_account_filter_id", "All Accounts link should not include saved_account_filter_id"
  end

  def test_filter_link_href_includes_filter_id
    user = users(:one)
    f1 = user.saved_account_filters.create!(name: "Trust", criteria: { "ownership_types" => [ "Trust" ] })

    rendered = render_inline(SavedAccountFilterSelectorComponent.new(
      saved_account_filters: [ f1 ],
      selected_id: nil,
      base_params: {},
      turbo_frame_id: "holdings-summary-frame"
    ))

    trust_link = rendered.css("a").find { |a| a.text.strip == "Trust" }
    assert trust_link, "Expected 'Trust' filter link"
    assert_includes trust_link["href"], "saved_account_filter_id=#{f1.id}", "Filter link should include saved_account_filter_id"
  end
end
