#!/usr/bin/env ruby
# frozen_string_literal: true

# Dumps RubyMine's MCP (Model Context Protocol) server capabilities/tools/resources/prompts
# into a markdown file for RAG ingestion.
#
# Usage:
#   ruby script/dump_rubymine_mcp.rb
#
# Environment variables:
#   MCP_URL   Base URL for the MCP server (default: http://localhost:5113)
#             Examples to try (JetBrains builds vary):
#               MCP_URL=http://localhost:5113
#               MCP_URL=http://localhost:5113/mcp
#   MCP_TOKEN Optional bearer token (if your MCP server requires it)
#   MCP_OUT   Output markdown path
#             (default: knowledge_base/epics/backlog/agentic-planning/rag-structure/MCP.md)
#
# Notes:
# - This script supports two MCP transports:
#   1) JSON-RPC over HTTP POST (common for MCP HTTP servers)
#   2) MCP over SSE (RubyMine often exposes an `/sse` endpoint)
# - For SSE, the server will stream events and provide a `/message?sessionId=...`
#   endpoint that the client must POST JSON-RPC requests to.

require "fileutils"
require "json"
require "net/http"
require "time"
require "timeout"
require "uri"

class McpConnectionError < StandardError
  attr_reader :mcp_url, :attempts

  def initialize(message, mcp_url:, attempts:)
    super(message)
    @mcp_url = mcp_url
    @attempts = attempts
  end
end

class McpTimeoutError < StandardError
end

DEFAULT_OUT = File.expand_path(
  "knowledge_base/epics/backlog/agentic-planning/rag-structure/MCP.md",
  __dir__ + "/.."
)

def deep_sort(obj)
  case obj
  when Hash
    obj.keys.sort_by(&:to_s).each_with_object({}) do |k, acc|
      acc[k] = deep_sort(obj[k])
    end
  when Array
    # Try to make ordering stable for common MCP structures.
    if obj.all? { |e| e.is_a?(Hash) && (e.key?("name") || e.key?(:name)) }
      obj.sort_by { |e| (e["name"] || e[:name]).to_s }.map { |e| deep_sort(e) }
    else
      obj.map { |e| deep_sort(e) }
    end
  else
    obj
  end
end

def pretty_json(obj)
  JSON.pretty_generate(deep_sort(obj))
end

class JsonRpcHttpClient
  def initialize(base_url:, token: "", open_timeout: 2, read_timeout: 15)
    @uri = URI.parse(base_url)
    @token = token
    @open_timeout = open_timeout
    @read_timeout = read_timeout
    @id = 0
  end

  attr_reader :uri

  def call(method, params = nil)
    @id += 1
    payload = {
      jsonrpc: "2.0",
      id: @id,
      method: method
    }
    payload[:params] = params if params

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    req["Authorization"] = "Bearer #{@token}" unless @token.empty?
    req.body = JSON.dump(payload)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout

    res = http.request(req)
    unless res.is_a?(Net::HTTPSuccess)
      raise "HTTP #{res.code} from #{uri} for method=#{method}: #{res.body.to_s[0, 500]}"
    end

    body = JSON.parse(res.body)
    if body["error"]
      raise "JSON-RPC error for method=#{method}: #{body["error"].inspect}"
    end

    body
  end

  def notify(method, params = nil)
    payload = {
      jsonrpc: "2.0",
      method: method
    }
    payload[:params] = params if params

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    req["Authorization"] = "Bearer #{@token}" unless @token.empty?
    req.body = JSON.dump(payload)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout

    http.request(req)
    true
  end
end

