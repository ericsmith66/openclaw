# frozen_string_literal: true

require "optparse"
require "securerandom"

module Agents
  class SdlcTestOptions
    class HelpRequested < StandardError; end

    DEFAULT_MODEL = "llama3.1:70b"
    DEFAULT_MODE = "end_to_end"
    DEFAULT_STAGE = "backlog"
    DEFAULT_SANDBOX_LEVEL = "strict"

    def self.parse(argv)
      options = {
        input: nil,
        mode: DEFAULT_MODE,
        stage: DEFAULT_STAGE,
        start_agent: nil,
        prd_only: false,
        run_id: nil,
        rescore_only: false,
        prd_path: nil,
        artifact_id: nil,
        prompt_sap: nil,
        prompt_coord: nil,
        prompt_planner: nil,
        prompt_cwa: nil,
        rag_sap: nil,
        rag_coord: nil,
        rag_planner: nil,
        rag_cwa: nil,
        model_sap: DEFAULT_MODEL,
        model_coord: DEFAULT_MODEL,
        model_planner: DEFAULT_MODEL,
        model_cwa: DEFAULT_MODEL,
        sandbox_level: DEFAULT_SANDBOX_LEVEL,
        max_tool_calls: nil,
        dry_run: false,
        debug: false
      }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: rake agent:test_sdlc[options] -- [flags]\n\nFlags:"

        opts.on("--input=QUERY", String, "Seed prompt/query (required unless --dry-run)") { |v| options[:input] = v }
        opts.on("--mode=MODE", String, "Run mode: end_to_end|stage (default: #{DEFAULT_MODE})") { |v| options[:mode] = v }
        opts.on("--stage=PHASE", String, "Artifact phase to start from (default: #{DEFAULT_STAGE})") { |v| options[:stage] = v }
        opts.on("--start-agent=NAME", String, "Force starting agent: SAP|Coordinator|CWA (overrides stage-based default routing)") do |v|
          options[:start_agent] = v
        end
        opts.on("--prd-only", "Generate a PRD and stop (skip Coordinator/Planner/CWA)") do
          options[:prd_only] = true
        end
        opts.on("--run-id=RUN_ID", String, "Correlation/run id (auto-generated if absent)") { |v| options[:run_id] = v }

        opts.on("--rescore-only", "Skip agents; rescore/validate an existing run_id using stored artifacts/logs") do
          options[:rescore_only] = true
        end

        opts.on("--artifact-id=ID", Integer, "Artifact id to use as PRD source (uses payload['content']; primarily for --stage=in_analysis)") do |v|
          options[:artifact_id] = v
        end

        opts.on("--prd-path=PATH", String, "Path to a PRD markdown file to use as artifact.payload['content'] (primarily for --stage=in_analysis)") do |v|
          options[:prd_path] = v
        end

        opts.on("--prompt-sap=PATH", String, "Override SAP prompt template (ERB). Locals: input, rag_content") { |v| options[:prompt_sap] = v }
        opts.on("--prompt-coord=PATH", String, "Override Coordinator prompt template (ERB). Locals: input, rag_content") { |v| options[:prompt_coord] = v }
        opts.on("--prompt-planner=PATH", String, "Override/append Planner prompt/instructions (markdown/plain text)") { |v| options[:prompt_planner] = v }
        opts.on("--prompt-cwa=PATH", String, "Override/append CWA prompt/instructions (markdown/plain text)") { |v| options[:prompt_cwa] = v }
        opts.on("--rag-sap=TIERS", String, "SAP RAG tiers (comma-separated: foundation,structure,history)") { |v| options[:rag_sap] = v }
        opts.on("--rag-coord=TIERS", String, "Coordinator RAG tiers (comma-separated: foundation,structure,history)") { |v| options[:rag_coord] = v }
        opts.on("--rag-planner=TIERS", String, "Planner RAG tiers (comma-separated: foundation,structure,history)") { |v| options[:rag_planner] = v }
        opts.on("--rag-cwa=LEVEL", String, "CWA RAG level: none|tier-1|tier-2") { |v| options[:rag_cwa] = v }

        opts.on("--model-sap=MODEL", String, "SAP model (default: #{DEFAULT_MODEL})") { |v| options[:model_sap] = v }
        opts.on("--model-coord=MODEL", String, "Coordinator model (default: #{DEFAULT_MODEL})") { |v| options[:model_coord] = v }
        opts.on("--model-planner=MODEL", String, "Planner model (default: #{DEFAULT_MODEL})") { |v| options[:model_planner] = v }
        opts.on("--model-cwa=MODEL", String, "CWA model (default: #{DEFAULT_MODEL})") { |v| options[:model_cwa] = v }

        opts.on("--sandbox-level=LEVEL", String, "Sandbox level strict|loose (default: #{DEFAULT_SANDBOX_LEVEL})") do |v|
          options[:sandbox_level] = v
        end

        opts.on("--max-tool-calls=N", Integer, "Max tool calls guardrail") { |v| options[:max_tool_calls] = v }
        opts.on("--dry-run", "Skip LLM + tool calls; validate transitions/logging only") { options[:dry_run] = true }
        opts.on("--debug", "Enable verbose traces/backtraces") { options[:debug] = true }

        opts.on("-h", "--help", "Show help and examples") do
          puts opts
          puts "\nExamples:" \
               "\n  rake agent:test_sdlc -- --input=\"Run SDLC test\"" \
               "\n  rake agent:test_sdlc -- --dry-run --stage=planning" \
               "\n  rake agent:test_sdlc -- --input=\"...\" --run-id=my_run_001 --debug"
          raise HelpRequested
        end
      end

      parser.parse!(argv)

      options[:run_id] ||= SecureRandom.uuid
      validate!(options)

      options
    end

    def self.validate!(options)
      if options[:rescore_only]
        # We can rescore with only a run_id (used to locate existing logs/artifacts).
        return
      end

      mode = options[:mode].to_s
      raise ArgumentError, "Invalid --mode '#{mode}'. Must be end_to_end or stage" unless %w[end_to_end stage].include?(mode)

      unless options[:dry_run]
        raise ArgumentError, "--input is required unless --dry-run" if options[:input].to_s.strip.empty?
      end

      stage = options[:stage].to_s
      raise ArgumentError, "Invalid --stage '#{stage}'. Must be one of: #{Artifact::PHASES.join(", ")}" unless Artifact::PHASES.include?(stage)

      # In end-to-end mode we still allow --stage, but defaulting is handled by the caller.

      if options[:start_agent].present?
        agent = options[:start_agent].to_s
        raise ArgumentError, "Invalid --start-agent '#{agent}'. Must be one of: SAP, Coordinator, CWA" unless %w[SAP Coordinator CWA].include?(agent)
      end

      # PRD-only mode is only meaningful when starting at SAP.
      if options[:prd_only]
        start_agent = options[:start_agent].to_s
        start_agent = "SAP" if start_agent.blank?
        unless start_agent == "SAP"
          raise ArgumentError, "--prd-only requires --start-agent=SAP (or omit --start-agent)"
        end
      end

      if options[:prd_path].to_s.strip.present?
        path = options[:prd_path].to_s
        raise ArgumentError, "--prd-path file not found: #{path}" unless File.exist?(path)
      end

      if options[:prompt_cwa].to_s.strip.present?
        path = options[:prompt_cwa].to_s
        raise ArgumentError, "--prompt-cwa file not found: #{path}" unless File.exist?(path)
      end

      if options[:prompt_planner].to_s.strip.present?
        path = options[:prompt_planner].to_s
        raise ArgumentError, "--prompt-planner file not found: #{path}" unless File.exist?(path)
      end

      if options[:artifact_id].present?
        id = options[:artifact_id].to_i
        raise ArgumentError, "--artifact-id must be a positive integer" if id <= 0
        raise ArgumentError, "--artifact-id not found: #{id}" unless Artifact.exists?(id)
      end

      sandbox = options[:sandbox_level].to_s
      raise ArgumentError, "Invalid --sandbox-level '#{sandbox}'. Must be strict or loose" unless %w[strict loose].include?(sandbox)

      rag_cwa = options[:rag_cwa].to_s
      if rag_cwa.present? && !%w[none tier-1 tier-2].include?(rag_cwa)
        raise ArgumentError, "Invalid --rag-cwa '#{rag_cwa}'. Must be none, tier-1, or tier-2"
      end

      %i[model_sap model_coord model_cwa].each do |key|
        model = options[key].to_s
        next if Ai::ModelAllowlist.allowed?(model)
        raise ArgumentError, "Invalid #{key.to_s.tr('_', '-')} '#{model}'. Must be one of: #{Ai::ModelAllowlist.allowed_models.join(', ')}"
      end

      model_planner = options[:model_planner].to_s
      unless Ai::ModelAllowlist.allowed?(model_planner)
        raise ArgumentError, "Invalid model-planner '#{model_planner}'. Must be one of: #{Ai::ModelAllowlist.allowed_models.join(', ')}"
      end
    end
  end
end
