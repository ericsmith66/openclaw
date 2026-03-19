# Usage: rails runner scripts/activity_analysis_range.rb [start_id] [end_id]
# Deep activity analysis of workflow runs in a range

start_id = (ARGV[0] || 57).to_i
end_id = (ARGV[1] || 62).to_i

(start_id..end_id).each do |rid|
  run = WorkflowRun.find_by(id: rid)
  next unless run

  puts "=" * 80
  puts "WR##{rid} - #{run.prompt&.first(80)}"
  dur = run.duration_ms ? (run.duration_ms / 60000.0).round(1) : 0
  turns = run.workflow_events.where(event_type: "response.complete").count
  puts "Duration: #{dur}min | Turns: #{turns} | Status: #{run.status}"
  puts "=" * 80

  events = run.workflow_events.where(event_type: %w[tool.called tool.result]).order(:recorded_at)

  bash_count = 0
  bash_test_runs = 0
  read_count = 0
  write_count = 0
  edit_count = 0
  edit_fail = 0
  skill_count = 0
  grep_glob = 0
  python_edits = 0
  activity_log = []

  events.each do |e|
    if e.event_type == "tool.called"
      tool = e.payload&.dig("tool_name") || ""
      args = e.payload&.dig("arguments") || {}

      if tool == "power---bash"
        bash_count += 1
        cmd = args["command"].to_s
        if cmd.include?("rspec") || cmd.include?("bundle exec rspec")
          bash_test_runs += 1
          activity_log << "TEST-RUN: #{cmd.split('rspec').last.to_s.first(80).strip}"
        elsif cmd.include?("ruby -c")
          activity_log << "SYNTAX-CHECK"
        elsif cmd.include?("python3")
          python_edits += 1
          activity_log << "PYTHON-EDIT"
        elsif cmd.include?("hexdump") || cmd.include?("cat -A")
          activity_log << "DEBUG-ENCODING"
        else
          activity_log << "BASH: #{cmd.first(60)}"
        end
      elsif tool == "power---file_read"
        read_count += 1
      elsif tool == "power---file_write"
        write_count += 1
        mode = args["mode"] || "create"
        activity_log << "WRITE(#{mode})"
      elsif tool == "power---file_edit"
        edit_count += 1
        activity_log << "EDIT"
      elsif tool.include?("grep") || tool.include?("glob")
        grep_glob += 1
      elsif tool.include?("skill")
        skill_count += 1
        activity_log << "SKILL: #{args['skill']}"
      end
    elsif e.event_type == "tool.result"
      result = (e.payload&.dig("result") || "").to_s
      if result.include?("Search term not found")
        edit_fail += 1
        activity_log << "  >> EDIT FAILED"
      end
      if result.match?(/\d+ examples?.*\d+ failures?/)
        match = result.match(/(\d+) examples?, (\d+) failures?/)
        if match
          activity_log << "  >> #{match[0]}"
          activity_log << "  >> GREEN!" if match[2] == "0"
        end
      end
    end
  end

  puts "Tools: #{bash_count} bash (#{bash_test_runs} test runs), #{read_count} read, #{write_count} write, #{edit_count} edit, #{grep_glob} grep/glob"
  puts "Failed edits: #{edit_fail} | Python edits: #{python_edits} | Skills: #{skill_count}"
  puts ""
  puts "Activity: #{activity_log.join(' → ')}"
  puts ""
end
