require "json"
require "open3"
require "tempfile"
require "securerandom"
require "fileutils"

module SapAgent
  COMMAND_MAPPING = {
    "generate" => SapAgent::GenerateCommand,
    "qa" => SapAgent::QaCommand,
    "debug" => SapAgent::DebugCommand,
    "health" => SapAgent::HealthCommand
  }.freeze

  class << self
    attr_accessor :task_id, :branch, :correlation_id, :model_used

    # Backward-compatible entrypoint.
    #
    # Legacy usage:
    #   SapAgent.process("generate", { query: ..., user_id: ... })
    #
    # New PRD-50F usage:
    #   SapAgent.process("my question", research: true)
    #   #=> { response:, tools_used:, loop_count:, model_used: }
    def process(query_or_type, payload = nil, research: false, request_id: nil, privacy_level: nil, max_cost_tier: nil)
      if payload.is_a?(Hash)
        return process_command(query_or_type, payload)
      end

      process_query(
        query_or_type,
        research: research,
        request_id: request_id,
        privacy_level: privacy_level,
        max_cost_tier: max_cost_tier
      )
    end

    def process_command(query_type, payload)
      command_class = COMMAND_MAPPING[query_type.to_s]
      raise "Unknown query type: #{query_type}" unless command_class

      result = command_class.new(payload).execute

      if result.is_a?(Hash) && result[:response].present? && !result[:response].include?("[CONTEXT START]")
        user_id = payload[:user_id] || payload["user_id"]
        persona_id = payload[:persona_id] || payload["persona_id"]
        sap_run_id = payload[:sap_run_id] || payload["sap_run_id"]
        prefix = SapAgent::RagProvider.build_prefix(query_type, user_id, persona_id, sap_run_id)
        result = result.merge(response: "#{prefix}\n\n#{result[:response]}")
      end

      result
    end

    WEB_SEARCH_TOOL = {
      type: "function",
      function: {
        name: "web_search",
        description: "Search the web for up-to-date information.",
        parameters: {
          type: "object",
          properties: {
            query: { type: "string", description: "Search query" },
            num_results: { type: "integer", description: "Number of results (default 5)" }
          },
          required: [ "query" ]
        }
      }
    }.freeze

    def process_query(query, research:, request_id:, privacy_level:, max_cost_tier:)
      decision = Ai::RoutingPolicy.call(
        prompt: query,
        research_requested: !!research,
        privacy_level: privacy_level,
        max_cost_tier: max_cost_tier
      )

      tools = decision.use_live_search ? [ WEB_SEARCH_TOOL ] : nil
      messages = []

      if decision.use_live_search
        messages << {
          role: "system",
          content: "You may use the web_search tool when up-to-date information is required. Use it only if it materially improves the answer."
        }
      end

      messages << { role: "user", content: query.to_s }

      resp = AiFinancialAdvisor.chat_completions(
        messages: messages,
        model: decision.model_id,
        request_id: request_id,
        tools: tools,
        max_loops: decision.max_loops
      )

      resp = { "response" => resp } unless resp.is_a?(Hash)

      smart_proxy = resp["smart_proxy"].is_a?(Hash) ? resp["smart_proxy"] : {}
      tool_loop = smart_proxy["tool_loop"].is_a?(Hash) ? smart_proxy["tool_loop"] : {}

      {
        response: resp.dig("choices", 0, "message", "content") || resp.dig("message", "content") || resp["response"],
        tools_used: Array(smart_proxy["tools_used"]),
        loop_count: tool_loop["loop_count"].to_i,
        model_used: resp["model"].presence || decision.model_id
      }
    end

    def code_review(branch: nil, files: nil, task_id: nil, correlation_id: SecureRandom.uuid)
      self.task_id = task_id
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = SapAgent::Config::MODEL_DEFAULT

      service = CodeReviewService.new(
        task_id: self.task_id,
        branch: self.branch,
        correlation_id: self.correlation_id,
        model_used: self.model_used
      )

      result = service.call(files: files)
      self.model_used = service.model_used
      result
    end

    def iterate_prompt(task:, branch: nil, correlation_id: SecureRandom.uuid, resume_token: nil, human_feedback: nil, pause: false)
      self.task_id = task
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = SapAgent::Config::MODEL_DEFAULT

      service = IterationService.new(
        task_id: self.task_id,
        branch: self.branch,
        correlation_id: self.correlation_id,
        model_used: self.model_used
      )

      result = service.iterate_prompt(
        task: task,
        resume_token: resume_token,
        human_feedback: human_feedback,
        pause: pause
      )
      self.model_used = service.model_used
      result
    end

    def adaptive_iterate(task:, branch: nil, correlation_id: SecureRandom.uuid, human_feedback: nil, start_model: nil)
      self.task_id = task
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = start_model&.presence || ENV["ESCALATE_LLM"]&.presence || SapAgent::Config::MODEL_DEFAULT

      service = IterationService.new(
        task_id: self.task_id,
        branch: self.branch,
        correlation_id: self.correlation_id,
        model_used: self.model_used
      )

      result = service.adaptive_iterate(
        task: task,
        human_feedback: human_feedback,
        start_model: start_model
      )
      self.model_used = service.model_used
      result
    end

    def conductor(task:, branch: nil, correlation_id: SecureRandom.uuid, idempotency_uuid: SecureRandom.uuid, refiner_iterations: 3, max_jobs: 5)
      started_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      self.task_id = task
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = SapAgent::Config::MODEL_DEFAULT

      requested_jobs = 2 + refiner_iterations # outliner + reviewer + refiners
      if requested_jobs > max_jobs
        log_conductor_event("conductor.aborted", reason: "max_jobs_exceeded", requested_jobs: requested_jobs, max_jobs: max_jobs, idempotency_uuid: idempotency_uuid)
        return { status: "aborted", reason: "max_jobs_exceeded", requested_jobs: requested_jobs, max_jobs: max_jobs }
      end

      state = {
        task: task,
        idempotency_uuid: idempotency_uuid,
        correlation_id: correlation_id,
        escalation_used: false,
        iterations: [],
        steps: []
      }

      failure_streak = 0
      queue_job_id = -> { SecureRandom.uuid }

      outliner_result = run_sub_agent(:outliner, state, queue_job_id.call, iteration: 1)
      failure_streak = update_failure_streak(outliner_result, failure_streak)
      state = outliner_result[:state]
      return circuit_breaker_fallback(state) if circuit_breaker_tripped?(failure_streak)

      refiner_iterations.times do |idx|
        sub_result = run_sub_agent(:refiner, state, queue_job_id.call, iteration: idx + 1)
        failure_streak = update_failure_streak(sub_result, failure_streak)
        state = sub_result[:state]
        return circuit_breaker_fallback(state) if circuit_breaker_tripped?(failure_streak)
      end

      reviewer_result = run_sub_agent(:reviewer, state, queue_job_id.call, iteration: refiner_iterations + 1)
      failure_streak = update_failure_streak(reviewer_result, failure_streak)
      state = reviewer_result[:state]

      if circuit_breaker_tripped?(failure_streak)
        return circuit_breaker_fallback(state)
      end

      elapsed = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      log_conductor_event("conductor.complete", idempotency_uuid: idempotency_uuid, elapsed_ms: elapsed, queue_job_id: reviewer_result[:queue_job_id])

      { status: "completed", state: state, elapsed_ms: elapsed }
    rescue StandardError => e
      log_conductor_event("conductor.error", reason: e.message, idempotency_uuid: idempotency_uuid)
      { status: "error", reason: e.message }
    end
    def queue_handshake(artifact:, task_summary:, task_id:, branch: "main", correlation_id: SecureRandom.uuid, idempotency_uuid: SecureRandom.uuid, artifact_path: nil)
      self.task_id = task_id
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = SapAgent::Config::MODEL_DEFAULT

      service = GitOperationsService.new(
        task_id: self.task_id,
        branch: self.branch,
        correlation_id: self.correlation_id,
        model_used: self.model_used
      )

      service.queue_handshake(
        artifact: artifact,
        task_summary: task_summary,
        idempotency_uuid: idempotency_uuid,
        artifact_path: artifact_path
      )
    end
    def sync_backlog
      BacklogService.sync_backlog
    end

    def update_backlog(item_data)
      BacklogService.update_backlog(item_data)
    end

    def prune_backlog
      BacklogService.prune_backlog
    end

    def prune_context(context:, correlation_id: SecureRandom.uuid, min_keep: SapAgent::Config::PRUNE_MIN_KEEP_TOKENS, target_tokens: SapAgent::Config::PRUNE_TARGET_TOKENS)
      self.correlation_id = correlation_id

      service = ContextPruningService.new(correlation_id: correlation_id)
      service.call(context: context, min_keep: min_keep, target_tokens: target_tokens)
    end

    def poll_task_state(task_id)
      state_path = Rails.root.join("tmp", "sap_iter_state_#{task_id}.json")
      return { status: "pending", message: "No state found" } unless File.exist?(state_path)

      JSON.parse(File.read(state_path)).with_indifferent_access
    rescue StandardError => e
      log_iterate_event("iterate.error", error: e.message, task_id: task_id)
      { status: "error", message: e.message }
    end

    def decompose(task_id, user_id, query)
      AgentLog.create!(
        task_id: task_id,
        user_id: user_id,
        persona: "SAP",
        action: "DECOMPOSE_START",
        details: "Starting decomposition for query: #{query}"
      )

      result = process("generate", { query: query, user_id: user_id })
      prd_content = result[:response]

      AgentLog.create!(
        task_id: task_id,
        user_id: user_id,
        persona: "SAP",
        action: "DECOMPOSE_SUCCESS",
        details: "Generated PRD: #{prd_content[0..200]}..."
      )

      AgentQueueJob.set(queue: :sap_to_cwa).perform_later(task_id, {
        prd: prd_content,
        user_id: user_id
      })
    rescue StandardError => e
      AgentLog.create!(
        task_id: task_id,
        user_id: user_id,
        persona: "SAP",
        action: "DECOMPOSE_FAILURE",
        details: e.message
      )
      raise e
    end

    def diff_files(branch = nil)
      base_ref = branch || "HEAD"
      stdout, = Open3.capture3("git", "diff", "--name-only", base_ref)
      files = stdout.to_s.split("\n").map(&:strip).reject(&:empty?)
      files.reject { |f| f.match?(/\.(bin|jpg|png|gif|jpeg)$/i) }
    rescue StandardError => e
      []
    end

    def fetch_contents(files)
      files.each_with_object({}) do |file, memo|
        memo[file] = File.read(Rails.root.join(file))
      rescue StandardError => e
        # Skip files that can't be read
      end
    end

    def run_rubocop(files)
      return [] if files.empty?

      stdout = ""
      stderr = ""
      status = nil
      cmd = [
        "bundle", "exec", "rubocop",
        "--format", "json",
        "--fail-level", "E",
        "--only", "Lint,Security,Style",
        "--config", Rails.root.join("config/rubocop.yml").to_s,
        *files
      ]

      SapAgent::TimeoutWrapper.with_timeout(SapAgent::Config::RUBOCOP_TIMEOUT_SECONDS) do
        stdout, stderr, status = Open3.capture3(*cmd)
      end

      return [] unless status&.success?

      data = JSON.parse(stdout)
      offenses = data.fetch("files", []).flat_map { |f| f["offenses"] }
      offenses.first(SapAgent::Config::OFFENSE_LIMIT).map do |offense|
        {
          "offense" => offense["message"],
          "line" => offense.dig("location", "start_line")
        }
      end
    rescue Timeout::Error
      raise
    rescue StandardError => e
      []
    end

    def estimate_tokens(text)
      (text.to_s.length / 4.0).ceil
    end

    def generate_iteration_output(context, iteration_number, model)
      prompt = <<~PROMPT
        You are the SAP (Senior Architect and Product Manager) Agent.

        Iteration: #{iteration_number}

        Context:
        #{context}

        Please provide a detailed, actionable response to continue this task.
        Focus on clarity, completeness, and practical implementation details.
      PROMPT
      response = AiFinancialAdvisor.ask(prompt, model: model, request_id: SecureRandom.uuid)
      response || "No response from #{model}"
    end

    def score_output(output, context)
      # Default heuristic score; tests will stub this method for deterministic behavior.
      length_score = [ (output.to_s.length + context.to_s.length) / 10, 100 ].min
      [ length_score, SapAgent::Config::SCORE_STOP_THRESHOLD ].min
    end

    def git_log_for_uuid(uuid)
      stdout, status = Open3.capture3("git", "log", "--pretty=format:%H", "--grep", uuid.to_s)
      return nil unless status.success?
      stdout.to_s.split("\n").reject(&:empty?).first
    end

    def git_status_clean?
      stdout, status = Open3.capture3("git", "status", "--porcelain")
      status.success? && stdout.to_s.strip.empty?
    end

    def ollama_relevance(chunk)
      # Stub relevance to 1.0; in production, call model. Tests will stub.
      1.0
    end

    def prune_by_heuristic(context)
      items = context.is_a?(Array) ? context : context.to_s.split("\n").reject(&:blank?)
      scored = items.map do |chunk|
        relevance = ollama_relevance(chunk)
        age_score = age_weight(chunk)
        weight = (0.7 * relevance) + (0.3 * age_score)
        { chunk: chunk, weight: weight }
      end
      sorted = scored.sort_by { |c| -c[:weight] }
      sorted.map { |s| s[:chunk] }
    end

    def age_weight(chunk)
      # Parse timestamps; if older than 30 days, downweight to 0.
      match = chunk.to_s.match(/(\d{4}-\d{2}-\d{2})/)
      return 1.0 unless match
      begin
        date = Date.parse(match[1])
        days_old = (Date.today - date).to_i
        return 0.0 if days_old > 30
        1.0 - (days_old / 30.0)
      rescue ArgumentError
        1.0
      end
    end

    def stash_working_changes(idempotency_uuid)
      _, status = Open3.capture3("git", "stash", "push", "-u", "-m", "sap-queue-handshake-#{idempotency_uuid}")
      status.success?
    end

    def write_artifact(path, artifact)
      FileUtils.mkdir_p(File.dirname(path))
      content = artifact.is_a?(String) ? artifact : artifact.to_json
      File.write(path, content)
      path
    end

    def git_add(path)
      _, status = Open3.capture3("git", "add", path.to_s)
      status.success?
    end

    def git_commit(message, idempotency_uuid)
      env = {
        "GIT_AUTHOR_NAME" => "SAP Agent",
        "GIT_AUTHOR_EMAIL" => "sap@nextgen-plaid.com",
        "GIT_COMMITTER_NAME" => "SAP Agent",
        "GIT_COMMITTER_EMAIL" => "sap@nextgen-plaid.com"
      }

      commit_body = "Idempotency-UUID: #{idempotency_uuid}"
      _, status = Open3.capture3(env, "git", "commit", "-m", message, "-m", commit_body)
      return nil unless status.success?

      stdout, rev_status = Open3.capture3("git", "rev-parse", "HEAD")
      return nil unless rev_status.success?

      stdout.to_s.strip
    end

    def tests_green?
      system("bundle", "exec", "rails", "test")
    end

    def git_push(branch)
      remote = ENV.fetch("GIT_REMOTE", "origin")
      _, status = Open3.capture3("git", "push", remote.to_s, branch.to_s)
      status.success?
    end

    def pop_stash_with_retry
      3.times do
        stdout, status = Open3.capture3("git", "stash", "pop")
        return true if status.success?

        return false if stdout.to_s.include?("Merge conflict")
      end

      false
    end

    def sleep(seconds)
      Kernel.sleep(seconds)
    end

    private


    def log_event(event, data = {})
      payload = {
        timestamp: Time.now.utc.iso8601,
        task_id: task_id,
        branch: branch,
        uuid: SecureRandom.uuid,
        correlation_id: correlation_id,
        model_used: model_used,
        elapsed_ms: data.delete(:elapsed_ms),
        score: data.delete(:score)
      }.merge(data).merge(event: event).compact

      logger.info(payload.to_json)
    end

    # Backward-compatible aliases
    alias_method :log_review_event, :log_event
    alias_method :log_iterate_event, :log_event
    alias_method :log_queue_event, :log_event
    alias_method :log_conductor_event, :log_event


    def logger
      @logger ||= Logger.new(Rails.root.join("agent_logs/sap.log"))
    end

    def run_sub_agent(sub_agent, state, queue_job_id, iteration: nil)
      payload = state.merge(queue_job_id: queue_job_id, sub_agent: sub_agent, iteration: iteration)
      log_conductor_event("conductor.route", payload)

      result = nil
      SapAgent::TimeoutWrapper.with_timeout(1) do
        result =
          case sub_agent
          when :outliner then sub_agent_outliner(state)
          when :refiner then sub_agent_refiner(state, iteration)
          when :reviewer then sub_agent_reviewer(state)
          else
            { status: "error", state: state, reason: "unknown_sub_agent" }
          end
      end

      result ||= { status: "error", state: state, reason: "no_result" }
      new_state = safe_state_roundtrip(result[:state] || state)
      log_conductor_event("conductor.state_saved", sub_agent: sub_agent, queue_job_id: queue_job_id, iteration: iteration)

      result.merge(state: new_state, queue_job_id: queue_job_id)
    rescue StandardError => e
      log_conductor_event("conductor.error", sub_agent: sub_agent, queue_job_id: queue_job_id, reason: e.message)
      { status: "error", reason: e.message, state: state, queue_job_id: queue_job_id }
    end

    def sub_agent_outliner(state)
      steps = [ "Gather requirements", "Design", "Implement", "Test" ]
      new_state = state.dup
      new_state[:steps] = (state[:steps] || []) + [ "outliner" ]
      new_state[:outline] = steps
      { status: "ok", state: new_state }
    end

    def sub_agent_refiner(state, iteration)
      new_state = state.dup
      refinements = new_state[:refinements] || []
      refinements << "refinement-#{iteration}"
      new_state[:refinements] = refinements
      new_state[:steps] = (state[:steps] || []) + [ "refiner-#{iteration}" ]
      new_state[:iterations] = (state[:iterations] || []) + [ { iteration: iteration, output: "refined step #{iteration}" } ]
      { status: "ok", state: new_state }
    end

    def sub_agent_reviewer(state)
      new_state = state.dup
      new_state[:steps] = (state[:steps] || []) + [ "reviewer" ]
      new_state[:score] = 85
      { status: "ok", state: new_state }
    end

    def safe_state_roundtrip(state)
      parsed = JSON.parse(state.to_json)
      parsed.is_a?(Hash) ? parsed.with_indifferent_access : state
    rescue JSON::ParserError
      log_conductor_event("conductor.error", reason: "state_validation_failed")
      state
    end

    def update_failure_streak(result, current_streak)
      return 0 if result[:status] == "ok"

      current_streak + 1
    end

    def circuit_breaker_tripped?(failure_streak)
      failure_streak >= 3
    end

    def circuit_breaker_fallback(state)
      log_conductor_event("conductor.circuit_breaker", reason: "failure_streak", state: state)
      { status: "fallback", reason: "circuit_breaker", state: state }
    end
  end
end
