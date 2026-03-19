class TransactionsController < ApplicationController
  include DefaultDateRange

  before_action :authenticate_user!
  before_action :apply_default_date_range, only: [ :regular, :investment, :credit, :transfers, :summary ]
  before_action :set_saved_account_filters, only: [ :regular, :investment, :credit, :transfers, :summary ]
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy ]



  # GET /transactions
  def index
    @transactions = Transaction.includes(:account)
    # Filtering
    @transactions = @transactions.where(subtype: params[:subtype]) if params[:subtype].present?
    # Sorting (server-side, whitelist)
    sort_col = safe_sort_column(params[:sort])
    sort_dir = %w[asc desc].include?(params[:dir].to_s.downcase) ? params[:dir].to_s.downcase : "desc"
    @transactions = @transactions.order(Arel.sql("#{sort_col} #{sort_dir}"))
    @transactions = @transactions.page(params[:page]).per(25)
  end

  def regular
    permitted = params.permit!
    merged = permitted.merge(view_type: "regular", date_from: @date_from, date_to: @date_to)
    result = TransactionGridDataProvider.new(current_user, merged).call
    assign_from_result(result, merged)
  end

  def investment
    permitted = params.permit!
    merged = permitted.merge(view_type: "investment", date_from: @date_from, date_to: @date_to)
    result = TransactionGridDataProvider.new(current_user, merged).call
    assign_from_result(result, merged)
  end

  def credit
    permitted = params.permit!
    merged = permitted.merge(view_type: "credit", date_from: @date_from, date_to: @date_to)
    result = TransactionGridDataProvider.new(current_user, merged).call
    assign_from_result(result, merged)
  end

  def transfers
    permitted = params.permit!
    merged = permitted.merge(view_type: "transfers", date_from: @date_from, date_to: @date_to)
    result = TransactionGridDataProvider.new(current_user, merged).call

    # Apply TransferDeduplicator to deduplicate transfer legs
    # Only outbound legs (negative amounts) are kept; matched inbound legs are suppressed
    # NOTE: This loads all matching transactions into memory. When per_page=all is used,
    # this is the highest memory risk scenario. The warning threshold applies here as well.
    deduped = TransferDeduplicator.new(result.transactions).call

    @transactions = deduped
    @total_count = deduped.count
    @page = merged[:page].to_i
    @page = 1 if @page <= 0
    @per_page = merged[:per_page].presence || "25"
    @sort = merged[:sort].presence || "date"
    @dir = merged[:dir].presence || "desc"
    @type_filter = merged[:type_filter]
    @search_term = merged[:search_term]
    @date_from = merged[:date_from]
    @date_to = merged[:date_to]
    @summary = result.summary
    @warning = result.warning
  rescue => e
    Rails.logger.error "Transfers controller error: #{e.class.name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  def summary
    permitted = params.permit!
    merged = permitted.merge(summary_mode: true, date_from: @date_from, date_to: @date_to)
    result = TransactionGridDataProvider.new(current_user, merged).call

    @summary = result.summary
    @total_count = result.total_count
    @top_recurring = top_recurring_expenses
    @warning = result.warning
    @search_term = merged[:search_term]
    @date_from = merged[:date_from]
    @date_to = merged[:date_to]
  end

  # GET /transactions/1
  def show
  end

  # GET /transactions/new
  def new
    @transaction = Transaction.new
  end

  # GET /transactions/1/edit
  def edit
  end

  # POST /transactions
  def create
    @transaction = Transaction.new(transaction_params)

    if @transaction.save
      redirect_to @transaction, notice: "Transaction was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /transactions/1
  def update
    if @transaction.update(transaction_params)
      redirect_to @transaction, notice: "Transaction was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /transactions/1
  def destroy
    @transaction.destroy
    redirect_to transactions_url, notice: "Transaction was successfully destroyed."
  end

  private
    def set_transaction
      @transaction = Transaction.find(params[:id])
    end

    def transaction_params
      params.require(:transaction).permit(:account_id, :transaction_id, :amount, :date,
                                          :name, :merchant_name, :subtype, :category,
                                          :pending, :payment_channel)
    end

    # Only allow ordering by these columns to avoid SQL injection
    def safe_sort_column(param)
      allowed = {
        "date" => "date",
        "name" => "name",
        "amount" => "amount",
        "subtype" => "subtype",
        "fees" => "fees"
      }
      allowed[param.to_s] || "date"
    end

    # Assign common instance variables from processed data hash
    def assign_common_ivars(data)
      @transactions = data[:transactions]
      @total_count = data[:total_count]
      @page = data[:page]
      @per_page = data[:per_page]
      @sort = data[:sort]
      @dir = data[:dir]
      @type_filter = data[:type_filter]
      @search_term = data[:search_term]
      @date_from = data[:date_from]
      @date_to = data[:date_to]
    end

    # Assign common instance variables from TransactionGridDataProvider result
    def assign_from_result(result, params)
      @transactions = result.transactions
      @total_count = result.total_count
      @page = params[:page].to_i
      @page = 1 if @page <= 0
      @per_page = params[:per_page].presence || "25"
      @sort = params[:sort].presence || "date"
      @dir = params[:dir].presence || "desc"
      @type_filter = params[:type_filter]
      @search_term = params[:search_term]
      @date_from = params[:date_from]
      @date_to = params[:date_to]
      @summary = result.summary
      @warning = result.warning
    end






    def set_saved_account_filters
      @saved_account_filters = current_user.saved_account_filters.order(created_at: :desc)
      @saved_account_filter_id = params[:saved_account_filter_id].presence
    end

    def top_recurring_expenses
      recurring = RecurringTransaction
        .joins(:plaid_item)
        .where(plaid_items: { user_id: current_user.id })
        .where(stream_type: "outflow")
        .order(average_amount: :desc)
        .limit(5)

      recurring.map do |r|
        {
          description: r.description || r.merchant_name || "Unknown",
          merchant_name: r.merchant_name,
          frequency: r.frequency,
          average_amount: r.average_amount.to_f.abs,
          last_date: r.last_date
        }
      end
    end
end
