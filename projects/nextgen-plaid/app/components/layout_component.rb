# frozen_string_literal: true

class LayoutComponent < ViewComponent::Base
  # @param title [String] Page title for breadcrumb display
  # @param current_user [User, nil] Current authenticated user
  # @param breadcrumb_segments [Array<Array(String, String)>] Array of [label, path] pairs for multi-level breadcrumbs
  # @param accounts [Array<String>] Account names for optional account filter dropdown in breadcrumb row
  # @param selected_account [String, nil] Currently selected account name
  # @param account_filter_path [String, nil] Form action path for account filter; nil hides the filter
  def initialize(title: "NextGen Wealth", current_user: nil, breadcrumb_segments: [],
                 accounts: [], selected_account: nil, account_filter_path: nil)
    @title = title
    @current_user = current_user
    @breadcrumb_segments = breadcrumb_segments
    @accounts = Array(accounts)
    @selected_account = selected_account.to_s
    @account_filter_path = account_filter_path
  end

  private

  def show_account_filter?
    @account_filter_path.present?
  end

  def account_options
    [ [ "All Accounts", "" ] ] + @accounts.map { |a| [ a, a ] }
  end
end
