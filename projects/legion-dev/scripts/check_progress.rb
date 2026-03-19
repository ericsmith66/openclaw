# Usage: rails runner scripts/check_progress.rb [WORKFLOW_RUN_ID]
# Default: latest workflow run

run_id = ARGV[0] || WorkflowRun.order(id: :desc).first.id
run = WorkflowRun.find(run_id)

tasks = run.tasks.order(:position)
completed = tasks.count { |t| t.completed? }
failed = tasks.count { |t| t.failed? }
running = tasks.count { |t| t.status.to_s == "running" }
pending = tasks.count { |t| t.status.to_s == "pending" }

puts "WorkflowRun ##{run_id} — #{run.project.name}"
puts "Progress: #{completed}/#{tasks.size} done | #{running} running | #{pending} pending | #{failed} failed"
puts ""

total_tokens_all = 0
total_prompt_all = 0
total_completion_all = 0

tasks.each do |t|
  status_icon = case t.status.to_s
  when "completed" then "✅"
  when "running"   then "🔄"
  when "failed"    then "❌"
  when "skipped"   then "⏭️"
  else "⏳"
  end

  duration = ""
  turns = 0
  total_tokens = 0
  prompt_tokens = 0
  completion_tokens = 0

  if t.execution_run_id
    exec_run = WorkflowRun.find(t.execution_run_id)

    # Duration
    if exec_run.duration_ms && exec_run.duration_ms > 0
      secs = exec_run.duration_ms / 1000.0
      if secs >= 60
        duration = "#{(secs / 60).floor}m #{(secs % 60).round}s"
      else
        duration = "#{secs.round(1)}s"
      end
    end

    # Turns (response.complete events = one LLM round-trip each)
    completions = exec_run.workflow_events.where(event_type: "response.complete")
    turns = completions.count

    # Tokens (sum across all turns)
    completions.pluck(:payload).each do |p|
      usage = p["usage"] || {}
      total_tokens += (usage["total_tokens"] || 0)
      prompt_tokens += (usage["prompt_tokens"] || 0)
      completion_tokens += (usage["completion_tokens"] || 0)
    end

    total_tokens_all += total_tokens
    total_prompt_all += prompt_tokens
    total_completion_all += completion_tokens

  elsif t.status.to_s == "running"
    started = t.updated_at
    elapsed = Time.current - started
    if elapsed >= 60
      duration = "#{(elapsed / 60).floor}m #{(elapsed % 60).round}s so far"
    else
      duration = "#{elapsed.round(0)}s so far"
    end

    # Live turns/tokens for running task
    exec_run = WorkflowRun.where(task: t).order(id: :desc).first
    if exec_run
      completions = exec_run.workflow_events.where(event_type: "response.complete")
      turns = completions.count
      completions.pluck(:payload).each do |p|
        usage = p["usage"] || {}
        total_tokens += (usage["total_tokens"] || 0)
        prompt_tokens += (usage["prompt_tokens"] || 0)
        completion_tokens += (usage["completion_tokens"] || 0)
      end
    end
  end

  agent = t.team_membership.config["name"] rescue "?"
  model = t.team_membership.config["model"] rescue "?"

  # Build stats line
  stats = []
  stats << duration if duration.length > 0
  stats << "#{turns} turns" if turns > 0
  stats << "#{format_tokens(total_tokens)} tokens (#{format_tokens(prompt_tokens)}p/#{format_tokens(completion_tokens)}c)" if total_tokens > 0
  stats_str = stats.any? ? " — #{stats.join(' | ')}" : ""

  puts "#{status_icon} #{t.position}/#{tasks.size}: [#{t.task_type}] #{agent} (#{model})#{stats_str}"
  puts "    #{t.prompt.to_s[0..80]}"
end

# Total elapsed
first_completed = tasks.select(&:completed?).filter_map { |t|
  WorkflowRun.find(t.execution_run_id).created_at rescue nil
}.min

if first_completed
  total_elapsed = Time.current - first_completed
  mins = (total_elapsed / 60).floor
  secs = (total_elapsed % 60).round
  total_task_time = tasks.filter_map { |t|
    t.execution_run_id ? (WorkflowRun.find(t.execution_run_id).duration_ms || 0) : 0
  }.sum / 1000.0

  puts ""
  puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  puts "Total: #{mins}m #{secs}s elapsed | #{(total_task_time / 60).round(1)}m task time | #{completed}/#{tasks.size} done"
  puts "Tokens: #{format_tokens(total_tokens_all)} total (#{format_tokens(total_prompt_all)} prompt / #{format_tokens(total_completion_all)} completion)"
  puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
end

BEGIN {
  def format_tokens(n)
    if n >= 1_000_000
      "#{(n / 1_000_000.0).round(1)}M"
    elsif n >= 1_000
      "#{(n / 1_000.0).round(1)}K"
    else
      n.to_s
    end
  end
}