class McpSseClient
  def initialize(sse_url:, token: "", open_timeout: 2, read_timeout: 300)
    @sse_uri = URI.parse(sse_url)
    @token = token.to_s
    @open_timeout = open_timeout
    @read_timeout = read_timeout
    @id = 0

    @message_uri = nil

    @lock = Mutex.new
    @cv = ConditionVariable.new
    @pending = {} # id => Queue

    @notifications = Queue.new

    @event_lock = Mutex.new
    @events = []
    @max_events = Integer(ENV.fetch("MCP_MAX_EVENTS", "5000"))

    @sse_thread = nil
  end

  attr_reader :sse_uri

  def start!
    return if @sse_thread

    @sse_thread = Thread.new { run_sse_loop }
    @sse_thread.report_on_exception = false if @sse_thread.respond_to?(:report_on_exception=)

    # Wait until we receive the server-provided message endpoint.
    Timeout.timeout(5) do
      @lock.synchronize do
        @cv.wait(@lock) until @message_uri
      end
    end

    self
  rescue Timeout::Error
    raise McpConnectionError.new(
      "Connected to SSE but did not receive message endpoint event.",
      mcp_url: sse_uri.to_s,
      attempts: { sse_uri.to_s => "no endpoint event" }
    )
  end

  def stop!
    return unless @sse_thread
    @sse_thread.kill
    @sse_thread.join(0.2)
  ensure
    @sse_thread = nil
  end

  def call(method, params = nil, timeout_seconds: 15)
    start!

    @id += 1
    id = @id

    payload = { jsonrpc: "2.0", id: id, method: method }
    payload[:params] = params if params

    q = Queue.new
    @lock.synchronize { @pending[id] = q }

    post_json(@message_uri, payload)

    begin
      Timeout.timeout(timeout_seconds) { q.pop }
    rescue Timeout::Error
      raise McpTimeoutError, "Timed out waiting for MCP response id=#{id} method=#{method}"
    ensure
      @lock.synchronize { @pending.delete(id) }
    end
  end

  def notify(method, params = nil)
    start!

    payload = { jsonrpc: "2.0", method: method }
    payload[:params] = params if params

    post_json(@message_uri, payload)
    true
  end

  def wait_for_notification(method, timeout_seconds: 5)
    start!

    Timeout.timeout(timeout_seconds) do
      loop do
        msg = @notifications.pop
        return msg if msg.is_a?(Hash) && msg["method"] == method
      end
    end
  rescue Timeout::Error
    nil
  end

  def events
    @event_lock.synchronize { @events.dup }
  end

  private

  def run_sse_loop
    loop do
      req = Net::HTTP::Get.new(@sse_uri)
      req["Accept"] = "text/event-stream"
      req["Cache-Control"] = "no-cache"
      req["Authorization"] = "Bearer #{@token}" unless @token.empty?

      http = Net::HTTP.new(@sse_uri.host, @sse_uri.port)
      http.use_ssl = @sse_uri.scheme == "https"
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout

      http.request(req) do |res|
        unless res.is_a?(Net::HTTPSuccess)
          raise McpConnectionError.new(
            "HTTP #{res.code} from #{@sse_uri} (SSE)",
            mcp_url: @sse_uri.to_s,
            attempts: { @sse_uri.to_s => res.body.to_s[0, 500] }
          )
        end

        event = nil
        data_lines = []

        # Net::HTTP yields arbitrary chunks; a single SSE line can be split
        # across chunks. Buffer until we have complete lines.
        buffer = +""

        res.read_body do |chunk|
          buffer << chunk.to_s

          while (newline_index = buffer.index("\n"))
            line = buffer.slice!(0..newline_index)
            line = line.chomp

            if line.empty?
              process_sse_event(event, data_lines)
              event = nil
              data_lines = []
              next
            end

            if line.start_with?("event:")
              event = line.sub("event:", "").strip
            elsif line.start_with?("data:")
              data_lines << line.sub("data:", "").lstrip
            end
          end
        end
      end
    rescue Net::ReadTimeout
      # SSE streams can go idle; reconnect.
      sleep 0.1
      next
    end
  rescue StandardError
    # Swallow errors inside the reader thread; caller will see timeouts/connection errors on requests.
    nil
  end

  def process_sse_event(event, data_lines)
    return if data_lines.empty? && event.nil?

    data = data_lines.join("\n")

    @event_lock.synchronize do
      @events << {
        "receivedAt" => Time.now.utc.iso8601,
        "event" => (event || "message"),
        "data" => data
      }
      if @events.length > @max_events
        @events.shift(@events.length - @max_events)
      end
    end

    case event
    when "endpoint"
      # RubyMine returns a relative endpoint like `/message?sessionId=...`
      endpoint_path = data.strip
      begin
        resolved = @sse_uri + endpoint_path
      rescue
        resolved = URI.parse(endpoint_path)
      end

      @lock.synchronize do
        @message_uri ||= resolved
        @cv.broadcast
      end
    else
      begin
        msg = JSON.parse(data)
      rescue
        return
      end

      if ENV["MCP_DEBUG_SSE"] == "1"
        if msg.is_a?(Hash) && (msg.key?("id") || msg.key?("method"))
          preview = msg.dup
          preview["result"] = "<omitted>" if preview.key?("result")
          preview["params"] = "<omitted>" if preview.key?("params")
          warn "[mcp-dump] SSE #{event || "message"}: #{preview.inspect}"
        end
      end

      # Notifications have no id; responses do.
      id = msg["id"]
      if id
        q = @lock.synchronize { @pending[id] }
        q&.push(msg)
      elsif msg["method"]
        @notifications.push(msg)
      end
    end
  end

  def handle_response_message(msg)
    id = msg["id"]
    return unless id

    q = @lock.synchronize { @pending[id] }
    q&.push(msg)
  end

  def post_json(uri, payload)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    req["Authorization"] = "Bearer #{@token}" unless @token.empty?
    req.body = JSON.dump(payload)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = @open_timeout
    http.read_timeout = @read_timeout

    res = http.request(req)
    if ENV["MCP_DEBUG_HTTP"] == "1"
      warn "[mcp-dump] POST #{uri} -> HTTP #{res.code} (#{payload[:method]})"
      body_preview = res.body.to_s.gsub("\n", "\\n")[0, 500]
      warn "[mcp-dump] body: #{body_preview}" unless body_preview.empty?
    end
    unless res.is_a?(Net::HTTPSuccess)
      raise "HTTP #{res.code} from #{uri} for JSON-RPC request: #{res.body.to_s[0, 500]}"
    end

    # Some MCP-over-SSE servers return JSON-RPC responses directly in the POST
    # response body (instead of emitting them on the SSE stream).
    body = res.body.to_s.strip
    if body.start_with?("{")
      begin
        parsed = JSON.parse(body)
        handle_response_message(parsed) if parsed.is_a?(Hash)
      rescue
        nil
      end
    end

    true
  end
