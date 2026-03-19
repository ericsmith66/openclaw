# frozen_string_literal: true

namespace :agent do
  desc "Cleanup agent sandbox worktrees older than HOURS (default: 48)"
  task :cleanup_sandboxes, [ :hours ] => :environment do |_t, args|
    hours = (args[:hours] || ENV["AGENT_SANDBOX_CLEANUP_HOURS"] || "48").to_i
    hours = 48 if hours <= 0

    cutoff = Time.current - hours.hours
    base = Rails.root.join("tmp", "agent_sandbox")

    unless Dir.exist?(base)
      puts "No sandbox dir at #{base}"
      next
    end

    removed = 0
    kept = 0

    Dir.children(base).sort.each do |entry|
      path = base.join(entry)
      next unless File.directory?(path)

      mtime = File.mtime(path)
      if mtime < cutoff
        begin
          FileUtils.rm_rf(path)
          removed += 1
        rescue StandardError => e
          warn "Failed to remove #{path}: #{e.class}: #{e.message}"
        end
      else
        kept += 1
      end
    end

    puts "Sandbox cleanup complete: removed=#{removed} kept=#{kept} cutoff=#{cutoff.iso8601} base=#{base}"
  end
end
