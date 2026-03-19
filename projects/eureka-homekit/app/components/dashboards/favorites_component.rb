# frozen_string_literal: true

module Dashboards
  class FavoritesComponent < ViewComponent::Base
    def initialize(accessories:, favorites: [])
      @accessories = accessories
      @favorites = favorites
    end

    def empty?
      @favorites.blank?
    end

    def favorite_accessories
      return [] if @favorites.blank?

      # Return accessories in the order defined by favorites
      accessories_by_uuid = @accessories.index_by(&:uuid)
      @favorites.filter_map { |uuid| accessories_by_uuid[uuid] }
    end

    def all_accessories
      @accessories
    end

    def favorited?(accessory)
      @favorites.include?(accessory.uuid)
    end
  end
end
