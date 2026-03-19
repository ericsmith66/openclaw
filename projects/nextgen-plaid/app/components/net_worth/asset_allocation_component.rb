# frozen_string_literal: true

module NetWorth
  class AssetAllocationComponent < BaseCardComponent
    def initialize(allocation_data:)
      @allocation_data = normalize_allocation(allocation_data)
    end

    def empty?
      @allocation_data.empty?
    end

    def allocation_rows
      @allocation_data
    end

    def pie_series
      allocation_rows.map { |r| [ r[:label], r[:value_usd] ] }
    end

    def bar_series
      allocation_rows.map { |r| [ r[:label], r[:pct] ] }
    end

    private

    def normalize_allocation(raw)
      rows = case raw
      when Array
               raw
      when Hash
               raw.to_a
      else
               []
      end

      normalized = rows.filter_map do |row|
        if row.is_a?(Array)
          # provider-style hash: { "equities" => 0.62, "cash" => 0.08 }
          key, pct = row
          label = key.to_s.tr("_", " ").strip
          pct_f = safe_to_f(pct, 0.0)
          next if label.blank? || pct_f <= 0
          { label: label.titleize, pct: pct_f, value_usd: nil }
        else
          h = row.to_h
          label = (h["class"] || h[:class] || h["label"] || h[:label]).to_s.tr("_", " ").strip
          pct = h["pct"] || h[:pct] || h["percentage"] || h[:percentage]
          value = h["value"] || h[:value] || h["value_usd"] || h[:value_usd]

          pct_f = pct.nil? ? nil : safe_to_f(pct, nil)
          value_f = value.nil? ? nil : safe_to_f(value, nil)
          next if label.blank?
          next if pct_f.nil? && value_f.nil?

          { label: label.titleize, pct: pct_f, value_usd: value_f }
        end
      end

      # Best-effort fill in missing value_usd when we have total.
      total = normalized.sum { |r| r[:value_usd].to_f }
      if total.positive?
        normalized.each do |r|
          r[:value_usd] ||= (r[:pct].to_f * total)
        end
      else
        # When only pct exists, use pct as value for pie so chart renders.
        normalized.each do |r|
          r[:value_usd] ||= r[:pct].to_f
        end
      end

      normalized.sort_by { |r| -r[:pct].to_f }
    end
  end
end
