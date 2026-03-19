class SimulationsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner

  def index
  end
end
