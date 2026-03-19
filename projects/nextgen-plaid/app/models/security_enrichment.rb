class SecurityEnrichment < ApplicationRecord
  SOURCES = %w[fmp].freeze
  STATUSES = %w[pending success partial error].freeze

  # Non-FK association: many holdings can share the same Plaid `security_id`.
  has_many :holdings, primary_key: :security_id, foreign_key: :security_id, inverse_of: :security_enrichment

  validates :security_id, presence: true
  validates :security_id, uniqueness: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :enriched_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  def price_d
    price
  end

  def market_cap_i
    market_cap
  end

  def roe_d
    roe
  end

  def roa_d
    roa
  end

  def beta_d
    beta
  end

  def roic_d
    roic
  end
end