end

def try_client_urls(base)
  base = base.sub(%r{/$}, "")
  candidates = []

  # If user already passed a path, try it first.
  candidates << base

  # Common endpoints seen in MCP HTTP servers.
  candidates << "#{base}/mcp"
  candidates << "#{base}/jsonrpc"
  candidates << "#{base}/rpc"

  candidates.uniq
end

def fetch_mcp_snapshot(mcp_url:, token: nil)
  errors = {}

  tools_timeout = Integer(ENV.fetch("MCP_TOOLS_TIMEOUT", "180"))
  capture_seconds = Float(ENV.fetch("MCP_CAPTURE_SECONDS", "2"))

  # If the provided URL looks like RubyMine's SSE transport, try that first.
  if mcp_url.to_s.include?("/sse")
    begin
      client = McpSseClient.new(sse_url: mcp_url, token: token)
      init = client.call(
        "initialize",
        {
          protocolVersion: "2024-11-05",
          clientInfo: { name: "nextgen-plaid:mcp-dump", version: "1.0" },
          capabilities: { tools: { listChanged: true } }
        },
        timeout_seconds: 20
      )

      # Some servers require a post-initialize notification before responding
      # to discovery calls (mirrors LSP-like handshake patterns).
      begin
        client.notify("notifications/initialized")
      rescue
        nil
      end

      # RubyMine emits `notifications/tools/list_changed` after initialization.
      # Waiting for it avoids races where `tools/list` is requested before the
      # tool registry is ready.
      begin
        client.wait_for_notification("notifications/tools/list_changed", timeout_seconds: 5)
      rescue
        nil
      end

      tools = safe_call(client, "tools/list", params: {}, timeout_seconds: tools_timeout)
      prompts = safe_call(client, "prompts/list", params: {})
      resources = safe_call(client, "resources/list", params: {})
      resource_templates = safe_call(client, "resources/templates/list", params: {})

      # Capture a small window of the raw SSE event stream (notifications and
      # responses) so the dump is as complete/diagnosable as possible.
      sleep capture_seconds if capture_seconds.positive?
      sse_events = client.events

      return {
        connected_url: mcp_url,
        initialize: init,
        tools_list: tools,
        prompts_list: prompts,
        resources_list: resources,
        resource_templates_list: resource_templates,
        sse_events: sse_events
      }
    rescue StandardError => e
      errors[mcp_url] = e.message
    ensure
      begin
        client&.stop!
      rescue
        nil
      end
    end
  end

  try_client_urls(mcp_url).each do |url|
    client = JsonRpcHttpClient.new(base_url: url, token: token)
    begin
      init = client.call(
        "initialize",
        {
          protocolVersion: "2024-11-05",
          clientInfo: { name: "nextgen-plaid:mcp-dump", version: "1.0" },
          capabilities: {}
        }
      )

      tools = safe_call(client, "tools/list", params: {})
      prompts = safe_call(client, "prompts/list", params: {})
      resources = safe_call(client, "resources/list", params: {})
      resource_templates = safe_call(client, "resources/templates/list", params: {})

      return {
        connected_url: url,
        initialize: init,
        tools_list: tools,
        prompts_list: prompts,
        resources_list: resources,
        resource_templates_list: resource_templates
      }
    rescue StandardError => e
      errors[url] = e.message
      next
    end
  end

  raise McpConnectionError.new(
    "Could not connect to MCP (tried SSE and JSON-RPC POST).",
    mcp_url: mcp_url,
    attempts: errors
  )
