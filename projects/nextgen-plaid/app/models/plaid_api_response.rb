# app/models/plaid_api_response.rb
class PlaidApiResponse < ApplicationRecord
  belongs_to :plaid_api_call
  belongs_to :plaid_item

  validates :product, presence: true
  validates :endpoint, presence: true
  validates :called_at, presence: true

  def self.serialize_payload(obj)
    return obj if obj.is_a?(Hash) || obj.is_a?(Array)

    if obj.respond_to?(:to_hash)
      obj.to_hash
    elsif obj.respond_to?(:as_json)
      obj.as_json
    else
      JSON.parse(obj.to_json)
    end
  rescue StandardError
    { "_serialization_error" => true, "class" => obj.class.name }
  end
end
