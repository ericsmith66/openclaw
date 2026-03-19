class SavedAccountFiltersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_saved_account_filter, only: [ :edit, :update, :destroy ]

  def index
    @saved_account_filters = current_user.saved_account_filters.order(created_at: :desc)
  end

  def new
    @saved_account_filter = current_user.saved_account_filters.new(
      criteria: {},
      context: params[:context].presence
    )
  end

  def create
    @saved_account_filter = current_user.saved_account_filters.new(saved_account_filter_params)
    apply_criteria_from_params(@saved_account_filter)

    if @saved_account_filter.errors.blank? && @saved_account_filter.save
      redirect_to saved_account_filters_path, notice: "Saved filter created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @saved_account_filter.assign_attributes(saved_account_filter_params)
    apply_criteria_from_params(@saved_account_filter)

    if @saved_account_filter.errors.blank? && @saved_account_filter.save
      redirect_to saved_account_filters_path, notice: "Saved filter updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @saved_account_filter.destroy
    redirect_to saved_account_filters_path, notice: "Saved filter deleted."
  end

  private

  def set_saved_account_filter
    @saved_account_filter = current_user.saved_account_filters.find(params[:id])
  end

  def saved_account_filter_params
    params.require(:saved_account_filter).permit(:name, :context)
  end

  def apply_criteria_from_params(record)
    raw = params.dig(:saved_account_filter, :criteria_json)
    return if raw.nil?

    json = raw.to_s.strip
    record.criteria = {} and return if json.blank?

    record.criteria = JSON.parse(json)
  rescue JSON::ParserError
    record.errors.add(:criteria, "must be valid JSON")
  end
end
