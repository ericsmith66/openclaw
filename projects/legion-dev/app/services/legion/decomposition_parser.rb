# frozen_string_literal: true

module Legion
  class DecompositionParser
    Result = Struct.new(:tasks, :warnings, :errors, keyword_init: true)

    REQUIRED_FIELDS = %w[position type prompt agent files_score concepts_score dependencies_score depends_on].freeze
    VALID_TASK_TYPES = %w[test code review debug].freeze

    def self.call(response_text:)
      new(response_text: response_text).call
    end

    def initialize(response_text:)
      @response_text = response_text
      @tasks = []
      @warnings = []
      @errors = []
    end

    def call
      json_text = extract_json(@response_text)
      return Result.new(tasks: [], warnings: [], errors: [ "No valid JSON found in response" ]) if json_text.nil?

      parsed_data = parse_json(json_text)
      return Result.new(tasks: [], warnings: [], errors: [ "Invalid JSON format" ]) if parsed_data.nil?

      validate_and_build_tasks(parsed_data)

      Result.new(
        tasks: @tasks,
        warnings: @warnings,
        errors: @errors
      )
    end

    private

    def extract_json(text)
      # Strategy 1: Find ```json ... ``` code fence (greedy — handles nested fences)
      json_match = text.match(/```json\s*\n(.+)\n```/m)
      if json_match
        content = json_match[1].strip
        # If content contains nested ``` fences, find the JSON array within it
        if content.include?("```")
          array_in_fence = content.match(/(\[\s*\{.*\}\s*\])/m)
          return array_in_fence[1].strip if array_in_fence
        end
        return content
      end

      # Strategy 2: Find JSON array directly in text (greedy match)
      array_match = text.match(/(\[\s*\{.*\}\s*\])/m)
      return array_match[1].strip if array_match

      # Strategy 3: Check if the entire text is valid JSON
      stripped = text.strip
      return stripped if stripped.start_with?("[") && stripped.end_with?("]")

      nil
    end

    def parse_json(json_text)
      # Remove trailing commas (lenient parsing)
      cleaned = json_text.gsub(/,(\s*[}\]])/, '\1')

      JSON.parse(cleaned, symbolize_names: true)
    rescue JSON::ParserError => e
      @errors << "JSON parse error: #{e.message}"
      nil
    end

    def validate_and_build_tasks(parsed_data)
      return unless parsed_data.is_a?(Array)

      if parsed_data.empty?
        @warnings << "Empty task list returned"
        return
      end

      # Build position map for dependency validation
      position_map = parsed_data.each_with_object({}) { |task, map| map[task[:position]] = task }

      parsed_data.each do |task_data|
        validate_task(task_data, position_map)
      end

      # Detect cycles if no errors
      detect_cycles(parsed_data) if @errors.empty?

      # Identify warnings for high-score tasks
      identify_warnings if @errors.empty?
    end

    def validate_task(task_data, position_map)
      # Check required fields
      missing_fields = REQUIRED_FIELDS - task_data.keys.map(&:to_s)
      if missing_fields.any?
        @errors << "Task at position #{task_data[:position]}: missing required fields: #{missing_fields.join(', ')}"
        return
      end

      # Validate task type
      unless VALID_TASK_TYPES.include?(task_data[:type])
        @errors << "Task #{task_data[:position]}: invalid type '#{task_data[:type]}'. Must be one of: #{VALID_TASK_TYPES.join(', ')}"
        return
      end

      # Validate score ranges
      %i[files_score concepts_score dependencies_score].each do |score_field|
        score = task_data[score_field]
        unless score.is_a?(Integer) && score >= 1 && score <= 4
          @errors << "Task #{task_data[:position]}: #{score_field} must be 1-4, got #{score.inspect}"
          return
        end
      end

      # Validate dependency references
      task_data[:depends_on].each do |dep_position|
        unless position_map.key?(dep_position)
          @errors << "Task #{task_data[:position]}: depends on non-existent task #{dep_position}"
          return
        end
      end

      # Compute total score
      total_score = task_data[:files_score] + task_data[:concepts_score] + task_data[:dependencies_score]

      # Build task object
      @tasks << {
        position: task_data[:position],
        type: task_data[:type],
        prompt: task_data[:prompt],
        agent: task_data[:agent],
        files_score: task_data[:files_score],
        concepts_score: task_data[:concepts_score],
        dependencies_score: task_data[:dependencies_score],
        total_score: total_score,
        depends_on: task_data[:depends_on] || [],
        notes: task_data[:notes]
      }
    end

    def detect_cycles(parsed_data)
      # Kahn's algorithm for cycle detection
      # Build adjacency list and in-degree count
      adjacency = Hash.new { |h, k| h[k] = [] }
      in_degree = Hash.new(0)
      positions = parsed_data.map { |t| t[:position] }

      positions.each { |pos| in_degree[pos] = 0 }

      parsed_data.each do |task|
        task[:depends_on].each do |dep|
          adjacency[dep] << task[:position]
          in_degree[task[:position]] += 1
        end
      end

      # Topological sort
      queue = positions.select { |pos| in_degree[pos] == 0 }
      processed = []

      while queue.any?
        current = queue.shift
        processed << current

        adjacency[current].each do |neighbor|
          in_degree[neighbor] -= 1
          queue << neighbor if in_degree[neighbor] == 0
        end
      end

      # If not all tasks processed, there's a cycle
      if processed.size < positions.size
        unprocessed = positions - processed
        # Find the actual cycle path using DFS
        cycle_path = find_cycle_path(unprocessed, adjacency, parsed_data)
        @errors << "Dependency cycle detected: #{cycle_path.join(' → ')}"
      end
    end

    def find_cycle_path(unprocessed_positions, adjacency, parsed_data)
      # DFS to find actual cycle
      visited = Set.new
      path = []

      # Build reverse adjacency (task -> its dependencies) for DFS
      dependencies = {}
      parsed_data.each do |task|
        dependencies[task[:position]] = task[:depends_on]
      end

      # Start from first unprocessed task
      start = unprocessed_positions.first
      current = start

      loop do
        path << current
        visited.add(current)

        # Follow first dependency
        next_task = dependencies[current]&.first
        break if next_task.nil?

        if path.include?(next_task)
          # Found the cycle
          cycle_start_index = path.index(next_task)
          return path[cycle_start_index..] + [ next_task ]
        end

        current = next_task
      end

      # Fallback: just report the unprocessed positions
      unprocessed_positions
    end

    def identify_warnings
      @tasks.each do |task|
        if task[:total_score] > 6
          @warnings << "Task #{task[:position]}: total_score #{task[:total_score]} > threshold 6 — consider further decomposition"
        end
      end
    end
  end
end
