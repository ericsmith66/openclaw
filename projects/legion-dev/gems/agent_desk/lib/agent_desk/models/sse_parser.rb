# frozen_string_literal: true

require "json"

module AgentDesk
  module Models
    # Parses Server-Sent Events (SSE) from an OpenAI-compatible streaming response.
    #
    # Handles the standard SSE format: +data: {...}\n\n+ lines with a terminal
    # +data: [DONE]\n\n+ marker. Accumulates delta content and tool_calls across
    # chunks to build a final normalized response.
    #
    # Raises +AgentDesk::StreamError+ if the stream ends without the +[DONE]+ sentinel,
    # indicating the connection was interrupted. The +partial_content+ attribute of the
    # raised error contains any content accumulated before the interruption.
    #
    # @example
    #   accumulated = SSEParser.parse(io) do |chunk|
    #     print chunk[:content]
    #   end
    #   puts accumulated[:role]      # => "assistant"
    #   puts accumulated[:content]   # => full accumulated text
    module SSEParser
      # Parses SSE data from an IO-like object.
      #
      # Yields +{ type: "chunk", content: chunk_text }+ for each delta with content.
      # Returns the fully accumulated response hash with :role, :content,
      # :tool_calls, :usage, :finish_reason.
      #
      # @param io [#each_line] IO-like object yielding SSE lines
      # @yield [chunk] called for each content delta
      # @yieldparam chunk [Hash] with :type ("chunk") and :content (String) keys
      # @return [Hash] accumulated response with :role, :content, :tool_calls, :usage
      # @raise [StreamError] if the stream ends without a +[DONE]+ sentinel
      def self.parse(io, &block)
        role = nil
        content_parts = []
        tool_calls_acc = {}   # index => { id:, function: { name:, arguments: "" } }
        usage = nil
        finish_reason = nil
        done = false

        io.each_line do |line|
          line = line.chomp
          next if line.empty?
          next unless line.start_with?("data:")

          data = line.sub(/\Adata:\s?/, "")

          if data == "[DONE]"
            done = true
            break
          end

          begin
            parsed = JSON.parse(data)
          rescue JSON::ParserError
            # Skip unparseable lines — some proxies send comments or metadata
            next
          end

          # Capture usage if present (some providers send it in a separate SSE event)
          usage = parsed["usage"] if parsed["usage"]

          choice = parsed.dig("choices", 0)
          next unless choice

          delta = choice["delta"] || {}
          finish_reason = choice["finish_reason"] if choice["finish_reason"]
          role ||= delta["role"]

          # Accumulate content
          if delta["content"]
            content_parts << delta["content"]
            yield({ type: "chunk", content: delta["content"] }) if block
          end

          # Accumulate tool_calls by index
          next unless delta["tool_calls"]

          delta["tool_calls"].each do |tc|
            idx = tc["index"]
            tool_calls_acc[idx] ||= { id: nil, function: { name: +"", arguments: +"" } }
            tool_calls_acc[idx][:id] = tc["id"] if tc["id"]
            next unless tc["function"]

            tool_calls_acc[idx][:function][:name] << tc.dig("function", "name").to_s
            tool_calls_acc[idx][:function][:arguments] << tc.dig("function", "arguments").to_s
          end
        end

        # Detect stream interruption: content was received but [DONE] was never sent
        unless done
          partial = content_parts.empty? ? nil : content_parts.join
          raise StreamError.new(
            "SSE stream ended without [DONE] sentinel — stream may have been interrupted",
            partial_content: partial
          )
        end

        # Build final accumulated tool_calls
        final_tool_calls =
          if tool_calls_acc.empty?
            nil
          else
            tool_calls_acc.sort_by { |idx, _| idx }.map do |_idx, tc|
              tc[:function][:arguments] = begin
                JSON.parse(tc[:function][:arguments])
              rescue JSON::ParserError
                {}
              end
              tc
            end
          end

        {
          role: role || "assistant",
          content: content_parts.empty? ? nil : content_parts.join,
          tool_calls: final_tool_calls,
          usage: ResponseNormalizer.normalize_usage(usage),
          finish_reason: finish_reason
        }
      end
    end
  end
end
