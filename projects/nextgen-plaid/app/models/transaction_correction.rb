class TransactionCorrection < ApplicationRecord
  belongs_to :original_transaction, class_name: "Transaction"
  belongs_to :corrected_transaction, class_name: "Transaction"

  validates :reason, presence: true
end
