require "securerandom"

module SapAgent
  class IterationService
    attr_reader :task_id, :branch, :correlation_id, :model_used

    def initialize(task_id:, branch:, correlation_id:, model_used:)
      @task_id = task_id
      @branch = branch
      @correlation_id = correlation_id
      @model_used = model_used
    end

    def iterate_prompt(task:, resume_token: nil, human_feedback: nil, pause: false)
      started_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

      context = [ "Task: #{task}" ]
      context << "Human feedback: #{human_feedback}" if human_feedback&.present?

      if pause
        token = resume_token&.presence || SecureRandom.uuid
        log_event("iterate.paused", resume_token: token)
        return { status: "paused", resume_token: token, context: context.join("\n") }
      end

      iterations = []
      retry_count = 0
      current_resume_token = resume_token

      SapAgent::Config::ITERATION_CAP.times do |idx|
        iteration_number = idx + 1
        current_model = @model_used
        output = SapAgent.generate_iteration_output(context.join("\n"), iteration_number, current_model)
        iterations << { iteration: iteration_number, output: output, model_used: current_model }

        token_count = SapAgent.estimate_tokens(context.join("\n") + output.to_s)
        if token_count > SapAgent::Config::TOKEN_BUDGET
          log_event("iterate.abort", reason: "token_budget_exceeded", token_count: token_count, iteration: iteration_number)
          return { status: "aborted", reason: "token_budget_exceeded", token_count: token_count, iterations: iterations, partial_output: output }
        end

        score = SapAgent.score_output(output, context.join("\n"))
        log_event("iterate.phase", iteration: iteration_number, score: score, token_count: token_count, model_used: current_model)

        context << "Iteration #{iteration_number} output: #{output}"

        if score >= SapAgent::Config::SCORE_STOP_THRESHOLD
          elapsed = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - started_at) * 1000).round
          log_event("iterate.complete", iteration: iteration_number, score: score, elapsed_ms: elapsed, model_used: current_model)
          return { status: "completed", iterations: iterations, final_output: output, score: score, model_used: current_model, resume_token: current_resume_token }
        end

        if score < SapAgent::Config::SCORE_ESCALATE_THRESHOLD || token_count > 500
          @model_used = ENV["ESCALATE_LLM"]&.presence || SapAgent::Config::MODEL_ESCALATE
        end

        if retry_count < SapAgent::Config::BACKOFF_MS.size
          sleep(SapAgent::Config::BACKOFF_MS[retry_count] / 1000.0)
          retry_count += 1
        else
          log_event("iterate.abort", reason: "iteration_cap", iteration: iteration_number)
          return { status: "aborted", reason: "iteration_cap", iterations: iterations, final_output: output, score: score, model_used: current_model, resume_token: current_resume_token }
        end
      end

      { status: "aborted", reason: "iteration_cap", iterations: iterations, model_used: @model_used, resume_token: current_resume_token }
    rescue StandardError => e
      log_event("iterate.error", error: e.message)
      { status: "error", error: e.message, iterations: iterations }
    end

    def adaptive_iterate(task:, human_feedback: nil, start_model: nil)
      started_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      @model_used = start_model&.presence || ENV["ESCALATE_LLM"]&.presence || SapAgent::Config::MODEL_DEFAULT

      context = [ "Task: #{task}" ]
      context << "Human feedback: #{human_feedback}" if human_feedback&.present?

      iterations = []
      retry_count = 0
      escalation_used = 0
      cumulative_tokens = 0
      previous_model = @model_used

      SapAgent::Config::ADAPTIVE_ITERATION_CAP.times do |idx|
        iteration_number = idx + 1
        current_model = @model_used

        output = SapAgent.generate_iteration_output(context.join("\n"), iteration_number, current_model)
        iterations << { iteration: iteration_number, output: output, model_used: current_model }

        token_count = SapAgent.estimate_tokens(context.join("\n") + output.to_s)
        cumulative_tokens += token_count

        log_event("adaptive.iteration", iteration: iteration_number, token_count: token_count, cumulative_tokens: cumulative_tokens, model_used: current_model)

        if cumulative_tokens > SapAgent::Config::ADAPTIVE_TOKEN_BUDGET
          log_event("adaptive.abort", reason: "token_budget_exceeded", token_count: cumulative_tokens, iteration: iteration_number)
          return { status: "aborted", reason: "token_budget_exceeded", token_count: cumulative_tokens, iterations: iterations, partial_output: output }
        end

        score = SapAgent.score_output(output, context.join("\n"))
        normalized_score = normalize_score(score, current_model, previous_model)

        log_event("adaptive.scored", iteration: iteration_number, score: normalized_score, token_count: cumulative_tokens, model_used: current_model)

        context << "Iteration #{iteration_number} output: #{output}"

        if normalized_score >= SapAgent::Config::SCORE_STOP_THRESHOLD
          elapsed = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - started_at) * 1000).round
          log_event("adaptive.complete", iteration: iteration_number, score: normalized_score, elapsed_ms: elapsed, model_used: current_model)
          return { status: "completed", iterations: iterations, final_output: output, score: normalized_score, model_used: current_model }
        end

        escalation_triggered = normalized_score < SapAgent::Config::SCORE_ESCALATE_THRESHOLD || cumulative_tokens > SapAgent::Config::ADAPTIVE_TOKEN_BUDGET

        if escalation_triggered && escalation_used < SapAgent::Config::ADAPTIVE_MAX_ESCALATIONS
          next_model = next_escalation_model(current_model)
          if next_model
            escalation_used += 1
            log_event("adaptive.escalate", iteration: iteration_number, from: current_model, to: next_model, escalation_used: escalation_used)
            previous_model = current_model
            @model_used = next_model
            retry_count = 0
            next
          end
        end

        if retry_count < SapAgent::Config::ADAPTIVE_RETRY_LIMIT
          backoff_ms = SapAgent::Config::BACKOFF_MS[retry_count] || SapAgent::Config::BACKOFF_MS.last
          SapAgent::TimeoutWrapper.with_timeout((backoff_ms / 1000.0) + 0.1) { SapAgent.sleep(backoff_ms / 1000.0) }
          retry_count += 1
          previous_model = current_model
          next
        end
      end

      log_event("adaptive.abort", reason: "iteration_cap", iteration: SapAgent::Config::ADAPTIVE_ITERATION_CAP)
      { status: "aborted", reason: "iteration_cap", iterations: iterations, final_output: iterations.last&.dig(:output), model_used: @model_used }
    rescue StandardError => e
      log_event("adaptive.error", error: e.message)
      { status: "error", reason: e.message, iterations: iterations }
    end

    private

    def generate_iteration_output(context, iteration_number, model)
      prompt = build_iteration_prompt(context, iteration_number)
      response = AiFinancialAdvisor.ask(prompt, model: model, request_id: correlation_id)
      response || "No response from #{model}"
    end

    def build_iteration_prompt(context, iteration_number)
      <<~PROMPT
        You are the SAP (Senior Architect and Product Manager) Agent.

        Iteration: #{iteration_number}

        Context:
        #{context}

        Please provide a detailed, actionable response to continue this task.
        Focus on clarity, completeness, and practical implementation details.
      PROMPT
    end

    def score_output(output, context)
      # Default heuristic score; tests will stub this method for deterministic behavior.
      length_score = [ (output.to_s.length + context.to_s.length) / 10, 100 ].min
      [ length_score, SapAgent::Config::SCORE_STOP_THRESHOLD ].min
    end

    def normalize_score(score, current_model, previous_model)
      return score if current_model == previous_model

      adjusted = score * 0.95
      [ [ adjusted, 0 ].max, 100 ].min
    end

    def next_escalation_model(current_model)
      order = SapAgent::Config::ADAPTIVE_ESCALATION_ORDER
      index = order.index(current_model)
      return order.first unless index

      order[index + 1] || order.first
    end

    def estimate_tokens(text)
      (text.to_s.length / 4.0).ceil
    end

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

    def logger
      @logger ||= Logger.new(Rails.root.join("agent_logs/sap.log"))
    end
  end
end
