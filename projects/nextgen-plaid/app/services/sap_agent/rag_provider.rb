module SapAgent
  class RagProvider
    CONTEXT_MAP_PATH = Rails.root.join("knowledge_base/static_docs/context_map.md")
    # Keep this aligned with tests and the SDLC bridge expectations.
    MAX_CONTEXT_CHARS = 4000

    def self.build_prefix(query_type, user_id = nil, persona_id = nil, sap_run_id = nil, request_id: nil)
      request_id ||= SecureRandom.uuid
      sap_logger.info({
        event: "RAG_PREFIX_START",
        request_id: request_id,
        query_type: query_type,
        user_id: user_id,
        persona_id: persona_id,
        sap_run_id: sap_run_id
      })

      if sap_run_id && (run = SapRun.find_by(id: sap_run_id))
        run.update_column(:output_json, (run.output_json || {}).merge("last_rag_request_id" => request_id))
      end

      snapshot_content = fetch_snapshot(user_id)
      backlog_content = fetch_backlog(persona_id) || "No backlog data available for this persona."
      active_artifact_content = fetch_active_artifact(sap_run_id, persona_id)

      # Determine which system prompt to load
      base_persona = persona_id.to_s.gsub("-agent", "").downcase
      prompt_file = case base_persona
      when "coordinator", "conductor" then "coordinator_system.md"
      when "cwa" then "cwa_system.md"
      else "sap_system.md"
      end

      system_prompt_path = Rails.root.join("config/agent_prompts", prompt_file)
      system_prompt = if File.exist?(system_prompt_path)
                        File.read(system_prompt_path)
      else
                        # Fallback for now if prompt doesn't exist
                        File.read(Rails.root.join("config/agent_prompts/sap_system.md"))
      end

      docs_content = fetch_static_docs(query_type)

      full_context = system_prompt
                       .gsub("[CONTEXT_BACKLOG]", backlog_content)
                       .gsub("[VISION_SSOT]", File.exist?(Rails.root.join("knowledge_base/static_docs/MCP.md")) ? File.read(Rails.root.join("knowledge_base/static_docs/MCP.md")) : "No vision context.")
                       .gsub("[PROJECT_CONTEXT]", snapshot_content)
                       .gsub("[ACTIVE_ARTIFACT]", active_artifact_content || "")

      # Some prompt templates may not include every placeholder. Ensure the
      # redacted user snapshot is still available to the agent.
      if !system_prompt.include?("[PROJECT_CONTEXT]") && snapshot_content.present?
        full_context << "\n\n#{snapshot_content}"
      end

      # Ensure the active artifact is present even if the template doesn't include
      # the placeholder.
      if !system_prompt.include?("[ACTIVE_ARTIFACT]") && active_artifact_content.present?
        full_context << "\n\n#{active_artifact_content}"
      end

      full_context << "\n\n--- STATIC DOCUMENTS ---\n#{docs_content}" if docs_content.present?

      # Inject Project Structure and Schema if applicable (placed after static docs
      # to avoid truncation cutting off the higher-signal sections).
      full_context << "\n\n--- PROJECT STRUCTURE ---\n#{fetch_project_structure}"

      if base_persona == "cwa"
        full_context << "\n\n--- DATABASE SCHEMA ---\n#{fetch_db_schema}"
      end

      truncated_context = truncate_context(full_context, request_id)

      # Stable framing markers for debugging + tests.
      truncated_context = "[CONTEXT START]\n#{truncated_context}\n[CONTEXT END]\n"

      sap_logger.info({
        event: "RAG_PREFIX_COMPLETED",
        request_id: request_id,
        length: truncated_context.length
      })
      truncated_context
    rescue => e
      sap_logger.warn({ event: "RAG_PREFIX_FAILURE", error: e.message })
      "[CONTEXT ERROR: Fallback to minimal prefix]\n"
    end

    def self.summarize(text)
      return if text.nil?

      snippet = text.is_a?(String) ? text : text.to_json
      snippet = snippet.to_s.strip
      truncated = snippet[0...400]
      sap_logger.info({ event: "RAG_SUMMARY", length: truncated.length })
      truncated
    rescue => e
      sap_logger.warn({ event: "RAG_SUMMARY_FAILURE", error: e.message })
      nil
    end

    private

    def self.fetch_static_docs(query_type)
      doc_names = select_docs(query_type)
      doc_names.map do |name|
        path = Rails.root.join(name.strip)
        if File.exist?(path)
          "File: #{name}\n#{File.read(path)}\n"
        else
          sap_logger.warn({ event: "DOC_NOT_FOUND", path: path.to_s })
          nil
        end
      end.compact.join("\n---\n")
    end

    def self.select_docs(query_type)
      query_type = query_type.to_s

      # Keep v0 behavior stable for tests/CI: when generating PRDs we always
      # include the core project thinking + product requirements if present.
      if query_type == "generate"
        base = [ "0_AI_THINKING_CONTEXT.md" ]
        base << "PRODUCT_REQUIREMENTS.md" if File.exist?(Rails.root.join("PRODUCT_REQUIREMENTS.md"))
        return base
      end

      return [ "0_AI_THINKING_CONTEXT.md" ] unless File.exist?(CONTEXT_MAP_PATH)

      map_content = File.read(CONTEXT_MAP_PATH)
      # Simple regex/parsing for the markdown table
      line = map_content.lines.find { |l| l.downcase.include?("| #{query_type.to_s.downcase}") }
      line ||= map_content.lines.find { |l| l.downcase.include?("| default") }

      if line
        docs = line.split("|")[2]
        docs ? docs.split(",").map(&:strip) : [ "0_AI_THINKING_CONTEXT.md" ]
      else
        [ "0_AI_THINKING_CONTEXT.md" ]
      end
    end

    def self.fetch_project_structure
      ignored = %w[
        .git .idea .vscode node_modules log tmp storage public/assets runs vendor/bundle
      ]

      entries = Dir.children(Rails.root)
        .reject { |e| e.start_with?(".") }
        .reject { |e| ignored.include?(e) }
        .sort

      entries.map { |e| "./#{e}" }.join("\n")
    rescue => e
      "Error fetching project structure: #{e.message}"
    end

    def self.fetch_db_schema
      schema_path = Rails.root.join("db/schema.rb")
      return "No schema.rb found." unless File.exist?(schema_path)

      # We could summarize it, but let's start with the first 100 lines or search for tables.
      # A better way might be to extract just table names and their columns.
      content = File.read(schema_path)
      # Extract only the create_table blocks to keep it concise
      tables = content.scan(/create_table "([^"]+)"[^\n]*\n(.*?)\n  end/m)
      tables.map do |name, body|
        "Table: #{name}\n#{body.gsub(/^    /, '  ')}"
      end.join("\n\n")
    rescue => e
      "Error fetching DB schema: #{e.message}"
    end

    def self.fetch_active_artifact(sap_run_id, persona_id)
      return nil unless sap_run_id

      run = SapRun.find_by(id: sap_run_id)
      return nil unless run&.artifact

      artifact = run.artifact
      base_persona = persona_id.to_s.gsub("-agent", "").downcase

      content = "--- [ACTIVE_ARTIFACT] ---\n"
      content << "Name: #{artifact.name}\n"
      content << "Type: #{artifact.artifact_type}\n"
      content << "Phase: #{artifact.phase.humanize}\n\n"

      content << "### PRD (Primary Requirements):\n"
      content << (artifact.payload["content"] || "No PRD content available.")

      # TECHNICAL PLAN visibility rules:
      # - Coordinator sees that a technical plan exists / is needed, but should not
      #   receive detailed micro-task titles (to avoid leaking implementation-level
      #   detail before handoff).
      # - CWA sees the full micro-task list.
      if base_persona == "coordinator" || base_persona == "conductor"
        content << "\n\n### TECHNICAL PLAN (Micro-tasks):\n"
        tasks = artifact.payload["micro_tasks"]
        if tasks.present?
          content << "(#{tasks.length} tasks defined — details available to CWA after handoff.)\n"
        else
          content << "No structured technical tasks defined."
        end
      elsif base_persona == "cwa"
        content << "\n\n### TECHNICAL PLAN (Micro-tasks):\n"
        tasks = artifact.payload["micro_tasks"]
        if tasks.present?
          tasks.each do |t|
            status_mark = (t["status"] == "completed" || t["completed"] == true) ? "x" : " "
            content << "- [#{status_mark}] #{t['id']}: #{t['title']} (#{t['estimate']})\n"
          end
        else
          content << "No structured technical tasks defined."
        end

        if artifact.payload["implementation_notes"].present?
          content << "\n\nImplementation Notes (Free-form Plan):\n#{artifact.payload['implementation_notes']}\n"
        end
      end

      content << "\n--- END ACTIVE_ARTIFACT ---\n"
      content
    end

    def self.fetch_snapshot(user_id)
      return "No user context provided." unless user_id

      snapshot = Snapshot.where(user_id: user_id).last
      return "No snapshot found for user #{user_id}" unless snapshot

      redacted = anonymize_snapshot(snapshot.data).to_json
      "--- USER DATA SNAPSHOT ---\n#{redacted}\n"
    end

    def self.fetch_backlog(persona_id)
      # Normalize persona_id (e.g., "sap-agent" -> "sap")
      base_persona = persona_id.to_s.gsub("-agent", "").downcase

      # Determine which artifacts this persona should see
      # We now use owner_persona to ensure agents see what's assigned to them (PRD-AH-011B fix)
      search_persona = case base_persona
      when "sap" then "SAP"
      when "coordinator", "conductor" then [ "Coordinator", "Conductor" ]
      when "cwa" then "CWA"
      when "ai_financial_advisor" then "AiFinancialAdvisor"
      else nil
      end

      return nil unless search_persona

      artifacts = Artifact.where(owner_persona: search_persona).limit(10).order(updated_at: :desc)

      title = base_persona == "sap" ? "BACKLOG" : "ASSIGNED ARTIFACTS"
      return "--- #{title} ---\nNo items found." if artifacts.empty?

      content = "--- #{title} (Total: #{artifacts.count}) ---\n"
      artifacts.each do |a|
        content << "ID: #{a.id} | Name: #{a.name} | Type: #{a.artifact_type} | Phase: #{a.phase.humanize} | Updated: #{a.updated_at.strftime('%Y-%m-%d')}\n"
      end
      content << "\nTo move an item forward, you MUST include this tag in your response: [ACTION: <INTENT>: ID]\n"
      content << "Valid intents: MOVE_TO_ANALYSIS, APPROVE_PRD, READY_FOR_DEV, START_DEV, COMPLETE_DEV, APPROVE_QA, REJECT, BACKLOG, START_BUILD (silent)\n"
      content
    end

    def self.anonymize_snapshot(data)
      # Basic anonymization as per PRD: mask balances and account-like numbers
      case data
      when Hash
        data.each_with_object({}) do |(k, v), h|
          if k.to_s.match?(/balance|amount|account_number|mask|official_name/i)
            h[k] = "[REDACTED]"
          else
            h[k] = anonymize_snapshot(v)
          end
        end
      when Array
        data.map { |v| anonymize_snapshot(v) }
      when String
        # Already handled by Anonymizer in proxy, but we do another pass here for financial values
        data.match?(/\d{4,}/) ? "[REDACTED_ID]" : data
      else
        data
      end
    end

    def self.truncate_context(text, request_id = nil)
      return text if text.length <= MAX_CONTEXT_CHARS

      sap_logger.info({
        event: "CONTEXT_TRUNCATED",
        request_id: request_id,
        original_length: text.length
      })
      text[0...MAX_CONTEXT_CHARS] + "\n[TRUNCATED due to length limits]"
    end

    def self.sap_logger
      @sap_logger ||= Logger.new(Rails.root.join("agent_logs/sap.log"))
      @sap_logger.formatter = proc do |severity, datetime, progname, msg|
        {
          timestamp: datetime,
          severity: severity,
          message: msg
        }.to_json + "\n"
      end
      @sap_logger
    end
  end
end
