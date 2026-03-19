# frozen_string_literal: true

class UserPreference < ApplicationRecord
  validates :session_id, presence: true, uniqueness: true

  def self.for_session(session_id)
    find_or_create_by(session_id: session_id.to_s)
  end

  def add_favorite(accessory_uuid)
    self.favorites ||= []
    return if favorites.include?(accessory_uuid)

    self.favorites << accessory_uuid
    self.favorites_order ||= []
    self.favorites_order << accessory_uuid
    save!
  end

  def remove_favorite(accessory_uuid)
    self.favorites&.delete(accessory_uuid)
    self.favorites_order&.delete(accessory_uuid)
    save!
  end

  def reorder_favorites(ordered_uuids)
    self.favorites_order = ordered_uuids.select { |uuid| favorites.include?(uuid) }
    save!
  end

  def ordered_favorites
    return [] if favorites.blank?

    if favorites_order.present?
      # Return ordered, then append any that aren't in the order list
      ordered = favorites_order.select { |uuid| favorites.include?(uuid) }
      unordered = favorites - ordered
      ordered + unordered
    else
      favorites
    end
  end
end
