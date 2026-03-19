# frozen_string_literal: true

module DefaultDateRange
  extend ActiveSupport::Concern

  private

  def apply_default_date_range
    @date_from = params[:date_from].presence || Date.current.beginning_of_month.iso8601
    @date_to   = params[:date_to].presence   || Date.current.end_of_month.iso8601
  end
end
