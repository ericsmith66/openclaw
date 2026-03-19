module PersonaContextProviders
  class FinancialSnapshotProvider
    MAX_CHARS = 4000

    # Returns a hash:
    # {
    #   content: "..." (string to inject into system context),
    #   metadata: {"financial_snapshot_id"=>..., "financial_snapshot_at"=>..., "schema_version"=>...}
    # }
    def self.call(user)
      snapshot = FinancialSnapshot.latest_for_user(user)
      return { content: "", metadata: {} } unless snapshot

      # Use existing sanitized export intended for AI context.
      provider = Reporting::DataProvider.new(user)
      rag_hash = provider.to_rag_context(snapshot.data.to_h)

      # Hard guardrails: never include raw account numbers even if upstream changes.
      %w[account_numbers institution_ids raw_transaction_data].each do |k|
        rag_hash.delete(k)
        rag_hash.delete(k.to_sym)
      end

      content = <<~TEXT
        --- FINANCIAL SNAPSHOT (CURRENT) ---
        Snapshot date: #{snapshot.snapshot_at.to_date}
        Status: #{snapshot.status}
        Data quality score: #{snapshot.data_quality_score}

        #{JSON.pretty_generate(rag_hash)}
      TEXT

      {
        content: truncate(content, MAX_CHARS),
        metadata: {
          "financial_snapshot_id" => snapshot.id,
          "financial_snapshot_at" => snapshot.snapshot_at.iso8601,
          "financial_snapshot_status" => snapshot.status,
          "financial_snapshot_schema_version" => snapshot.schema_version
        }
      }
    rescue StandardError => e
      Rails.logger.warn("[FinancialSnapshotProvider] failed user_id=#{user.id} error=#{e.class}:#{e.message}")
      { content: "", metadata: {} }
    end

    def self.truncate(text, max)
      return text if text.length <= max
      text[0...max] + "\n[TRUNCATED]"
    end
    private_class_method :truncate
  end
end
