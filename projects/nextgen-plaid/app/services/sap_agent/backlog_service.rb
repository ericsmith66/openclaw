require "json"

module SapAgent
  class BacklogService
    def self.sync_backlog
      backlog_path = Rails.root.join("knowledge_base/backlog.json")
      todo_path = Rails.root.join("TODO.md")

      backlog = File.exist?(backlog_path) ? JSON.parse(File.read(backlog_path)) : []

      todo_content = "# NextGen Plaid — TODO\n\n"

      done = backlog.select { |i| i["status"] == "Completed" }
      todo = backlog.select { |i| i["status"] != "Completed" }

      todo_content << "## Next\n"
      todo.each do |item|
        todo_content << "- [ ] #{item["title"]} (#{item["id"]}) - #{item["priority"]}\n"
      end

      todo_content << "\n## Done ✅\n"
      done.each do |item|
        todo_content << "- #{item["title"]} (#{item["id"]})\n"
      end

      File.write(todo_path, todo_content)
      Rails.logger.info({ event: "sap.backlog.synced", todo_count: todo.size, done_count: done.size }.to_json)
    end

    def self.update_backlog(item_data)
      SapAgent::BacklogStrategy.store!(item_data)
      sync_backlog
    end

    def self.prune_backlog
      backlog_path = Rails.root.join("knowledge_base/backlog.json")
      archive_path = Rails.root.join("knowledge_base/backlog_archive.json")
      return unless File.exist?(backlog_path)

      backlog = JSON.parse(File.read(backlog_path))
      archive = File.exist?(archive_path) ? JSON.parse(File.read(archive_path)) : []

      pruned = []
      kept = []

      backlog.each do |item|
        if item["priority"] != "High" && item["status"] != "Completed"
          kept << item
        else
          kept << item
        end
      end

      if pruned.any?
        archive += pruned
        File.write(backlog_path, JSON.pretty_generate(kept))
        File.write(archive_path, JSON.pretty_generate(archive))
        sync_backlog
        Rails.logger.info({ event: "sap.backlog.pruned", count: pruned.size }.to_json)
      end
    end
  end
end
