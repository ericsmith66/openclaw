# frozen_string_literal: true

module Transactions
  # Renders a single transaction row with type-specific styling.
  # Supports recurring badges, security icons, transfer direction arrows,
  # and view-specific column rendering.
  class RowComponent < ViewComponent::Base
    include Rails.application.routes.url_helpers
    def initialize(transaction:, show_investment_columns: false, view_type: "cash")
      @transaction = transaction
      @show_investment_columns = show_investment_columns
      @view_type = view_type.to_s
    end

    # DaisyUI color classes based on amount positive/negative
    def amount_class
      return "text-success" if transaction.amount.to_f.positive?
      return "text-error" if transaction.amount.to_f.negative?
      "text-base-content"
    end

    # Badge component for transaction type
    def type_badge
      type = transaction_type
      case type
      when "InvestmentTransaction"
        "badge badge-primary badge-sm"
      when "CreditTransaction"
        "badge badge-secondary badge-sm"
      when "RegularTransaction"
        "badge badge-accent badge-sm"
      else
        "badge badge-outline badge-sm"
      end
    end

    # Formatted date consistent across app
    def formatted_date
      return "—" unless transaction.date.present?

      date = transaction.date.is_a?(String) ? Date.parse(transaction.date) : transaction.date
      date.strftime("%b %-d, %Y")
    rescue ArgumentError
      transaction.date.to_s
    end

    # Human-readable type label
    def type_label
      type = transaction_type
      case type
      when "InvestmentTransaction" then "Investment"
      when "CreditTransaction" then "Credit"
      when "RegularTransaction" then "Cash"
      else
        type.to_s.titleize
      end
    end

    # Format amount with currency symbol
    # For transfers: always show positive (absolute) value per feedback
    def formatted_amount
      amount = transaction.amount.to_f
      amount = amount.abs if transfers_view?
      number_to_currency(amount)
    end

    # Determine transaction type from fields
    def transaction_type
      transaction.type.presence || transaction.try(:_type).presence || "RegularTransaction"
    end

    # Determine if transaction is pending
    def pending?
      transaction.pending == true || transaction.pending == "true"
    end

    # Check if transaction is investment type
    def investment?
      transaction_type == "InvestmentTransaction"
    end

    # Check if transaction is marked as recurring
    def recurring?
      transaction.respond_to?(:is_recurring) && transaction.is_recurring == true
    end

    # Format quantity with precision
    def formatted_quantity
      return unless investment?
      quantity = transaction.quantity.to_f
      quantity.zero? ? "—" : quantity.to_s
    end

    # Format price as currency
    def formatted_price
      return unless investment?
      price = transaction.price.to_f
      price.zero? ? "—" : number_to_currency(price)
    end

    # Security name or ID
    def security_display
      return unless investment?
      transaction.try(:security_name).presence || transaction.security_id.presence || "—"
    end

    # Security icon: letter avatar fallback
    def security_initial
      name = transaction.try(:security_name).to_s.strip
      name.present? ? name[0].upcase : "?"
    end

    # Stub URL for security detail page
    def security_link
      sid = transaction.try(:security_id).presence || transaction.try(:security_name).to_s.parameterize
      portfolio_security_path(sid)
    end

    # Merchant icon: letter avatar fallback
    def merchant_initial
      name = transaction.try(:merchant_name).to_s.strip
      name.present? ? name[0].upcase : "?"
    end

    # Transfer-specific helpers
    def transfers_view?
      @view_type == "transfers"
    end

    def investments_view?
      @view_type == "investments"
    end

    def credit_view?
      @view_type == "credit"
    end

    def show_merchant_column?
      !investments_view? && !transfers_view?
    end

    # Transfer direction: outbound (negative amount) or inbound (positive)
    def transfer_outbound?
      transaction.amount.to_f.negative?
    end

    # Opposite account name from matched pair (set by TransferDeduplicator)
    def opposite_account_name
      transaction.instance_variable_get(:@_matched_opposite_account_name).to_s
    end

    # From account (source of transfer)
    def transfer_from
      if transfer_outbound?
        transaction.account&.name.to_s
      else
        opposite_account_name.presence || transaction.try(:target_account_name).to_s
      end
    end

    # To account (destination)
    def transfer_to
      if transfer_outbound?
        opposite_account_name.presence || transaction.try(:target_account_name).to_s
      else
        transaction.account&.name.to_s
      end
    end

    # Badge for external vs internal transfer
    def transfer_badge
      # Use @_external flag if set by TransferDeduplicator, otherwise use heuristic
      if transaction.instance_variable_defined?(:@_external)
        external = transaction.instance_variable_get(:@_external)
        return { class: "badge badge-warning badge-sm", label: "External" } if external
        return { class: "badge badge-ghost badge-sm", label: "Internal" }
      end

      target = transaction.try(:target_account_name).to_s.downcase
      # Simple heuristic: if target contains "external" or is not a known internal account
      if target.include?("external") || target.blank?
        { class: "badge badge-warning badge-sm", label: "External" }
      else
        { class: "badge badge-ghost badge-sm", label: "Internal" }
      end
    end

    # Subtype badge for investment transactions (Buy/Sell/Dividend/Interest/Split)
    def subtype_badge
      return unless investment?
      subtype = transaction.subtype.to_s.strip
      return nil if subtype.empty?

      case subtype.downcase
      when "buy"
        { class: "badge badge-success badge-xs", label: "Buy" }
      when "sell"
        { class: "badge badge-error badge-xs", label: "Sell" }
      when "dividend"
        { class: "badge badge-info badge-xs", label: "Dividend" }
      when "interest"
        { class: "badge badge-purple badge-xs", label: "Interest" }
      when "split"
        { class: "badge badge-gray badge-xs", label: "Split" }
      else
        { class: "badge badge-outline badge-xs", label: subtype.titlecase }
      end
    end

    # Category label from personal_finance_category_label
    # For cash view, show first segment before "→"
    def category_label
      return unless cash_view?
      label = transaction.personal_finance_category_label
      return nil unless label

      # First segment before "→"
      label.split("→").first.strip.presence
    end

    # Check if transaction has external flag (from TransferDeduplicator)
    def external?
      transaction.instance_variable_defined?(:@_external) &&
        transaction.instance_variable_get(:@_external) == true
    end

    private

    attr_reader :transaction, :show_investment_columns, :view_type

    def cash_view?
      @view_type == "cash" || @view_type == "regular"
    end
  end
end
