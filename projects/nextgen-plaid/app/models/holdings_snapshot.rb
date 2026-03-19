class HoldingsSnapshot < ApplicationRecord
  belongs_to :user
  belongs_to :account, optional: true

  validates :snapshot_data, presence: true

  scope :by_user, ->(user_id) { where(user_id: user_id) }
  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :by_date_range, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :recent_first, -> { order(created_at: :desc) }
  scope :user_level, -> { where(account_id: nil) }
  scope :account_level, -> { where.not(account_id: nil) }
end
