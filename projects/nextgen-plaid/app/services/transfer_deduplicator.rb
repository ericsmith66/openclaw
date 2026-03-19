# frozen_string_literal: true

class TransferDeduplicator
  # Input: array of transfer transactions (from TransactionGridDataProvider)
  # Matching key: date ±1 day, opposite sign, abs(amount) within 1% tolerance, different account_ids
  # Output: deduplicated array — outbound/negative leg kept, matched inbound/positive suppressed
  # Unmatched transactions kept with external: true flag for "External" badge
  # Investment account transactions excluded before processing (handled by data provider filter)

  def initialize(transactions)
    @transactions = transactions
  end

  def call
    # Filter out investment account transactions (handled by data provider, but safety check)
    transfers = @transactions.select { |t| t.account&.plaid_account_type != "investment" }

    # Build lookup by date range and amount tolerance
    outbound = [] # negative amounts
    inbound = []  # positive amounts

    transfers.each do |txn|
      amount = txn.amount.to_f
      next if amount.zero?

      if amount.negative?
        outbound << txn
      else
        inbound << txn
      end
    end

    # Build hash map for inbound transactions keyed by date (normalized day)
    inbound_date_map = build_inbound_date_map(inbound)
    matched_inbound_ids = Set.new
    result = []

    # Match outbound with inbound
    outbound.each do |out|
      match = find_matching_inbound(out, inbound_date_map, matched_inbound_ids)
      if match
        matched_inbound_ids.add(match.id)
        # Keep outbound, suppress inbound (matched)
        # Enrich outbound with opposite account name
        out.instance_variable_set(:@_matched_opposite_account_name, match.account&.name.to_s)
        result << out
      else
        # No match found, keep outbound as external
        result << out
      end
    end

    # Add unmatched inbound transactions
    inbound.each do |inbound_txn|
      result << inbound_txn unless matched_inbound_ids.include?(inbound_txn.id)
    end

    # Mark external transfers
    mark_external_transfers(result, matched_inbound_ids)
  end

  private

  # Build a hash map where keys are normalized dates and values are arrays of inbound transactions
  # Each inbound is stored under three date keys (date-1, date, date+1) to allow ±1 day tolerance
  def build_inbound_date_map(inbound_txns)
    map = Hash.new { |h, k| h[k] = [] }
    inbound_txns.each do |txn|
      date = normalize_date(txn.date)
      (-1..1).each do |offset|
        map[date + offset] << txn
      end
    end
    map
  end

  def find_matching_inbound(outbound_txn, inbound_date_map, matched_ids)
    out_date = normalize_date(outbound_txn.date)
    out_amount = outbound_txn.amount.to_f.abs
    out_account_id = outbound_txn.account_id

    # Search across date tolerance window
    (-1..1).each do |date_offset|
      date_key = out_date + date_offset
      candidates = inbound_date_map[date_key]
      next if candidates.empty?

      candidates.each do |inbound_txn|
        next if matched_ids.include?(inbound_txn.id)
        next if inbound_txn.account_id == out_account_id

        # Verify date within ±1 day (double-check)
        in_date = normalize_date(inbound_txn.date)
        date_diff = (out_date - in_date).abs
        next if date_diff > 1

        # Verify amount within 1% tolerance
        in_amount = inbound_txn.amount.to_f.abs
        tolerance = (out_amount * 0.01).round(2)
        amount_diff = (out_amount - in_amount).abs
        next if amount_diff > tolerance

        return inbound_txn
      end
    end
    nil
  end

  def normalize_date(date)
    return Date.today unless date
    date.is_a?(Date) ? date : Date.parse(date.to_s)
  rescue ArgumentError
    Date.today
  end

  # Mark external transfers based on matched inbound IDs.
  # For outbound transactions, they are external if they didn't find a match.
  # For inbound transactions, they are external if not in matched_inbound_ids.
  def mark_external_transfers(transactions, matched_inbound_ids)
    transactions.each do |txn|
      # Determine if this transaction has a matched opposite
      is_matched = if txn.amount.to_f.negative?
                     # outbound matched if its matched inbound id is known (we didn't store that)
                     # Instead we can check if txn has @_matched_opposite_account_name set
                     txn.instance_variable_defined?(:@_matched_opposite_account_name)
      else
                     matched_inbound_ids.include?(txn.id)
      end
      txn.instance_variable_set(:@_external, !is_matched)
    end
    transactions
  end
end
