class PersonaRagProvider
  MAX_CONTEXT_CHARS = 4000

  # Loads persona-scoped RAG docs from `knowledge_base/personas/<persona_dir>/`.
  # This is intentionally lightweight and separate from `SapAgent::RagProvider`.
  def self.build_prefix(persona_id)
    dir = persona_dir(persona_id)
    base = Rails.root.join("knowledge_base/personas/#{dir}")
    return "" unless Dir.exist?(base)

    files = Dir.glob(base.join("**/*.md")).sort
    return "" if files.empty?

    content = files.map do |path|
      rel = path.delete_prefix(Rails.root.to_s + "/")
      "File: #{rel}\n#{File.read(path)}\n"
    end.join("\n")

    truncate(content)
  rescue StandardError => e
    Rails.logger.warn("[PersonaRagProvider] failed persona_id=#{persona_id} error=#{e.class}:#{e.message}")
    ""
  end

  def self.persona_dir(persona_id)
    persona_id.to_s.tr("-", "_")
  end

  def self.truncate(text)
    return text if text.length <= MAX_CONTEXT_CHARS
    text[0...MAX_CONTEXT_CHARS] + "\n[TRUNCATED due to length limits]"
  end

  private_class_method :persona_dir, :truncate
end
