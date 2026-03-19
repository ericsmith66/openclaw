class FavoritesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :toggle, :reorder ]
  def index
    pref = UserPreference.for_session(session.id.to_s)
    ordered_uuids = pref.ordered_favorites

    @controllable_accessories = Accessory.includes(:sensors, room: :home)
      .joins(:sensors)
      .where(sensors: { is_writable: true })
      .distinct
      .order(:name)

    @favorites = ordered_uuids
  end

  def toggle
    pref = UserPreference.for_session(session.id.to_s)
    uuid = params[:accessory_uuid]

    unless uuid.present?
      return render json: { success: false, error: "Missing accessory_uuid" }, status: :bad_request
    end

    if pref.favorites.include?(uuid)
      pref.remove_favorite(uuid)
      render json: { success: true, favorited: false }
    else
      pref.add_favorite(uuid)
      render json: { success: true, favorited: true }
    end
  end

  def reorder
    pref = UserPreference.for_session(session.id.to_s)
    ordered_uuids = params[:ordered_uuids]

    unless ordered_uuids.is_a?(Array)
      return render json: { success: false, error: "Missing ordered_uuids array" }, status: :bad_request
    end

    pref.reorder_favorites(ordered_uuids)
    render json: { success: true }
  end
end
