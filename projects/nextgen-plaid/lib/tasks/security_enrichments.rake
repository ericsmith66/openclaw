namespace :security_enrichments do
  desc "Delete Finnhub security enrichments (if any) and deduplicate remaining records by security_id"
  task cleanup_finnhub_and_dedupe: :environment do
    deleted_finnhub = 0

    if SecurityEnrichment.column_names.include?("source")
      deleted_finnhub = SecurityEnrichment.unscoped.where(source: "finnhub").delete_all
    end

    duplicate_security_ids = SecurityEnrichment
      .unscoped
      .group(:security_id)
      .having("COUNT(*) > 1")
      .pluck(:security_id)

    deleted_duplicates = 0
    duplicate_security_ids.each do |security_id|
      rows = SecurityEnrichment.unscoped.where(security_id: security_id).order(enriched_at: :desc, id: :desc)
      keeper = rows.first
      next unless keeper

      deleted_duplicates += rows.where.not(id: keeper.id).delete_all
    end

    puts "Deleted finnhub records: #{deleted_finnhub}"
    puts "Deduped duplicate records: #{deleted_duplicates}"
    puts "Duplicate security_ids processed: #{duplicate_security_ids.size}"
  end

  desc "Re-run FMP enrichment for every SecurityEnrichment record (uses stored symbol when present, otherwise falls back to a holding ticker_symbol)"
  task reenrich_all: :environment do
    limit = ENV["LIMIT"]&.to_i
    offset = ENV["OFFSET"]&.to_i

    scope = SecurityEnrichment.order(:id)
    scope = scope.offset(offset) if offset && offset.positive?
    scope = scope.limit(limit) if limit && limit.positive?

    total = scope.count
    puts "Re-enriching #{total} security_enrichments#{limit ? " (LIMIT=#{limit})" : ""}#{offset ? " (OFFSET=#{offset})" : ""}"

    job = HoldingsEnrichmentJob.new
    processed = 0
    successes = 0
    errors = 0
    missing_symbol = 0

    scope.each do |row|
      processed += 1

      holding = Holding.where(security_id: row.security_id).where.not(ticker_symbol: [ nil, "" ]).first

      symbol = row.symbol.presence || holding&.ticker_symbol

      if symbol.blank?
        missing_symbol += 1
        puts "[#{processed}/#{total}] security_id=#{row.security_id} - skipping (no symbol and no holding ticker_symbol)"
        next
      end

      symbol = job.send(:normalize_symbol, symbol)

      begin
        if holding
          job.perform(holding_ids: [ holding.id ])
        else
          now = Time.current
          notes = []
          data = {}

          begin
            fmp_data = FmpEnricherService.new.enrich(symbol)
            data = fmp_data.present? ? fmp_data : {}
          rescue => e
            notes << "fmp: #{e.class.name}: #{e.message}"
          end

          status = data.present? ? "success" : "error"
          job.send(:upsert_enrichment!, row.security_id, symbol: symbol, enriched_at: now, status: status, data: data, notes: notes)
        end

        refreshed = SecurityEnrichment.find_by(security_id: row.security_id)
        if refreshed&.status == "success"
          successes += 1
        else
          errors += 1
        end
        puts "[#{processed}/#{total}] security_id=#{row.security_id} symbol=#{symbol} status=#{refreshed&.status}"
      rescue => e
        errors += 1
        puts "[#{processed}/#{total}] security_id=#{row.security_id} symbol=#{symbol} ERROR #{e.class}: #{e.message}"
      end
    end

    puts "Done. processed=#{processed} success=#{successes} error=#{errors} missing_symbol=#{missing_symbol}"
  end
end
