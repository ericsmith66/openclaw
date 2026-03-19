class ScenesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :execute ]

  SCENE_CACHE_TTL = 5.minutes

  def index
    cache_key = "scenes:index:#{params[:home_id]}:#{params[:search]}"

    @scenes = Rails.cache.fetch(cache_key, expires_in: SCENE_CACHE_TTL) do
      scenes = Scene.includes(:home, :accessories).all

      # Filter by home
      if params[:home_id].present?
        scenes = scenes.where(home_id: params[:home_id])
      end

      # Search by name
      if params[:search].present?
        scenes = scenes.where("name ILIKE ?", "%#{params[:search]}%")
      end

      scenes.order(name: :asc).to_a
    end

    @homes = Home.all # for filter dropdown
  end

  def show
    @scene = Scene.includes(:home, :accessories).find(params[:id])
    @execution_history = ControlEvent.for_scene(@scene.id).recent.limit(20)
  end

  def execute
    @scene = Scene.find(params[:id])

    result = PrefabControlService.trigger_scene(
      scene: @scene,
      user_ip: request.remote_ip
    )

    if result[:success]
      render json: { success: true, message: "Scene '#{@scene.name}' executed successfully" }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("Scene execution error: #{e.message}")
    render json: { success: false, error: "Unexpected error" }, status: :internal_server_error
  end
end
