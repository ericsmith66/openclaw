class AccountBalanceSnapshot < ApplicationRecord
  belongs_to :account

  validates :snapshot_date, presence: true
  validates :account_id, uniqueness: { scope: :snapshot_date }

  scope :for_date, ->(date) { where(snapshot_date: date) }
  scope :for_date_range, ->(start_date, end_date) { where(snapshot_date: start_date..end_date).order(:snapshot_date) }
  scope :latest, -> { order(snapshot_date: :desc).limit(1) }
  scope :liabilities, -> { joins(:account).where(accounts: { type: %w[credit loan] }) }

  def utilized_balance
    return nil unless limit.present? && available_balance.present?
    limit - available_balance
  end

  def utilization_rate
    return nil unless limit.present? && limit.to_d > 0
    utilized = utilized_balance
    return nil if utilized.nil?

    (utilized / limit * 100).round(2)
  end
end
