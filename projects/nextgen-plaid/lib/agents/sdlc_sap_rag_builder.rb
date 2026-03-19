# frozen_string_literal: true

require "time"

module Agents
  class SdlcSapRagBuilder
    CHAR_CAP = 100_000

    def self.build(tiers_csv, now: Time.current)
      tiers = parse_tiers(tiers_csv)
      sections = []

      tiers.each do |tier|
        sections << "\n\n--- RAG TIER: #{tier} ---\n"
        sections << read_tier(tier, now: now)
      end

      content = sections.join
      truncated = false
      original_length = content.length

      if content.length > CHAR_CAP
        truncated = true
        content = content[0, CHAR_CAP]
      end

      {
        content: content,
        tiers: tiers,
        truncated: truncated,
        original_length: original_length,
        final_length: content.length
      }
    end

    def self.parse_tiers(tiers_csv)
      return [] if tiers_csv.to_s.strip.empty?

      tiers_csv.to_s.split(",").map(&:strip).reject(&:empty?)
    end

    def self.read_tier(tier, now:)
      case tier
      when "foundation"
        read_directory("knowledge_base/static_docs")
      when "structure"
        read_directory("knowledge_base/schemas")
      when "history"
        read_history(now: now)
      else
        "(unknown tier: #{tier})"
      end
    end

    def self.read_directory(rel_dir)
      dir = Rails.root.join(rel_dir)
      return "(missing dir: #{rel_dir})" unless Dir.exist?(dir)

      files = Dir.glob(dir.join("**", "*")).select { |p| File.file?(p) }.sort
      return "(no files under #{rel_dir})" if files.empty?

      files.map do |path|
        rel = path.delete_prefix(Rails.root.to_s + "/")
        "\n\n[FILE: #{rel}]\n#{File.read(path)}"
      end.join
    end

    def self.read_history(now:)
      parts = []

      inventory_path = Rails.root.join("knowledge_base", "inventory.json")
      if File.exist?(inventory_path)
        parts << "\n\n[FILE: knowledge_base/inventory.json]\n#{File.read(inventory_path)}"
      end

      # 7-day lookback on run summaries + logs.
      cutoff = now - 7.days
      base = Rails.root.join("knowledge_base", "logs", "cli_tests")
      if Dir.exist?(base)
        run_dirs = Dir.glob(base.join("*"))
                      .select { |p| File.directory?(p) }
                      .sort

        run_dirs.each do |dir|
          summary = File.join(dir, "run_summary.md")
          cli_log = File.join(dir, "cli.log")
          sap_log = File.join(dir, "sap.log")

          [ summary, cli_log, sap_log ].each do |path|
            next unless File.exist?(path)
            next unless File.mtime(path) >= cutoff

            rel = path.delete_prefix(Rails.root.to_s + "/")
            parts << "\n\n[FILE: #{rel}]\n#{File.read(path)}"
          end
        end
      end

      parts.join.presence || "(no history context available)"
    end

    private_class_method :parse_tiers, :read_tier, :read_directory, :read_history
  end
end
