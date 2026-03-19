module AgentHub
  class BacklogService
    def self.call(user:, content:, metadata: {})
      # Extract title from first line of content
      title = content.lines.first&.strip&.gsub(/^#+\s*/, "") || "New Backlog Item"

      Artifact.create!(
        name: title,
        artifact_type: "feature",
        phase: "backlog",
        owner_persona: "SAP",
        payload: {
          "content" => content,
          "metadata" => metadata.merge("user_id" => user.id)
        }
      )
    end
  end
end
