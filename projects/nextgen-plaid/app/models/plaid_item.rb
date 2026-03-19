# app/models/plaid_item.rb
class PlaidItem < ApplicationRecord
  belongs_to :user
  has_many :accounts, dependent: :destroy
  has_many :holdings, through: :accounts
  has_many :transactions, through: :accounts
  has_many :liabilities, through: :accounts
  has_many :recurring_transactions, dependent: :destroy
  has_many :sync_logs, dependent: :destroy
  has_many :webhook_logs, dependent: :destroy

  # PRD 6.1: Status enum for error handling
  enum :status, { good: "good", needs_reauth: "needs_reauth", failed: "failed" }

  INTENDED_PRODUCT_OPTIONS = %w[investments transactions liabilities].freeze

  # Epic-0 PRD-0030: a "successfully linked" item is one that is currently in good standing.
  scope :successfully_linked, -> { where(status: statuses[:good]) }

  # Epic-0 PRD-0010: sync/retry UX helpers
  MAX_RETRY_COUNT = 3
  RETRY_COOLDOWN = 2.minutes

  def intended_products_list
    intended_products.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def intended_for?(product)
    # Legacy items may have NULL/blank `intended_products`. Treat that as
    # "all products" so sync/retry/webhook flows remain backward-compatible.
    return true if intended_products.blank?

    intended_products_list.include?(product.to_s)
  end

  def sync_in_progress?
    # We don't have a first-class "in flight" state in the DB.
    # Use presence of a recent "started" log as a reasonable proxy.
    sync_logs.where(status: "started").where("created_at > ?", 10.minutes.ago).exists?
  end

  def retry_allowed?
    return false unless failed?
    return false if sync_in_progress?
    return false if retry_count.to_i >= MAX_RETRY_COUNT

    last_retry_at.blank? || last_retry_at <= RETRY_COOLDOWN.ago
  end

  # This is the correct, final version for 2025
  attr_encrypted :access_token,
                 key: ACCESS_TOKEN_ENCRYPTION_KEY,        # 32-byte binary key from initializer
                 attribute: "access_token_encrypted",     # write to the column you have
                 random_iv: true                          # use the _iv column we added

  attr_encrypted_encrypted_attributes

  validates :item_id, presence: true
  validates :institution_name, presence: true
  validates :status, presence: true
  validates :item_id, uniqueness: { scope: :user_id }
end
