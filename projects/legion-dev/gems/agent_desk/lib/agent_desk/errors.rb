# frozen_string_literal: true

module AgentDesk
  # Base error class for all agent_desk errors.
  #
  # @example Rescue all agent_desk errors
  #   rescue AgentDesk::Error => e
  class Error < StandardError; end

  # Raised when required configuration is missing or invalid.
  #
  # @example
  #   raise ConfigurationError, "api_key is required for provider :openai"
  class ConfigurationError < Error; end

  # Raised when the LLM endpoint returns a non-200 response or malformed data.
  #
  # @!attribute [r] status
  #   @return [Integer, nil] HTTP status code (nil for parse errors)
  # @!attribute [r] response_body
  #   @return [String, nil] raw response body
  class LLMError < Error
    attr_reader :status, :response_body

    # @param message [String] human-readable error description
    # @param status [Integer, nil] HTTP status code
    # @param response_body [String, nil] raw response body
    def initialize(message, status: nil, response_body: nil)
      @status = status
      @response_body = response_body
      super(message)
    end
  end

  # Raised when an HTTP request exceeds the configured timeout.
  class TimeoutError < Error; end

  # Raised when an SSE stream is interrupted or encounters a parse error.
  #
  # @!attribute [r] partial_content
  #   @return [String, nil] content accumulated before the interruption
  class StreamError < Error
    attr_reader :partial_content

    # @param message [String] human-readable error description
    # @param partial_content [String, nil] content accumulated before interruption
    def initialize(message, partial_content: nil)
      @partial_content = partial_content
      super(message)
    end
  end

  # Raised when a file path resolves outside the project directory (path traversal).
  class PathTraversalError < Error; end

  # Raised when a template file cannot be found in any location
  # (project, global, or bundled defaults).
  #
  # @example
  #   raise TemplateNotFoundError, "Template 'system-prompt' not found"
  class TemplateNotFoundError < Error; end

  # Raised when a Liquid template contains syntax errors.
  #
  # @example
  #   raise TemplateSyntaxError, "Liquid syntax error in system-prompt.liquid: ..."
  class TemplateSyntaxError < Error; end
end