end

def safe_call(client, method, params: nil, timeout_seconds: nil)
  if timeout_seconds
    client.call(method, params, timeout_seconds: timeout_seconds)
  else
    client.call(method, params)
  end
rescue StandardError => e
  { "_error" => e.message, "_method" => method }
end

def to_markdown(snapshot)
  checked_at = Time.now.utc.iso8601

  sections = []
  sections << "# RubyMine MCP Dump"
  sections << ""
  sections << "- Generated at: `#{checked_at}`"
  sections << "- Connected URL: `#{snapshot[:connected_url]}`"
  sections << ""

  sections << "## initialize"
  sections << "```json"
  sections << pretty_json(snapshot[:initialize])
  sections << "```"
  sections << ""

  sections << "## tools/list"
  sections << "```json"
  sections << pretty_json(snapshot[:tools_list])
  sections << "```"
  sections << ""

  sections << "## prompts/list"
  sections << "```json"
  sections << pretty_json(snapshot[:prompts_list])
  sections << "```"
  sections << ""

  sections << "## resources/list"
  sections << "```json"
  sections << pretty_json(snapshot[:resources_list])
  sections << "```"
  sections << ""

  sections << "## resources/templates/list"
  sections << "```json"
  sections << pretty_json(snapshot[:resource_templates_list])
  sections << "```"
  sections << ""

  if snapshot[:sse_events]
    sections << "## sse/events (raw)"
    sections << "```json"
    sections << pretty_json(snapshot[:sse_events])
    sections << "```"
    sections << ""
  end

  sections.join("\n")
end

def failure_markdown(mcp_url:, out_path:, error:)
  checked_at = Time.now.utc.iso8601
  attempted = try_client_urls(mcp_url)

  attempts_block = if error.respond_to?(:attempts) && error.attempts.is_a?(Hash)
    error.attempts
  else
    {}
  end

  lines = []
  lines << "# RubyMine MCP Dump (FAILED)"
  lines << ""
  lines << "- Generated at: `#{checked_at}`"
  lines << "- Requested MCP_URL: `#{mcp_url}`"
  lines << "- Output: `#{out_path}`"
  lines << ""
  lines << "## Error"
  lines << ""
  lines << "```"
  lines << "#{error.class}: #{error.message}"
  lines << "```"
  lines << ""
  lines << "## Attempted endpoints"
  lines << ""
  attempted.each do |url|
    msg = attempts_block[url]
    if msg
      lines << "- `#{url}` — #{msg}"
    else
      lines << "- `#{url}`"
    end
  end
  lines << ""
  lines << "## Troubleshooting"
  lines << ""
  lines << "1) Enable/start RubyMine MCP Server: `Settings → Tools → MCP Server`"
  lines << "2) Confirm the MCP URL RubyMine shows (host + path). Then rerun:"
  lines << "   ```bash"
  lines << "   MCP_URL=<that_url> ruby script/dump_rubymine_mcp.rb"
  lines << "   ```"
  lines << "3) If RubyMine shows `SSE` transport, use the `/sse` URL (example: `http://127.0.0.1:64342/sse`)."
  lines << ""
  lines.join("\n")
end

out_path = ENV.fetch("MCP_OUT", DEFAULT_OUT)
mcp_url = ENV.fetch("MCP_URL", "http://localhost:5113")
token = ENV.fetch("MCP_TOKEN", "")

begin
  snapshot = fetch_mcp_snapshot(mcp_url: mcp_url, token: token)
  md = to_markdown(snapshot)

  FileUtils.mkdir_p(File.dirname(out_path))
  File.write(out_path, md)

  puts "Wrote MCP dump to: #{out_path}"
rescue StandardError => e
  # Always write *something* to MCP_OUT so the knowledge base file doesn't end up blank.
  FileUtils.mkdir_p(File.dirname(out_path))
  File.write(out_path, failure_markdown(mcp_url: mcp_url, out_path: out_path, error: e))

  warn "ERROR: #{e.class}: #{e.message}"
  warn "Wrote failure report to: #{out_path}"
  exit 1
end
