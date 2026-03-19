# frozen_string_literal: true

class SavedAccountFilterSelectorComponent < ViewComponent::Base
  def initialize(saved_account_filters:, selected_id:, base_params:, turbo_frame_id: nil, label: "Accounts", holdings_path_helper: nil, path_helper: nil)
    @saved_account_filters = Array(saved_account_filters)
    @selected_id = selected_id.presence
    @base_params = base_params.to_h
    @turbo_frame_id = turbo_frame_id
    @label = label
    @path_helper = path_helper || holdings_path_helper || :net_worth_holdings_path
  end

  private

  attr_reader :saved_account_filters, :selected_id, :base_params, :turbo_frame_id, :label, :path_helper

  def target_path(params)
    public_send(path_helper, params)
  end

  def selected_filter
    return nil if selected_id.blank?

    saved_account_filters.find { |f| f.id.to_s == selected_id.to_s }
  end

  def selected_label
    selected_filter&.name || "All Accounts"
  end

  def link_params(filter_id)
    params = base_params.dup
    params.delete(:saved_account_filter_id)
    params.delete("saved_account_filter_id")
    params[:saved_account_filter_id] = filter_id if filter_id.present?
    params
  end
end
