class ApplicationController < ActionController::Base
  helper ApplicationHelper
  include Pundit::Authorization
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  protect_from_forgery with: :exception

  layout :set_layout

  # This is the official Devise fix for Rails 7+ / 8
  # Without this, Devise login succeeds but warden.user is nil
  before_action :authenticate_user!, if: :devise_controller?
  before_action :set_environment_banner
  before_action :prevent_authenticated_page_caching, if: :user_signed_in?

  private

  def set_layout
    return "application" unless user_signed_in?

    enabled = if Rails.env.production?
      ENV["ENABLE_NEW_LAYOUT"] == "true"
    else
      ENV.fetch("ENABLE_NEW_LAYOUT", "true") == "true"
    end

    enabled ? "authenticated" : "application"
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || authenticated_root_path)
  end

  def set_environment_banner
    return unless current_user
    env_label = Rails.env.production? ? "PRODUCTION" : "DEVELOPMENT"
    plaid_env = ENV["PLAID_ENV"]&.upcase || "SANDBOX"
    flash.now[:success] = "SECURE SESSION [#{env_label} | Plaid: #{plaid_env}]"
  end

  # Authenticated pages include an importmap with digested asset URLs.
  # If an intermediary cache (or the browser) serves stale HTML after a deploy,
  # the page can reference an old digest that no longer exists and trigger 404s.
  #
  # Prevent caching of authenticated HTML responses, while leaving `/assets/*`
  # cache headers to Propshaft/public file server.
  def prevent_authenticated_page_caching
    return unless request.get?
    return unless request.format&.html?

    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end

  def require_owner
    owner_email = ENV["OWNER_EMAIL"].presence || "ericsmith66@me.com"
    unless current_user && current_user.email == owner_email
      flash[:alert] = "You are not authorized to access Mission Control."
      redirect_to authenticated_root_path
    end
  end
end
