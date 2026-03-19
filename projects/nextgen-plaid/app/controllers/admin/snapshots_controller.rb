# frozen_string_literal: true

module Admin
  class SnapshotsController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :require_admin!

    def index
      @snapshots = FinancialSnapshot
        .includes(:user)
        .order(snapshot_at: :desc)
        .page(params[:page])
        .per(50)
    end

    def show
      @snapshot = FinancialSnapshot.includes(:user).find(params[:id])
      @pretty_json = JSON.pretty_generate(@snapshot.data)
    end

    private

    def require_admin!
      head :forbidden unless current_user&.admin?
    end
  end
end
