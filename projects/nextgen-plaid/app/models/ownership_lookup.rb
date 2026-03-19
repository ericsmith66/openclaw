class OwnershipLookup < ApplicationRecord
  has_many :accounts, dependent: :restrict_with_error

  OWNERSHIP_TYPES = %w[Individual Trust Other].freeze

  validates :name, presence: true
  validates :ownership_type, presence: true, inclusion: { in: OWNERSHIP_TYPES }
end
