# frozen_string_literal: true

module NetWorth
  class SectorWeightsComponent < BaseCardComponent
    DEFAULT_COLORS = [
      "#22c55e", # green
      "#3b82f6", # blue
      "#f97316", # orange
      "#a855f7", # purple
      "#06b6d4", # cyan
      "#ef4444", # red
      "#eab308", # yellow
      "#64748b"  # slate
    ].freeze

    def initialize(data:, sort: nil, dir: nil)
      @data = data.to_h
      @sort = normalize_sort(sort)
      @dir = normalize_dir(dir)
      @corrupt = false
      @chart_error = false
    end

    def empty?
      sector_rows.empty? && !corrupt?
    end

    def corrupt?
      @corrupt
    end

    def chart_error?
      @chart_error
    end

    def server_sort?
      sector_rows.size >= 10
    end

    def sector_rows
      @sector_rows ||= begin
        raw = safe_get(@data, "sector_weights")
        rows = normalize_sector_weights(raw)
        apply_sort(rows)
      rescue StandardError => e
        log_error(e, message: "sector_weights normalize failed")
        @corrupt = true
        []
      end
    end

    def chart_series
      sector_rows.map do |r|
        label = r[:sector]
        value_label = number_to_currency(r[:value_usd].to_f, precision: 0)
        [ "#{label} (#{value_label})", (r[:pct].to_f * 100.0) ]
      end
    end

    def colors
      sector_rows.map { |r| color_for(r[:sector]) }
    end

    def sort_link(column)
      next_dir = if @sort == column
        @dir == "asc" ? "desc" : "asc"
      else
        default_dir_for(column)
      end

      { sort: column, dir: next_dir }
    end

    def aria_sort_for(column)
      return "none" unless @sort == column

      @dir == "asc" ? "ascending" : "descending"
    end

    def mark_chart_error!(error)
      @chart_error = true
      log_error(error, message: "sector_weights chart render failed")
    end

    private

    def normalize_sector_weights(raw)
      return [] if raw.nil?

      if raw.is_a?(Array)
        raw.filter_map do |row|
          h = row.to_h
          sector = presence(h["sector"] || h[:sector])
          pct = h["pct"] || h[:pct] || h["percentage"] || h[:percentage]
          value = h["value"] || h[:value] || h["value_usd"] || h[:value_usd]
          next if sector.nil?

          pct_f = safe_to_f(pct, default: nil)
          value_f = safe_to_f(value, default: nil)
          next if pct_f.nil? && value_f.nil?

          { sector: sector.to_s.titleize, pct: pct_f, value_usd: value_f }
        end
      elsif raw.is_a?(Hash)
        raw.to_h.map do |k, v|
          { sector: k.to_s.titleize, pct: safe_to_f(v), value_usd: nil }
        end
      else
        @corrupt = true
        []
      end
    end

    def apply_sort(rows)
      return rows.sort_by { |r| -r[:pct].to_f } if @sort.nil?

      sorted = case @sort
      when "sector" then rows.sort_by { |r| r[:sector].to_s }
      when "pct" then rows.sort_by { |r| r[:pct].to_f }
      when "value" then rows.sort_by { |r| r[:value_usd].to_f }
      else rows
      end

      @dir == "desc" ? sorted.reverse : sorted
    end

    def normalize_sort(sort)
      s = sort.to_s
      return nil if s.blank?

      %w[sector pct value].include?(s) ? s : nil
    end

    def normalize_dir(dir)
      d = dir.to_s
      return "desc" if d.blank?

      %w[asc desc].include?(d) ? d : "desc"
    end

    def default_dir_for(column)
      column == "sector" ? "asc" : "desc"
    end

    def color_for(label)
      idx = label.to_s.bytes.sum % DEFAULT_COLORS.length
      DEFAULT_COLORS[idx]
    end

    def log_error(error, message:)
      tags = { epic: 3, prd: "3-12", component: self.class.name }

      if defined?(Sentry)
        Sentry.capture_exception(error, tags: tags, extra: { message: message })
      else
        Rails.logger.warn("#{message}: #{error.class} #{error.message} tags=#{tags}")
      end
    end
  end
end
