class OtherIncomesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_other_income, only: [ :edit, :update, :destroy ]

  def index
    @other_incomes = current_user.other_incomes.order(order_clause_for_sort)
    @estimated_annual_total = @other_incomes.sum(&:annualized_amount)
  end

  def new
    @other_income = current_user.other_incomes.new
  end

  def edit
  end

  def create
    @other_income = current_user.other_incomes.new(other_income_params)

    if @other_income.save
      redirect_to other_incomes_path, notice: "Other income source added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @other_income.update(other_income_params)
      redirect_to other_incomes_path, notice: "Other income source updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @other_income.destroy
    redirect_to other_incomes_path, notice: "Other income source removed."
  end

  private

  def set_other_income
    @other_income = current_user.other_incomes.find(params[:id])
  end

  def order_clause_for_sort
    case params[:sort]
    when "amount_desc"
      { amount: :desc }
    when "updated_at_desc"
      { updated_at: :desc }
    else
      { name: :asc }
    end
  end

  def other_income_params
    params.require(:other_income).permit(:name, :amount, :frequency, :start_date, :end_date, :category, :taxable, :notes)
  end
end
