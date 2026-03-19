# frozen_string_literal: true

module NetWorth
  class PerformanceComponent < BaseCardComponent
    # Performance: using pre-rolled historical_totals from latest snapshot only
    def initialize(data:)
      @data = data.to_h
      @corrupt = false
      @chart_error = false
    end

    def missing_data?
      safe_get(@data, "historical_totals").nil? && safe_get(@data, "historical_net_worth").nil?
    end

    def corrupt?
      @corrupt
    end

    def chart_error?
      @chart_error
    end

    def insufficient_history?
      rows.size < 2 && !corrupt? && !missing_data?
    end

    def rows
      @rows ||= begin
        raw = safe_get(@data, "historical_totals")
        raw = safe_get(@data, "historical_net_worth") if raw.nil?
        normalize_rows(raw)
      rescue StandardError => e
        log_error(e, message: "performance historical_totals normalize failed")
        @corrupt = true
        []
      end
    end

    def chart_points
      rows.map do |r|
        {
          x: r[:date],
          y: r[:total].to_f,
          delta: r[:delta].nil? ? nil : r[:delta].to_f
        }
      end
    end

    def line_chart_options
      {
        id: "net-worth-performance-chart",
        height: "260px",
        prefix: "$",
        precision: 0,
        curve: false,
        messages: { empty: "No performance data" },
        library: {
          parsing: { xAxisKey: "x", yAxisKey: "y" },
          plugins: {
            tooltip: {
              callbacks: {
                label: "function(context){var raw=context.raw||{};var base=(context.dataset && context.dataset.label ? context.dataset.label+': ' : '') + context.formattedValue; if(raw.delta===undefined||raw.delta===null){return base;} var d=raw.delta; var sign=d>0?'+':''; try{ return base + ' (\u0394 ' + sign + '$' + d.toLocaleString() + ')'; }catch(e){ return base + ' (\u0394 ' + sign + '$' + d + ')'; }}"
              }
            }
          },
          scales: {
            x: { ticks: { maxRotation: 0 } },
            y: { ticks: { callback: "function(value){return '$' + Number(value).toLocaleString();}" } }
          }
        }
      }
    end

    def mark_chart_error!(error)
      @chart_error = true
      log_error(error, message: "performance chart render failed")
    end

    private

    def normalize_rows(raw)
      return [] if raw.nil?
      return [] unless raw.is_a?(Array)

      raw.filter_map do |row|
        h = row.to_h
        date = presence(h["date"] || h[:date])
        total = h["total"] || h[:total]
        delta = h["delta"] || h[:delta]
        next if date.nil?

        {
          date: date.to_s,
          # NOTE: `safe_to_f` takes a positional default argument.
          # Passing `default:` here would create a Hash fallback (e.g. `{default: 0.0}`),
          # which later breaks formatting (`to_f` undefined for Hash).
          total: safe_to_f(total, 0.0),
          delta: (delta.nil? ? nil : safe_to_f(delta, nil))
        }
      end
    end

    def log_error(error, message:)
      tags = { epic: 3, prd: "3-13", component: self.class.name }

      if defined?(Sentry)
        Sentry.capture_exception(error, tags: tags, extra: { message: message })
      else
        Rails.logger.warn("#{message}: #{error.class} #{error.message} tags=#{tags}")
      end
    end
  end
end
