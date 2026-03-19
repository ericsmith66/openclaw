# PRD-0050: Power Tools

**PRD ID**: PRD-0050
**Status**: Draft
**Priority**: High
**Created**: 2026-02-26
**Milestone**: M3 (Power Tools)
**Depends On**: PRD-0020

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/agent/tools/power.ts` — All power tools: file_read, file_write, file_edit, glob, grep, semantic_search, bash, fetch
- `src/common/tools.ts` — `POWER_TOOL_DESCRIPTIONS`

**Output Files** (Ruby):
- `lib/agent_desk/tools/power_tools.rb`
- `spec/agent_desk/tools/power_tools_spec.rb`

---

## 1. Problem Statement

The agent needs tools to interact with the filesystem and execute commands. These are the most commonly used tools — they make the agent immediately useful for code analysis and modification tasks.

Power tools in AiderDesk:
1. **file_read** — Read file contents (with optional line offset/limit)
2. **file_write** — Create, overwrite, or append to files
3. **file_edit** — Find-and-replace within a file (string or regex)
4. **glob** — Find files matching a pattern
5. **grep** — Search file contents with regex
6. **bash** — Execute shell commands (with safety patterns)
7. **fetch** — HTTP GET a URL (markdown, html, or raw format)
8. **semantic_search** — Code search (deferred; requires external index)

---

## 2. Design

### 2.1 Power Tool Factory

Uses the DSL from PRD-0020 to create all power tools:

```ruby
# lib/agent_desk/tools/power_tools.rb
module AgentDesk
  module Tools
    module PowerTools
      def self.create(project_dir:, profile: nil)
        Tools.build_group(POWER_TOOL_GROUP_NAME) do
          # --- file_read ---
          tool POWER_TOOL_FILE_READ,
               description: TOOL_DESCRIPTIONS[POWER_TOOL_FILE_READ],
               input_schema: {
                 properties: {
                   file_path: { type: 'string', description: 'Path to file (relative to project dir or absolute)' },
                   with_lines: { type: 'boolean', default: false },
                   line_offset: { type: 'integer', default: 0, minimum: 0 },
                   line_limit: { type: 'integer', default: 1000, minimum: 1 }
                 },
                 required: ['file_path']
               } do |args, _ctx|
            path = resolve_path(args['file_path'], project_dir)
            content = File.read(path)
            lines = content.lines

            offset = args.fetch('line_offset', 0)
            limit = args.fetch('line_limit', 1000)
            sliced = lines[offset, limit] || []

            if args.fetch('with_lines', false)
              sliced.each_with_index.map { |line, i| "#{offset + i + 1}|#{line}" }.join
            else
              sliced.join
            end
          end

          # --- file_write ---
          tool POWER_TOOL_FILE_WRITE,
               description: TOOL_DESCRIPTIONS[POWER_TOOL_FILE_WRITE],
               input_schema: {
                 properties: {
                   file_path: { type: 'string' },
                   content: { type: 'string' },
                   mode: { type: 'string', enum: %w[create_only overwrite append], default: 'create_only' }
                 },
                 required: %w[file_path content]
               } do |args, _ctx|
            path = resolve_path(args['file_path'], project_dir)
            mode = args.fetch('mode', 'create_only')

            case mode
            when 'create_only'
              raise "File already exists: #{path}" if File.exist?(path)
              FileUtils.mkdir_p(File.dirname(path))
              File.write(path, args['content'])
            when 'overwrite'
              FileUtils.mkdir_p(File.dirname(path))
              File.write(path, args['content'])
            when 'append'
              FileUtils.mkdir_p(File.dirname(path))
              File.open(path, 'a') { |f| f.write(args['content']) }
            end
            "Successfully wrote to #{path}"
          end

          # --- file_edit ---
          tool POWER_TOOL_FILE_EDIT,
               description: TOOL_DESCRIPTIONS[POWER_TOOL_FILE_EDIT],
               input_schema: {
                 properties: {
                   file_path: { type: 'string' },
                   search_term: { type: 'string' },
                   replacement_text: { type: 'string' },
                   is_regex: { type: 'boolean', default: false },
                   replace_all: { type: 'boolean', default: false }
                 },
                 required: %w[file_path search_term replacement_text]
               } do |args, _ctx|
            path = resolve_path(args['file_path'], project_dir)
            content = File.read(path)

            pattern = args.fetch('is_regex', false) ? Regexp.new(args['search_term']) : args['search_term']

            new_content = if args.fetch('replace_all', false)
                            content.gsub(pattern, args['replacement_text'])
                          else
                            content.sub(pattern, args['replacement_text'])
                          end

            raise "Search term not found in #{path}" if new_content == content

            File.write(path, new_content)
            "Successfully edited #{path}"
          end

          # --- glob ---
          tool POWER_TOOL_GLOB,
               description: TOOL_DESCRIPTIONS[POWER_TOOL_GLOB],
               input_schema: {
                 properties: {
                   pattern: { type: 'string' },
                   cwd: { type: 'string' },
                   ignore: { type: 'array', items: { type: 'string' } }
                 },
                 required: ['pattern']
               } do |args, _ctx|
            base = resolve_path(args.fetch('cwd', '.'), project_dir)
            matches = Dir.glob(File.join(base, args['pattern']))
            # TODO: apply ignore patterns
            matches.map { |m| m.delete_prefix("#{project_dir}/") }
          end

          # --- grep ---
          tool POWER_TOOL_GREP,
               description: TOOL_DESCRIPTIONS[POWER_TOOL_GREP],
               input_schema: {
                 properties: {
                   file_pattern: { type: 'string' },
                   search_term: { type: 'string' },
                   case_sensitive: { type: 'boolean', default: false },
                   context_lines: { type: 'integer', default: 0 },
                   max_results: { type: 'integer', default: 50 }
                 },
                 required: %w[file_pattern search_term]
               } do |args, _ctx|
            files = Dir.glob(File.join(project_dir, args['file_pattern']))
            regex_opts = args.fetch('case_sensitive', false) ? 0 : Regexp::IGNORECASE
            regex = Regexp.new(args['search_term'], regex_opts)
            results = []

            files.each do |file|
              next unless File.file?(file)
              lines = File.readlines(file) rescue next
              lines.each_with_index do |line, i|
                if line.match?(regex)
                  results << {
                    file: file.delete_prefix("#{project_dir}/"),
                    line_number: i + 1,
                    content: line.chomp
                  }
                  break if results.size >= args.fetch('max_results', 50)
                end
              end
              break if results.size >= args.fetch('max_results', 50)
            end
            results
          end

          # --- bash ---
          tool POWER_TOOL_BASH,
               description: TOOL_DESCRIPTIONS[POWER_TOOL_BASH],
               input_schema: {
                 properties: {
                   command: { type: 'string' },
                   cwd: { type: 'string' },
                   timeout: { type: 'integer', default: 120 }
                 },
                 required: ['command']
               } do |args, _ctx|
            cwd = resolve_path(args.fetch('cwd', '.'), project_dir)
            # Safety: validate against allowed/denied patterns from profile tool_settings
            # (delegated to caller or approval manager)

            stdout, stderr, status = Open3.capture3(args['command'], chdir: cwd)
            {
              stdout: stdout,
              stderr: stderr,
              exit_code: status.exitstatus
            }
          end

          # --- fetch ---
          tool POWER_TOOL_FETCH,
               description: TOOL_DESCRIPTIONS[POWER_TOOL_FETCH],
               input_schema: {
                 properties: {
                   url: { type: 'string' },
                   format: { type: 'string', enum: %w[markdown html raw], default: 'markdown' },
                   timeout: { type: 'integer', default: 60 }
                 },
                 required: ['url']
               } do |args, _ctx|
            require 'net/http'
            uri = URI(args['url'])
            response = Net::HTTP.get_response(uri)
            response.body
            # TODO: markdown conversion for format: 'markdown'
          end
        end
      end

      def self.resolve_path(path, project_dir)
        return path if File.absolute_path?(path) == path
        File.join(project_dir, path)
      end
    end
  end
