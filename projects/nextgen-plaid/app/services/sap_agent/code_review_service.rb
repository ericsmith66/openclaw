require "json"
require "open3"
require "securerandom"

module SapAgent
  class CodeReviewService
    attr_reader :task_id, :branch, :correlation_id, :model_used

    def initialize(task_id:, branch:, correlation_id:, model_used:)
      @task_id = task_id
      @branch = branch
      @correlation_id = correlation_id
      @model_used = model_used
    end

    def call(files: nil)
      started_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

      selected_files = files&.presence || SapAgent.diff_files(branch)
      filtered_files = prioritize_files(selected_files).take(5)

      log_event("code_review.start", files: filtered_files)

      contents = SapAgent.fetch_contents(filtered_files)
      token_count = estimate_tokens(contents.values.join("\n"))

      if token_count > SapAgent::Config::TOKEN_BUDGET
        log_event("code_review.abort", reason: "token_budget_exceeded", token_count: token_count)
        return { error: "Budget exceeded", token_count: token_count }
      end

      score = 100
      offenses = []
      begin
        offenses = SapAgent.run_rubocop(filtered_files)
        offenses = offenses.first(SapAgent::Config::OFFENSE_LIMIT)
        score = [ 100 - (offenses.size * 5), 0 ].max
      rescue StandardError => e
        log_event("code_review.rubocop_error", error: e.message)
      end

      if score < SapAgent::Config::SCORE_ESCALATE_THRESHOLD || token_count > 500
        @model_used = ENV["ESCALATE_LLM"]&.presence || SapAgent::Config::MODEL_ESCALATE
      end

      redacted_contents = contents.transform_values { |val| SapAgent::Redactor.redact(val) }
      output = build_output(offenses, redacted_contents)

      elapsed = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      log_event("code_review.complete", score: score, elapsed_ms: elapsed, model_used: model_used)

      output
    end

    private

    def diff_files
      base_ref = branch || "HEAD"
      stdout, = Open3.capture3("git", "diff", "--name-only", base_ref)
      files = stdout.to_s.split("\n").map(&:strip).reject(&:empty?)
      files.reject { |f| f.match?(/\.(bin|jpg|png|gif|jpeg)$/i) }
    rescue StandardError => e
      log_event("code_review.diff_fallback", error: e.message)
      []
    end

    def prioritize_files(files)
      priority = lambda do |path|
        return 0 if path.start_with?("app/models")
        return 1 if path.start_with?("app/services")
        return 2 if path.start_with?("spec") || path.start_with?("test")

        3
      end

      files.sort_by { |f| [ priority.call(f), f.length ] }
    end

    def fetch_contents(files)
      files.each_with_object({}) do |file, memo|
        memo[file] = File.read(Rails.root.join(file))
      rescue StandardError => e
        log_event("code_review.fetch_error", file: file, error: e.message)
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

      log_event("code_review.rubocop_stderr", stderr: stderr.strip) unless stderr.to_s.strip.empty?
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
      log_event("code_review.rubocop_timeout", timeout_seconds: SapAgent::Config::RUBOCOP_TIMEOUT_SECONDS)
      raise
    rescue StandardError => e
      log_event("code_review.rubocop_error", error: e.message)
      []
    end

    def build_output(offenses, contents)
      {
        "strengths" => [ "Reviewed #{contents.keys.size} files" ],
        "weaknesses" => offenses.empty? ? [] : [ "Found #{offenses.size} RuboCop offenses" ],
        "issues" => offenses,
        "recommendations" => offenses.map { |o| "Address: #{o["offense"]} (line #{o["line"]})" },
        "files" => contents
      }
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

    def estimate_tokens(text)
      (text.to_s.length / 4.0).ceil
    end

    def logger
      @logger ||= Logger.new(Rails.root.join("agent_logs/sap.log"))
    end
  end
end
