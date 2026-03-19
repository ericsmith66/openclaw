# frozen_string_literal: true

# Minimal recurring transaction detection heuristic.
# Identifies transactions with the same merchant/security, near-identical amount,
# and roughly monthly interval (3+ occurrences).
# Forward-compatible: also respects Plaid's recurring flag if present.
module TransactionRecurringDetector
  # Amount tolerance: transactions within 5% of each other are "near-identical"
  AMOUNT_TOLERANCE = 0.05
  # Minimum occurrences to consider a pattern recurring
  MIN_OCCURRENCES = 3

  # Detect and mark recurring transactions in the collection.
  # Mutates each transaction's is_recurring attribute.
  # Returns the modified collection.
  def self.detect!(transactions)
    return transactions if transactions.blank?

    # Group by merchant/security name (normalized)
    groups = transactions.group_by { |txn| recurring_key(txn) }

    groups.each do |_key, group_txns|
      next if group_txns.size < MIN_OCCURRENCES

      # Check if amounts are near-identical
      amounts = group_txns.map { |t| t.amount.to_f.abs }
      median_amount = amounts.sort[amounts.size / 2]
      next if median_amount.zero?

      similar = group_txns.select do |t|
        amt = t.amount.to_f.abs
        (amt - median_amount).abs / median_amount <= AMOUNT_TOLERANCE
      end

      if similar.size >= MIN_OCCURRENCES
        similar.each { |t| t.is_recurring = true }
      end
    end

    # Also respect Plaid's recurring flag if present
    transactions.each do |txn|
      if txn.respond_to?(:recurring) && txn.recurring == true
        txn.is_recurring = true
      end
      # Ensure is_recurring is set to false if not already true
      txn.is_recurring = false unless txn.respond_to?(:is_recurring) && txn.is_recurring == true
    end

    transactions
  end

  # Extract top recurring expenses sorted by estimated yearly spend.
  # Returns array of hashes: { name:, frequency:, amount:, yearly_total: }
  def self.top_recurring(transactions, limit: 5)
    recurring = Array(transactions).select { |t| t.respond_to?(:is_recurring) && t.is_recurring == true }
    # Filter to expenses only (negative amounts) for "Top Recurring Expenses" card
    recurring = recurring.select { |t| t.amount.to_f.negative? }
    return [] if recurring.empty?

    # Group by merchant key and compute stats
    groups = recurring.group_by { |t| recurring_key(t) }

    results = groups.map do |key, txns|
      amounts = txns.map { |t| t.amount.to_f.abs }
      avg_amount = amounts.sum / amounts.size
      frequency = estimate_frequency(txns)
      yearly_multiplier = case frequency
      when "Weekly" then 52
      when "Biweekly" then 26
      when "Monthly" then 12
      when "Quarterly" then 4
      else 12 # default to monthly
      end
      {
        name: key,
        frequency: frequency,
        amount: avg_amount,
        yearly_total: avg_amount * yearly_multiplier
      }
    end

    results.sort_by { |r| -r[:yearly_total] }.first(limit)
  end

  # Private helpers

  def self.recurring_key(txn)
    (txn.merchant_name.presence || txn.security_name.presence || txn.name.to_s).strip.downcase
  end
  private_class_method :recurring_key

  def self.estimate_frequency(txns)
    return "Monthly" if txns.size < 2

    dates = txns.map do |t|
      d = t.date
      d.is_a?(String) ? Date.parse(d) : d
    rescue ArgumentError
      nil
    end.compact.sort

    return "Monthly" if dates.size < 2

    intervals = dates.each_cons(2).map { |a, b| (b - a).to_i }
    avg_interval = intervals.sum.to_f / intervals.size

    if avg_interval <= 10
      "Weekly"
    elsif avg_interval <= 21
      "Biweekly"
    elsif avg_interval <= 45
      "Monthly"
    else
      "Quarterly"
    end
  end
  private_class_method :estimate_frequency
end
