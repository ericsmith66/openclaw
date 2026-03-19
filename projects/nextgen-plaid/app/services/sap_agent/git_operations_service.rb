require "open3"
require "securerandom"
require "fileutils"

module SapAgent
  class GitOperationsService
    attr_reader :task_id, :branch, :correlation_id, :model_used

    def initialize(task_id:, branch:, correlation_id:, model_used:)
      @task_id = task_id
      @branch = branch
      @correlation_id = correlation_id
      @model_used = model_used
    end

    def queue_handshake(artifact:, task_summary:, idempotency_uuid:, artifact_path: nil)
      started_at = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)

      duplicate = SapAgent.git_log_for_uuid(idempotency_uuid)
      if duplicate
        log_event("queue_handshake.duplicate", idempotency_uuid: idempotency_uuid, commit_hash: duplicate)
        return { status: "skipped", reason: "duplicate", commit_hash: duplicate, idempotency_uuid: idempotency_uuid }
      end

      stashed = false
      stash_applied = false
      unless SapAgent.git_status_clean?
        3.times do |attempt|
          stashed = SapAgent.stash_working_changes(idempotency_uuid)
          log_event("queue_handshake.stash", attempt: attempt + 1, idempotency_uuid: idempotency_uuid, stashed: stashed)
          break if stashed && SapAgent.git_status_clean?
        end
        unless stashed && SapAgent.git_status_clean?
          log_event("queue_handshake.error", reason: "dirty_workspace", idempotency_uuid: idempotency_uuid)
          return { status: "error", reason: "dirty_workspace" }
        end
      end

      target_path = artifact_path || Rails.root.join("knowledge_base/epics/AGENT-02C/queue_artifacts", "#{task_id}.json")
      SapAgent.write_artifact(target_path, artifact)
      commit_message = "AGENT-02C-#{task_id}: #{task_summary} by SAP [Links to PRD: AGENT-02C-0040]"

      unless SapAgent.git_add(target_path)
        log_event("queue_handshake.error", reason: "git_add_failed", idempotency_uuid: idempotency_uuid)
        return { status: "error", reason: "git_add_failed" }
      end

      commit_hash = SapAgent.git_commit(commit_message, idempotency_uuid)
      unless commit_hash
        log_event("queue_handshake.error", reason: "git_commit_failed", idempotency_uuid: idempotency_uuid)
        return { status: "error", reason: "git_commit_failed" }
      end

      tests_ok = SapAgent.tests_green?
      unless tests_ok
        log_event("queue_handshake.push_skipped", reason: "tests_failed", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash)
        stash_applied = SapAgent.pop_stash_with_retry if stashed
        return { status: "error", reason: "tests_failed", commit_hash: commit_hash, idempotency_uuid: idempotency_uuid }
      end

      if ENV["DRY_RUN"].present?
        log_event("queue_handshake.dry_run", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash)
      else
        push_ok = SapAgent.git_push(branch)
        unless push_ok
          log_event("queue_handshake.error", reason: "push_failed", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash)
          stash_applied = SapAgent.pop_stash_with_retry if stashed
          return { status: "error", reason: "push_failed", commit_hash: commit_hash, idempotency_uuid: idempotency_uuid }
        end
      end

      if stashed
        stash_applied = SapAgent.pop_stash_with_retry
        unless stash_applied
          log_event("queue_handshake.error", reason: "stash_apply_conflict", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash)
          return { status: "error", reason: "stash_apply_conflict", commit_hash: commit_hash, idempotency_uuid: idempotency_uuid }
        end
      end

      elapsed = ((::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      log_event("queue_handshake.complete", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash, elapsed_ms: elapsed)
      { status: "committed", commit_hash: commit_hash, idempotency_uuid: idempotency_uuid, elapsed_ms: elapsed }
    rescue StandardError => e
      log_event("queue_handshake.error", reason: e.message, idempotency_uuid: idempotency_uuid)
      { status: "error", reason: e.message }
    ensure
      stash_applied ||= false
      SapAgent.pop_stash_with_retry if stashed && !stash_applied
    end

    private

    def git_log_for_uuid(idempotency_uuid)
      stdout, status = Open3.capture3("git", "log", "--pretty=format:%H", "--grep", idempotency_uuid.to_s)
      return nil unless status.success?

      stdout.to_s.split("\n").reject(&:empty?).first
    end

    def git_status_clean?
      stdout, status = Open3.capture3("git", "status", "--porcelain")
      status.success? && stdout.to_s.strip.empty?
    end

    def stash_working_changes(idempotency_uuid)
      _, status = Open3.capture3("git", "stash", "push", "-u", "-m", "sap-queue-handshake-#{idempotency_uuid}")
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
