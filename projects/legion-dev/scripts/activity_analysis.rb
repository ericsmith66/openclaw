# Usage: rails runner scripts/activity_analysis.rb
# Deep activity analysis of QA test-writing runs

[ 55, 56 ].each do |rid|
  run = WorkflowRun.find(rid)
  puts "=" * 80
  puts "WR##{rid} - #{run.prompt&.first(80)}"
  dur = run.duration_ms ? (run.duration_ms / 60000.0).round(1) : 0
  turns = run.workflow_events.where(event_type: "response.complete").count
  puts "Duration: #{dur}min | Turns: #{turns}"
  puts "=" * 80

  events = run.workflow_events.where(event_type: %w[tool.called tool.result]).order(:recorded_at)

  bash_count = 0
  bash_test_runs = 0
  read_count = 0
  write_count = 0
  edit_count = 0
  edit_fail = 0
  skill_count = 0
  activity_log = []

  prev_tool = nil
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
          activity_log << "SYNTAX-CHECK: #{cmd.split('ruby -c').last.to_s.strip.first(60)}"
        elsif cmd.include?("python3")
          activity_log << "PYTHON-EDIT: (using python to edit file)"
        else
          activity_log << "BASH: #{cmd.first(80)}"
        end
        prev_tool = tool
      elsif tool == "power---file_read"
        read_count += 1
        activity_log << "READ: #{File.basename(args['filePath'].to_s)}"
        prev_tool = tool
      elsif tool == "power---file_write"
        write_count += 1
        activity_log << "WRITE: #{File.basename(args['filePath'].to_s)} (#{args['mode'] || 'create'})"
        prev_tool = tool
      elsif tool == "power---file_edit"
        edit_count += 1
        activity_log << "EDIT: #{File.basename(args['filePath'].to_s)}"
        prev_tool = tool
      elsif tool.include?("skill")
        skill_count += 1
        activity_log << "SKILL: #{args['skill']}"
        prev_tool = tool
      else
        activity_log << "OTHER: #{tool}"
        prev_tool = tool
      end
    elsif e.event_type == "tool.result"
      result = (e.payload&.dig("result") || "").to_s
      if result.include?("Search term not found")
        edit_fail += 1
        activity_log << "  >> EDIT FAILED (search not found)"
      end
      if result.match?(/\d+ examples?.*\d+ failures?/)
        match = result.match(/(\d+) examples?, (\d+) failures?/)
        if match
          activity_log << "  >> #{match[0]}"
          activity_log << "  >> GREEN!" if match[2] == "0"
        end
      end
      if result.include?("Syntax OK")
        activity_log << "  >> Syntax OK"
      end
      if result.include?("Error") && !result.include?("Faraday::Error") && !result.include?("StandardError")
        snippet = result.lines.select { |l| l.include?("Error") }.first(2).map(&:strip)
        activity_log << "  >> ERROR: #{snippet.join(' | ').first(100)}" unless snippet.empty?
      end
    end
  end

  puts "Tools: #{bash_count} bash (#{bash_test_runs} test runs), #{read_count} read, #{write_count} write, #{edit_count} edit"
  puts "Failed edits: #{edit_fail} | Skills activated: #{skill_count}"
  puts ""
  puts "Activity timeline:"
  activity_log.each { |a| puts "  #{a}" }
  puts ""
end
