# frozen_string_literal: true

require "csv"

module Api
  class SnapshotsController < ApplicationController
    before_action :authenticate_user!, only: [ :download ]

    def download
      snapshot = FinancialSnapshot.find(params[:id])
      head :forbidden and return unless snapshot.user_id == current_user.id

      date = snapshot.snapshot_at.to_date

      if request.format.csv?
        send_data(
          holdings_csv(snapshot),
          filename: "networth-snapshot-#{date}.csv",
          type: "text/csv",
          disposition: "attachment"
        )
      else
        send_data(
          snapshot_payload(snapshot, include_holdings_export: params[:include_holdings_export] == "true").to_json,
          filename: "networth-snapshot-#{date}.json",
          type: "application/json",
          disposition: "attachment"
        )
      end
    end

    def rag_context
      snapshot = FinancialSnapshot.find(params[:id])
      head :forbidden and return unless rag_authorized?

      provider = Reporting::DataProvider.new(snapshot.user)
      render json: provider.to_rag_context(snapshot.data)
    end

    private

    def snapshot_payload(snapshot, include_holdings_export: false)
      payload = snapshot.data.to_h.deep_dup

      # Backfill newer keys for older snapshots so exports remain useful.
      payload["transactions_summary"] ||= {}

      if include_holdings_export
        payload["holdings_export"] ||= []

        if Array(payload["holdings_export"]).empty?
          begin
            provider = Reporting::DataProvider.new(snapshot.user)
            payload["holdings_export"] = provider.respond_to?(:holdings_export_rows) ? provider.holdings_export_rows : []
          rescue StandardError
            payload["holdings_export"] ||= []
          end
        end
      else
        # `holdings_export` can be extremely large; keep the default JSON export focused on
        # snapshot summary data. Users can still export holdings via CSV or full JSON.
        payload.delete("holdings_export")
      end

      if payload["transactions_summary"].blank?
        monthly = payload["monthly_transaction_summary"].to_h
        income = (monthly["income"] || monthly[:income] || 0).to_f
        expenses = (monthly["expenses"] || monthly[:expenses] || 0).to_f

        payload["transactions_summary"] = {
          "month" => {
            "income" => income,
            "expenses" => expenses,
            "net" => (income - expenses)
          }
        }
      end

      payload
    end

    def holdings_csv(snapshot)
      rows = Array(snapshot.data&.dig("holdings_export"))

      if rows.empty?
        rows = Array(snapshot.data&.dig("top_holdings")).map do |h|
          {
            "account" => "",
            "symbol" => h["ticker"],
            "name" => h["name"],
            "value" => h["value"],
            "pct_portfolio" => h["pct_portfolio"]
          }
        end
      end

      CSV.generate do |csv|
        csv << %w[Account Symbol Name Value Percentage]
        rows.each do |row|
          r = row.to_h
          pct = (r["pct_portfolio"] || r[:pct_portfolio] || r["percentage"] || r[:percentage]).to_f
          csv << [
            (r["account"] || r[:account]).to_s,
            (r["symbol"] || r[:symbol] || r["ticker"] || r[:ticker]).to_s,
            (r["name"] || r[:name]).to_s,
            (r["value"] || r[:value]).to_f,
            (pct * 100.0).round(2)
          ]
        end
      end
    end

    def rag_authorized?
      return true if current_user&.admin?
      return true if api_key_valid?

      false
    end

    def api_key_valid?
      configured = ENV["RAG_EXPORT_API_KEY"].to_s
      provided = request.headers["X-Api-Key"].to_s

      return false if configured.blank? || provided.blank?
      return false unless configured.bytesize == provided.bytesize

      ActiveSupport::SecurityUtils.secure_compare(configured, provided)
    end
  end
end
