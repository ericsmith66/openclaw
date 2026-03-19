class SavedAccountFilter < ApplicationRecord
  SUPPORTED_CRITERIA_KEYS = %w[
    account_ids
    institution_ids
    ownership_types
    asset_strategy
    trust_code
    holder_category
  ].freeze

  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :criteria, presence: true
  validate :criteria_must_have_at_least_one_supported_key

  before_validation :normalize_criteria

  private

  def normalize_criteria
    self.criteria = {} if criteria.nil?
    self.criteria = criteria.to_h if criteria.respond_to?(:to_h)
  end

  def criteria_must_have_at_least_one_supported_key
    hash = criteria.is_a?(Hash) ? criteria : {}

    any_present = SUPPORTED_CRITERIA_KEYS.any? do |key|
      value = hash[key] || hash[key.to_sym]
      case value
      when Array
        value.any?
      when Hash
        value.present?
      else
        value.present?
      end
    end

    errors.add(:criteria, "must include at least one filter criteria") unless any_present
  end
end
