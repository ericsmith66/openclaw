# frozen_string_literal: true

require "yaml"

module AiWorkflow
  class AgentFactory
    def initialize(model:, test_overrides: {}, common_context: "", context: {})
      @model = model
      @test_overrides = test_overrides
      @common_context = common_context
      @context = context
    end

    def build_agents
      cwa_agent = build_cwa_agent
      planner_agent = build_planner_agent(cwa_agent)
      coordinator_agent = build_coordinator_agent(planner_agent, cwa_agent)
      sap_agent = build_sap_agent(coordinator_agent)

      cwa_agent.register_handoffs(coordinator_agent)

      {
        sap: sap_agent,
        coordinator: coordinator_agent,
        planner: planner_agent,
        cwa: cwa_agent
      }
    end

    def build_cwa_agent
      cwa_instructions = persona_instructions("intp") + @common_context

      rag_level = @test_overrides.is_a?(Hash) ? @test_overrides["rag_cwa"].to_s : ""
      rag_level = "tier-1" if rag_level.blank?

      if rag_level != "none"
        sap_rag_path = Rails.root.join("knowledge_base", "static_docs", "eric_grok_static_rag.md")
        if File.exist?(sap_rag_path)
          sap_rag = File.read(sap_rag_path)
          cwa_instructions += "\n\n[STATIC RAG]\n#{sap_rag}"
        end

        if rag_level == "tier-2"
          extra_paths = Dir.glob(Rails.root.join("knowledge_base", "static_docs", "*.md").to_s)
            .reject { |p| p.end_with?("/MCP.md") || p.end_with?("/eric_grok_static_rag.md") }

          extra = extra_paths.sort.map do |p|
            "--- #{File.basename(p)} ---\n" + File.read(p)
          rescue StandardError
            nil
          end.compact.join("\n\n")

          extra = extra.to_s.byteslice(0, 200_000)
          cwa_instructions += "\n\n[EXTRA STATIC DOCS]\n#{extra}" if extra.present?
        end
      end

      if @test_overrides.is_a?(Hash) && @test_overrides["prompt_cwa"].to_s.strip.present?
        path = @test_overrides["prompt_cwa"].to_s
        if File.exist?(path)
          cwa_instructions += "\n\n--- CWA PROMPT OVERRIDE ---\n" + File.read(path)
        end
      end

      # Inject DB Schema for CWA
      schema_path = Rails.root.join("db/schema.rb")
      if File.exist?(schema_path)
        schema_content = File.read(schema_path).scan(/create_table "([^"]+)"[^\n]*\n(.*?)\n  end/m).map do |name, body|
          "Table: #{name}\n#{body.gsub(/^    /, '  ')}"
        end.join("\n\n")
        cwa_instructions += "\n\n--- DATABASE SCHEMA ---\n#{schema_content}"
      end

      Agents::Registry.fetch(:cwa, model: model_for("cwa"), instructions: cwa_instructions, context: @context)
    end

    def build_planner_agent(cwa_agent)
      base = persona_instructions("planner") + @common_context + "\nYou MUST use tools for task breakdown."

      if @test_overrides.is_a?(Hash) && @test_overrides["planner_rag_content"].to_s.present?
        base += "\n\n--- PLANNER RAG (TEST OVERRIDE) ---\n" + @test_overrides["planner_rag_content"].to_s
      end

      if @test_overrides.is_a?(Hash) && @test_overrides["prompt_planner"].to_s.strip.present?
        path = @test_overrides["prompt_planner"].to_s
        if File.exist?(path)
          base += "\n\n--- PLANNER PROMPT OVERRIDE ---\n" + File.read(path)
        end
      end

      build_agent(
        name: "Planner",
        instructions: base,
        model: model_for("planner"),
        handoff_agents: [ cwa_agent ],
        context: @context,
        tools: [ TaskBreakdownTool.new ]
      )
    end

    def build_coordinator_agent(planner_agent, cwa_agent)
      build_agent(
        name: "Coordinator",
        instructions: persona_instructions("coordinator") + @common_context + "\nYou MUST use handoff tools to assign work. If the PRD is ready, handoff to Planner first for technical breakdown.",
        model: model_for("coordinator"),
        handoff_agents: [ planner_agent, cwa_agent ],
        context: @context
      )
    end

    def build_sap_agent(coordinator_agent)
      sap_instructions = if Ai::TestMode.enabled?
        persona_instructions("sap") + @common_context + "\nIf the request requires coordination or implementation work, you should hand off to the Coordinator."
      else
        "You are a routing agent." + @common_context + " For ANY implementation request, you MUST call `handoff_to_coordinator`. DO NOT answer directly."
      end

      # Check if prd_only mode from test_overrides
      prd_only_mode = @test_overrides.is_a?(Hash) && @test_overrides["prd_only"] == true

      build_agent(
        name: "SAP",
        instructions: sap_instructions,
        model: model_for("sap"),
        handoff_agents: prd_only_mode ? [] : [ coordinator_agent ],
        context: @context
      )
    end

    private

    def persona_instructions(key)
      personas_path = Rails.root.join("knowledge_base", "personas.yml")
      personas = YAML.safe_load(File.read(personas_path))
      persona = personas.fetch(key)
      persona.fetch("description")
    end

    def build_agent(name:, instructions:, model:, handoff_agents:, context: nil, tools: [])
      headers = {
        # Per-run correlation header; DO NOT use X-Request-ID here.
        # SmartProxy uses X-Request-ID to name per-call artifacts. If we set it here,
        # every LLM call in the run would share the same request id and overwrite files.
        "X-Correlation-ID" => context&.fetch(:correlation_id, nil).to_s,
        "X-Agent-Name" => name.to_s,
        "X-LLM-Base-Dir" => context&.fetch(:llm_base_dir, nil).to_s
      }.compact

      Agents::Agent.new(
        name: name,
        instructions: instructions,
        model: model,
        handoff_agents: handoff_agents,
        tools: tools,
        headers: headers
      )
    end

    def model_for(agent_key)
      override_models = @test_overrides.is_a?(Hash) ? (@test_overrides["models"] || {}) : {}
      override_models = {} unless override_models.is_a?(Hash)

      m = override_models[agent_key.to_s] || override_models[agent_key.to_sym]
      m = m.to_s.strip
      m.present? ? m : (@model || Agents.configuration.default_model)
    end
  end
end
