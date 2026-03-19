class WelcomeController < ApplicationController
  def index
    # Never expose debug/shortcut login UI outside of local development.
    # Public environments should go straight to the normal Devise sign-in.
    if !user_signed_in? && !Rails.env.development?
      redirect_to new_user_session_path
    end
  end
end
