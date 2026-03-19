class Holding < ApplicationRecord
  belongs_to :account
  has_one :fixed_income, dependent: :destroy
  has_one :option_contract, dependent: :destroy

  # Enrichment is stored per-security in `SecurityEnrichment` (PRD-1-09 Option B).

  has_one :security_enrichment,
          primary_key: :security_id,
          foreign_key: :security_id,
          inverse_of: :holdings

  # PRD 10: Disable STI — type column is for security type data, not inheritance
  self.inheritance_column = :_type_disabled

  # CSV-2: Source enum for tracking data origin
  attribute :source, :integer, default: 0
  enum :source, { plaid: 0, csv: 1 }

  validates :security_id, presence: true
  validates :security_id, uniqueness: { scope: [ :account_id, :source ] }

  # CSV-2: Validations for CSV imports
  validates :symbol, presence: true, if: :csv?
  validates :quantity, presence: true, if: :csv?
  validates :market_value, presence: true, if: :csv?

  after_commit :invalidate_portfolio_cache, on: [ :create, :update, :destroy ]

  def latest_enrichment_record
    security_enrichment
  end

  def latest_enrichment_data
    security_enrichment&.data || {}
  end

  def latest_consensus
    latest_enrichment_data["analyst_consensus"].presence
  end

  def target_upside_percent
    latest_enrichment_data["target_upside_percent"]
  end

  # Decimal fields that require fixed notation formatting
  DECIMAL_FIELDS = %w[quantity cost_basis market_value vested_value institution_price].freeze

  # Formatting methods for decimal fields to avoid scientific notation
  def quantity_s
    quantity&.to_s("F")
  end

  def cost_basis_s
    cost_basis&.to_s("F")
  end

  def market_value_s
    market_value&.to_s("F")
  end

  def vested_value_s
    vested_value&.to_s("F")
  end

  def institution_price_s
    institution_price&.to_s("F")
  end

  # Override inspect to show fixed decimal notation in console
  def inspect
    attrs = attributes.map do |k, v|
      if DECIMAL_FIELDS.include?(k) && v.is_a?(BigDecimal)
        "#{k}: #{v.to_s('F')}"
      else
        "#{k}: #{v.inspect}"
      end
    end.join(", ")
    "#<Holding #{attrs}>"
  end

  private

  def invalidate_portfolio_cache
    user_id = account&.plaid_item&.user_id
    return if user_id.blank?

    Rails.cache.increment("holdings_totals:v1:user:#{user_id}:version", 1, initial: 0)

    # `delete_matched` expects a Regexp; passing a glob-like string does not work
    # reliably across cache stores.
    Rails.cache.delete_matched(/\Aholdings_totals:v1:user:#{user_id}:/)
  end
end
