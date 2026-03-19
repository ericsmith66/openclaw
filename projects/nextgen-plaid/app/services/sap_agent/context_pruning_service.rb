require "securerandom"

module SapAgent
  class ContextPruningService
    attr_reader :correlation_id

    def initialize(correlation_id:)
      @correlation_id = correlation_id
    end

    def call(context:, min_keep: SapAgent::Config::PRUNE_MIN_KEEP_TOKENS, target_tokens: SapAgent::Config::PRUNE_TARGET_TOKENS)
      started_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

      tokens = SapAgent.estimate_tokens(context.to_s)
      if tokens <= target_tokens
        log_event("prune.skipped", reason: "under_target", token_count: tokens, correlation_id: correlation_id)
        return { status: "skipped", context: context, token_count: tokens }
      end

      pruned = SapAgent.prune_by_heuristic(context)
      pruned_tokens = SapAgent.estimate_tokens(pruned)

      if pruned_tokens < min_keep
        log_event("prune.warning", reason: "min_keep_floor", token_count: pruned_tokens, min_keep: min_keep, correlation_id: correlation_id)
        return { status: "warning", context: context, token_count: tokens, warning: "min_keep_floor" }
      end

      elapsed = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      log_event("prune.complete", pruned_tokens: pruned_tokens, original_tokens: tokens, correlation_id: correlation_id, elapsed_ms: elapsed)

      { status: "pruned", context: minify_context(pruned), token_count: pruned_tokens, original_tokens: tokens, elapsed_ms: elapsed }
    rescue StandardError => e
      log_event("prune.error", reason: e.message, correlation_id: correlation_id)
      { status: "error", context: context, token_count: tokens }
    end

    private

    def prune_by_heuristic(context)
      items = context.is_a?(Array) ? context : context.to_s.split("\n").reject(&:blank?)

      scored = items.map do |chunk|
        relevance = ollama_relevance(chunk)
        age_score = age_weight(chunk)
        weight = (0.7 * relevance) + (0.3 * age_score)
        { chunk: chunk, weight: weight }
      end

      sorted = scored.sort_by { |c| -c[:weight] }
      kept = []
      sorted.each do |entry|
        kept << entry[:chunk]
        break if SapAgent.estimate_tokens(kept.join("\n\n")) >= SapAgent::Config::PRUNE_MIN_KEEP_TOKENS
      end

      kept.join("\n\n")
    end

    def ollama_relevance(chunk)
      # Stub relevance to 1.0; in production, call model. Tests will stub.
      1.0
    end

    def age_weight(chunk)
      # Parse timestamps; if older than 30 days, downweight to 0.
      match = chunk.to_s.match(/(\d{4}-\d{2}-\d{2})/)
      return 1.0 unless match

      begin
        date = Date.parse(match[1])
        (Date.today - date) > 30 ? 0.0 : 1.0
      rescue ArgumentError
        1.0
      end
    end

    def minify_context(text)
      text.to_s.split("\n").map do |line|
        if line.include?("|")
          parts = line.split("|").map(&:strip)
          parts.take(2).join(" | ")
        else
          line
        end
      end.join("\n")
    end

    def estimate_tokens(text)
      (text.to_s.length / 4.0).ceil
    end

    def log_event(event, data = {})
      payload = {
        timestamp: Time.now.utc.iso8601,
        uuid: SecureRandom.uuid,
        correlation_id: correlation_id,
        elapsed_ms: data.delete(:elapsed_ms)
      }.merge(data).merge(event: event).compact

      logger.info(payload.to_json)
    end

    def logger
      @logger ||= Logger.new(Rails.root.join("agent_logs/sap.log"))
    end
  end
end
