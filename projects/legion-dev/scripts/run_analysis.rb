# Usage: rails runner scripts/run_analysis.rb
# Analyzes all completed/failed runs today

runs = WorkflowRun.where("created_at > ?", Time.current.beginning_of_day)
                  .where(status: %w[completed failed])
                  .order(:id)

puts "=" * 100
puts "Run Analysis - #{Time.current.strftime('%Y-%m-%d')}"
puts "=" * 100

runs.each do |run|
  name = run.team_membership&.config&.dig("name") || "?"
  model = run.team_membership&.config&.dig("model") || "?"

  responses = run.workflow_events.where(event_type: "response.complete")
  turns = responses.count

  prompt_tokens = 0
  completion_tokens = 0
  responses.each do |e|
    u = e.payload&.dig("usage") || {}
    prompt_tokens += (u["prompt_tokens"] || u["input_tokens"] || 0).to_i
    completion_tokens += (u["completion_tokens"] || u["output_tokens"] || 0).to_i
  end

  tool_calls = run.workflow_events.where(event_type: "tool.called").count
  tool_errors = run.workflow_events.where(event_type: "tool.result")
    .select { |e| (e.payload&.dig("result") || "").include?("Error") || (e.payload&.dig("result") || "").include?("STDERR") }
    .count

  file_edits = run.workflow_events.where(event_type: "tool.called")
    .select { |e| e.payload&.dig("tool_name") == "power---file_edit" }.count
  file_edit_fails = run.workflow_events.where(event_type: "tool.result")
    .joins("INNER JOIN workflow_events AS prev ON prev.workflow_run_id = workflow_events.workflow_run_id")
    .none? # skip complex join, count from tool results instead

  bash_calls = run.workflow_events.where(event_type: "tool.called")
    .select { |e| e.payload&.dig("tool_name") == "power---bash" }.count
  file_reads = run.workflow_events.where(event_type: "tool.called")
    .select { |e| e.payload&.dig("tool_name") == "power---file_read" }.count
  file_writes = run.workflow_events.where(event_type: "tool.called")
    .select { |e| e.payload&.dig("tool_name") == "power---file_write" }.count
  search_calls = run.workflow_events.where(event_type: "tool.called")
    .select { |e| (e.payload&.dig("tool_name") || "").include?("search") }.count
  edit_calls = run.workflow_events.where(event_type: "tool.called")
    .select { |e| e.payload&.dig("tool_name") == "power---file_edit" }.count

  # Check for "Search term not found" in tool results (failed edits)
  failed_edits = run.workflow_events.where(event_type: "tool.result")
    .select { |e| (e.payload&.dig("result") || "").include?("Search term not found") }.count

  # Check for skill activations
  skill_calls = run.workflow_events.where(event_type: "tool.called")
    .select { |e| (e.payload&.dig("tool_name") || "").include?("skill") }.count

  dur = run.duration_ms ? (run.duration_ms / 60000.0).round(1) : 0

  puts ""
  puts "WR##{run.id} | #{name} (#{model}) | #{run.status} | #{dur}min | #{turns} turns"
  puts "  Tokens: #{(prompt_tokens / 1000.0).round(0)}K prompt / #{(completion_tokens / 1000.0).round(0)}K completion = #{((prompt_tokens + completion_tokens) / 1000.0).round(0)}K total"
  puts "  Tools: #{tool_calls} calls (#{bash_calls} bash, #{file_reads} read, #{file_writes} write, #{edit_calls} edit, #{search_calls} search)"
  puts "  Failed edits (search not found): #{failed_edits}" if failed_edits > 0
  puts "  Skills activated: #{skill_calls}" if skill_calls > 0
  puts "  Prompt/turn: #{turns > 0 ? (prompt_tokens / turns / 1000.0).round(1) : 0}K avg"
  puts "  Task: #{run.prompt&.first(100)}"
end

# Summary stats
puts ""
puts "=" * 100
puts "SUMMARY"
puts "=" * 100

total_prompt = 0
total_completion = 0
total_duration = 0
total_turns = 0
total_failed_edits = 0

runs.each do |run|
  responses = run.workflow_events.where(event_type: "response.complete")
  total_turns += responses.count
  responses.each do |e|
    u = e.payload&.dig("usage") || {}
    total_prompt += (u["prompt_tokens"] || u["input_tokens"] || 0).to_i
    total_completion += (u["completion_tokens"] || u["output_tokens"] || 0).to_i
  end
  total_duration += (run.duration_ms || 0)
  total_failed_edits += run.workflow_events.where(event_type: "tool.result")
    .select { |e| (e.payload&.dig("result") || "").include?("Search term not found") }.count
end

puts "Runs: #{runs.count} (#{runs.select { |r| r.status == 'completed' }.count} completed, #{runs.select { |r| r.status == 'failed' }.count} failed)"
puts "Total time: #{(total_duration / 60000.0).round(1)} min"
puts "Total turns: #{total_turns}"
puts "Total tokens: #{(total_prompt / 1_000_000.0).round(2)}M prompt / #{(total_completion / 1000.0).round(0)}K completion"
puts "Total failed edits: #{total_failed_edits} (wasted turns)"
puts "Avg prompt/turn: #{total_turns > 0 ? (total_prompt / total_turns / 1000.0).round(1) : 0}K"