end
```

---

## 3. Acceptance Criteria

- ✅ `PowerTools.create(project_dir: '/tmp/test')` returns a `ToolSet` with 7 tools (semantic_search deferred)
- ✅ `file_read` reads a file, supports line offset/limit and line numbers
- ✅ `file_write` creates (fails if exists), overwrites, or appends
- ✅ `file_edit` does string and regex find-and-replace
- ✅ `glob` returns files matching a pattern relative to project dir
- ✅ `grep` searches file contents with regex and returns matches
- ✅ `bash` executes commands and returns stdout/stderr/exit_code
- ✅ `fetch` performs HTTP GET
- ✅ All tools have proper `input_schema` and `description`

---

## 4. Test Plan

```ruby
RSpec.describe AgentDesk::Tools::PowerTools do
  let(:project_dir) { Dir.mktmpdir }
  let(:tool_set) { described_class.create(project_dir: project_dir) }

  after { FileUtils.remove_entry(project_dir) }

  describe 'file_read' do
    it 'reads a file' do
      File.write(File.join(project_dir, 'test.txt'), "line1\nline2\nline3")
      tool = tool_set[AgentDesk.tool_id('power', 'file_read')]
      result = tool.execute({ 'file_path' => 'test.txt' })
      expect(result).to include('line1')
    end
  end

  describe 'file_write' do
    it 'creates a new file' do
      tool = tool_set[AgentDesk.tool_id('power', 'file_write')]
      tool.execute({ 'file_path' => 'new.txt', 'content' => 'hello', 'mode' => 'create_only' })
      expect(File.read(File.join(project_dir, 'new.txt'))).to eq('hello')
    end
  end

  describe 'bash' do
    it 'executes a command' do
      tool = tool_set[AgentDesk.tool_id('power', 'bash')]
      result = tool.execute({ 'command' => 'echo hello' })
      expect(result[:stdout].strip).to eq('hello')
      expect(result[:exit_code]).to eq(0)
    end
  end
end
```

---

## 5. AiderDesk Mapping

| Ruby | AiderDesk |
|------|-----------|
| `PowerTools.create` | `createPowerToolset()` in `power.ts` |
| `resolve_path` | `path.resolve(task.getTaskDir(), ...)` in power.ts |
| bash safety patterns | `profile.toolSettings[bash].allowedPattern/deniedPattern` |
| `Open3.capture3` | `child_process.spawn` in bash tool |

---

**Next**: PRD-0060 (Prompt Templating) builds the system prompt that tells the LLM about these tools.
