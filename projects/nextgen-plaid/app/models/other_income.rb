class OtherIncome < ApplicationRecord
  belongs_to :user

  FREQUENCIES = %w[annual monthly quarterly one_time].freeze
  CATEGORIES = %w[employment_side interest_dividends rental capital_gains pension other].freeze

  validates :name, presence: true, length: { maximum: 100 }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :frequency, presence: true, inclusion: { in: FREQUENCIES }
  validates :category, inclusion: { in: CATEGORIES }, allow_nil: true
  validate :end_date_not_before_start_date

  def annualized_amount
    case frequency
    when "annual"
      amount
    when "monthly"
      amount * 12
    when "quarterly"
      amount * 4
    when "one_time"
      amount
    else
      0
    end
  end

  private

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?
    return if end_date >= start_date

    errors.add(:end_date, "must be on or after the start date")
  end
end
