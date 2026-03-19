class Admin::OwnershipLookupsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ownership_lookup, only: %i[show edit update destroy]

  def index
    authorize OwnershipLookup
    @ownership_lookups = policy_scope(OwnershipLookup).order(:name).page(params[:page]).per(25)
  end

  def show
    authorize @ownership_lookup
  end

  def new
    @ownership_lookup = OwnershipLookup.new
    authorize @ownership_lookup
  end

  def create
    @ownership_lookup = OwnershipLookup.new(ownership_lookup_params)
    authorize @ownership_lookup

    if @ownership_lookup.save
      redirect_to admin_ownership_lookup_path(@ownership_lookup), notice: "Ownership lookup was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @ownership_lookup
  end

  def update
    authorize @ownership_lookup

    if @ownership_lookup.update(ownership_lookup_params)
      redirect_to admin_ownership_lookup_path(@ownership_lookup), notice: "Ownership lookup was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @ownership_lookup

    if @ownership_lookup.destroy
      redirect_to admin_ownership_lookups_path, notice: "Ownership lookup was successfully deleted."
    else
      redirect_to admin_ownership_lookup_path(@ownership_lookup), alert: @ownership_lookup.errors.full_messages.to_sentence
    end
  end

  private

  def set_ownership_lookup
    @ownership_lookup = OwnershipLookup.find(params[:id])
  end

  def ownership_lookup_params
    params.require(:ownership_lookup).permit(:name, :ownership_type, :details)
  end
end
