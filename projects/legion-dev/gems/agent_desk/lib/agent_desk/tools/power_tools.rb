# frozen_string_literal: true

require_relative "power_tools/path_resolver"
require_relative "../constants"
require "fileutils"
require "open3"
require "timeout"
require "faraday"

module AgentDesk
  module Tools
    module PowerTools
      # Factory that creates a ToolSet containing the 7 power tools.
      #
      # @param project_dir [String] absolute path to the project directory
      # @param profile [AgentDesk::Agent::Profile, nil] optional profile for tool settings
      # @return [ToolSet] tool set with 7 power tools
      def self.create(project_dir:, profile: nil)
        Tools.build_group(AgentDesk::POWER_TOOL_GROUP_NAME) do
          tool name: AgentDesk::POWER_TOOL_FILE_READ,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::POWER_TOOL_FILE_READ],
               input_schema: {
                 properties: {
                   file_path: { type: "string" },
                   with_lines: { type: "boolean", default: false },
                   line_offset: { type: "integer", default: 0, minimum: 0 },
                   line_limit: { type: "integer", default: 1000, minimum: 1 }
                 },
                 required: [ "file_path" ]
               } do |args, context:|
            effective_dir = context[:project_dir] || project_dir
            begin
              resolved = PathResolver.resolve(args["file_path"], project_dir: effective_dir)
              offset = args.fetch("line_offset", 0).to_i
              limit = args.fetch("line_limit", 1000).to_i
              with_lines = args.fetch("with_lines", false)

              lines = []
              File.foreach(resolved).each_with_index do |line, idx|
                next if idx < offset
                break if lines.size >= limit
                line = line.chomp
                lines << (with_lines ? "#{idx + 1}|#{line}" : line)
              end
              lines.join("\n")
            rescue StandardError => e
              e.message
            end
          end

          tool name: AgentDesk::POWER_TOOL_FILE_WRITE,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::POWER_TOOL_FILE_WRITE],
               input_schema: {
                 properties: {
                   file_path: { type: "string" },
                   content: { type: "string" },
                   mode: { type: "string", enum: [ "create_only", "overwrite", "append" ], default: "create_only" }
                 },
                 required: [ "file_path", "content" ]
               } do |args, context:|
            effective_dir = context[:project_dir] || project_dir
            begin
              resolved = PathResolver.resolve(args["file_path"], project_dir: effective_dir)
              mode = args.fetch("mode", "create_only")
              content = args["content"]

              if mode == "create_only" && File.exist?(resolved)
                raise "File already exists: #{args['file_path']}"
              end

              FileUtils.mkdir_p(File.dirname(resolved))
              case mode
              when "create_only", "overwrite"
                File.write(resolved, content)
              when "append"
                File.open(resolved, "a") { |f| f.write(content) }
              else
                raise "Invalid mode: #{mode}"
              end
              "File written successfully (#{mode})"
            rescue StandardError => e
              e.message
            end
          end

          tool name: AgentDesk::POWER_TOOL_FILE_EDIT,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::POWER_TOOL_FILE_EDIT],
               input_schema: {
                 properties: {
                   file_path: { type: "string" },
                   search_term: { type: "string" },
                   replacement_text: { type: "string" },
                   is_regex: { type: "boolean", default: false },
                   replace_all: { type: "boolean", default: false }
                 },
                 required: [ "file_path", "search_term", "replacement_text" ]
               } do |args, context:|
            effective_dir = context[:project_dir] || project_dir
            begin
              resolved = PathResolver.resolve(args["file_path"], project_dir: effective_dir)
              search = args["search_term"]
              replace = args["replacement_text"]
              is_regex = args.fetch("is_regex", false)
              replace_all = args.fetch("replace_all", false)

              content = File.read(resolved)
              pattern = if is_regex
                          Regexp.new(search)
              else
                          Regexp.escape(search)
              end

              new_content = if replace_all
                              content.gsub(pattern, replace)
              else
                              content.sub(pattern, replace)
              end

              if content == new_content
                raise "Search term not found: #{search}"
              end

              File.write(resolved, new_content)
              # Simple diff summary
              "Replaced '#{search}' with '#{replace}' (#{replace_all ? 'all occurrences' : 'first occurrence'})"
            rescue RegexpError => e
              "Invalid regular expression: #{e.message}"
            rescue StandardError => e
              e.message
            end
          end

          tool name: AgentDesk::POWER_TOOL_GLOB,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::POWER_TOOL_GLOB],
               input_schema: {
                 properties: {
                   pattern: { type: "string" },
                   cwd: { type: "string", default: "" },
                   ignore: { type: "array", items: { type: "string" }, default: [] }
                 },
                 required: [ "pattern" ]
               } do |args, context:|
            effective_dir = context[:project_dir] || project_dir
            begin
              pattern = args["pattern"]
              cwd = args.fetch("cwd", "")
              ignore_patterns = args.fetch("ignore", [])

              base_dir = if cwd.empty?
                           effective_dir
              else
                           PathResolver.resolve(cwd, project_dir: effective_dir)
              end

              matches = Dir.glob(pattern, base: base_dir)
              # Filter ignored patterns
              matches.reject! do |path|
                ignore_patterns.any? { |ignore| File.fnmatch(ignore, path, File::FNM_PATHNAME | File::FNM_DOTMATCH) }
              end
              matches.join("\n")
            rescue StandardError => e
              e.message
            end
          end

          tool name: AgentDesk::POWER_TOOL_GREP,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::POWER_TOOL_GREP],
               input_schema: {
                 properties: {
                   file_pattern: { type: "string" },
                   search_term: { type: "string" },
                   context_lines: { type: "integer", default: 0, minimum: 0 },
                   case_sensitive: { type: "boolean", default: false },
                   max_results: { type: "integer", default: 50, minimum: 1 }
                 },
                 required: [ "file_pattern", "search_term" ]
               } do |args, context:|
            effective_dir = context[:project_dir] || project_dir
            begin
              file_pattern = args["file_pattern"]
              search = args["search_term"]
              context_lines = args.fetch("context_lines", 0).to_i
              case_sensitive = args.fetch("case_sensitive", false)
              max_results = args.fetch("max_results", 50).to_i

              regex_opts = case_sensitive ? 0 : Regexp::IGNORECASE
              regex = Regexp.new(search, regex_opts)

              files = Dir.glob(file_pattern, base: effective_dir)
              matches = []
              files.each do |file|
                abs_file = File.join(effective_dir, file)
                next unless File.file?(abs_file)
                lines = File.readlines(abs_file, chomp: true)
                lines.each_with_index do |line, idx|
                  if regex.match?(line)
                    # collect context lines
                    start_idx = [ idx - context_lines, 0 ].max
                    end_idx = [ idx + context_lines, lines.length - 1 ].min
                    context = (start_idx..end_idx).map do |ctx_idx|
                      prefix = ctx_idx == idx ? "> " : "  "
                      "#{prefix}#{ctx_idx + 1}: #{lines[ctx_idx]}"
                    end
                    matches << "File: #{file}\n#{context.join("\n")}"
                    break if matches.length >= max_results
                  end
                end
                break if matches.length >= max_results
              end
              matches.empty? ? "No matches found" : matches.join("\n\n")
            rescue RegexpError => e
              "Invalid regular expression: #{e.message}"
            rescue StandardError => e
              e.message
            end
          end

          tool name: AgentDesk::POWER_TOOL_BASH,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::POWER_TOOL_BASH],
               input_schema: {
                 properties: {
                   command: { type: "string" },
                   cwd: { type: "string", default: "" },
                   timeout: { type: "integer", default: 120000, minimum: 0 }
                 },
                 required: [ "command" ]
               } do |args, context:|
            effective_dir = context[:project_dir] || project_dir
            begin
              require "open3"
              require "timeout"
              command = args["command"]
              cwd = args.fetch("cwd", "")
              timeout_ms = args.fetch("timeout", 120000).to_i

              working_dir = if cwd.empty?
                              effective_dir
              else
                              PathResolver.resolve(cwd, project_dir: effective_dir)
              end

              stdout, stderr, status = Timeout.timeout(timeout_ms / 1000.0) do
                if defined?(Bundler)
                  Bundler.with_unbundled_env do
                    Open3.capture3(command, chdir: working_dir)
                  end
                else
                  Open3.capture3(command, chdir: working_dir)
                end
              end
              result = []
              result << "STDOUT:" unless stdout.empty?
              result << stdout unless stdout.empty?
              result << "STDERR:" unless stderr.empty?
              result << stderr unless stderr.empty?
              result << "Exit code: #{status.exitstatus}"
              result.join("\n")
            rescue Timeout::Error
              "Command timed out after #{timeout_ms} ms"
            rescue StandardError => e
              e.message
            end
          end

          tool name: AgentDesk::POWER_TOOL_FETCH,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::POWER_TOOL_FETCH],
               input_schema: {
                 properties: {
                   url: { type: "string" },
                   timeout: { type: "integer", default: 60000, minimum: 0 },
                   format: { type: "string", enum: [ "markdown", "html", "raw" ], default: "markdown" }
                 },
                 required: [ "url" ]
               } do |args, context:|
            begin
              url = args["url"]
              timeout_ms = args.fetch("timeout", 60000).to_i
              format = args.fetch("format", "markdown")

              conn = context[:faraday_connection] || Faraday.new do |f|
                f.request :url_encoded
                f.adapter Faraday.default_adapter
                f.options.timeout = timeout_ms / 1000.0
                f.options.open_timeout = timeout_ms / 1000.0
              end
              response = conn.get(url)

              body = response.body
              if format == "markdown"
                # Simple HTML to text conversion: strip tags, decode entities (basic)
                body = body.gsub(/<script[^>]*>.*?<\/script>/im, "")
                          .gsub(/<style[^>]*>.*?<\/style>/im, "")
                          .gsub(/<[^>]+>/, " ")
                          .gsub(/\s+/, " ")
                          .strip
              elsif format == "html"
                # keep raw HTML
              else # raw
                # keep raw body (bytes)
              end
              "Status: #{response.status}\n#{body}"
            rescue Faraday::Error => e
              "HTTP error: #{e.message}"
            rescue StandardError => e
              e.message
            end
          end
        end
      end
    end
  end
end
