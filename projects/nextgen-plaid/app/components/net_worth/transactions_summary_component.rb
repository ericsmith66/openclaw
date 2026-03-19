# frozen_string_literal: true

module NetWorth
  class TransactionsSummaryComponent < BaseCardComponent
    def initialize(data:)
      @data = data.to_h
      @corrupt = false
    end

    def missing_data?
      month_hash.nil?
    end

    def corrupt?
      @corrupt
    end

    def income
      safe_to_f(safe_get(month_hash, :income, nil), default: 0.0)
    end

    def expenses
      safe_to_f(safe_get(month_hash, :expenses, nil), default: 0.0)
    end

    def net
      # Acceptance criteria: net reflects income - expenses
      income - expenses
    end

    def net_style
      net.to_f >= 0 ? "text-success" : "text-error"
    end

    def net_symbol
      net.to_f >= 0 ? "↑" : "↓"
    end

    def signed_currency(amount)
      formatted = number_to_currency(amount.to_f, precision: 0)
      amount.to_f >= 0 ? "+#{formatted}" : formatted
    end

    def expenses_currency
      formatted = number_to_currency(expenses.to_f.abs, precision: 0)
      "-#{formatted}"
    end

    def last_30_days_label
      "Last 30 days"
    end

    private

    def month_hash
      @month_hash ||= begin
        h = transactions_summary_hash
        month = safe_get(h, :month, nil)
        return nil if month.nil?
        return month.to_h if month.respond_to?(:to_h)

        raise TypeError, "transactions_summary.month is not hash-like"
      rescue StandardError => e
        log_error(e, message: "transactions summary month normalize failed")
        @corrupt = true
        nil
      end
    end

    def transactions_summary_hash
      raw = safe_get(@data, "transactions_summary", nil)
      return raw.to_h if raw.respond_to?(:to_h)

      # Backward compatibility: existing snapshots currently use `monthly_transaction_summary`
      legacy = safe_get(@data, "monthly_transaction_summary", nil)
      legacy_h = legacy.respond_to?(:to_h) ? legacy.to_h : {}
      {
        month: {
          income: safe_get(legacy_h, :income, 0.0),
          expenses: safe_get(legacy_h, :expenses, 0.0),
          net: safe_get(legacy_h, :net, nil)
        }
      }
    end

    def log_error(error, message:)
      tags = { epic: 3, prd: "3-15", component: self.class.name }

      if defined?(Sentry)
        Sentry.capture_exception(error, tags: tags, extra: { message: message })
      else
        Rails.logger.warn("#{message}: #{error.class} #{error.message} tags=#{tags}")
      end
    end
  end
end
