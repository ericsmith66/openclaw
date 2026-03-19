class HealthController < ApplicationController
  # No authentication required — protected by HEALTH_TOKEN only
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_environment_banner, raise: false
  skip_before_action :prevent_authenticated_page_caching, raise: false

  def show
    expected_token = ENV["HEALTH_TOKEN"].presence
    provided_token = params[:token].to_s

    # Fail closed if HEALTH_TOKEN is not configured
    if expected_token.nil?
      render json: { status: "error", message: "health check not configured" }, status: :service_unavailable
      return
    end

    # Timing-safe comparison to prevent token enumeration
    unless ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
      render json: { status: "error", message: "unauthorized" }, status: :unauthorized
      return
    end

    # Basic liveness check — DB connectivity
    ActiveRecord::Base.connection.execute("SELECT 1")

    render json: { status: "ok" }, status: :ok
  rescue => e
    render json: { status: "error", message: e.message }, status: :service_unavailable
  end
end
