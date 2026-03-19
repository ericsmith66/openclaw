require 'digest'
require 'securerandom'

class RequestAuthenticator
  def initialize(auth_token:, request:, logger: nil, session_id: nil)
    @auth_token = auth_token
    @request = request
    @logger = logger
    @session_id = session_id
  end

  def authenticate!
    return if @auth_token.to_s.empty?

    auth_header = @request.env['HTTP_AUTHORIZATION']
    provided_token = auth_header&.gsub(/^Bearer /, '')&.strip

    return if provided_token == @auth_token

    log_unauthorized(provided_token)

    # We return a hash that the controller can use to halt
    {
      status: 401,
      body: {
        id: "chatcmpl-#{SecureRandom.hex(8)}",
        object: 'chat.completion',
        created: Time.now.to_i,
        model: 'unknown',
        choices: [
          {
            index: 0,
            finish_reason: 'error',
            message: {
              role: 'assistant',
              content: 'SmartProxy error (401): Unauthorized'
            }
          }
        ],
        usage: {
          prompt_tokens: 0,
          completion_tokens: 0,
          total_tokens: 0
        },
        smart_proxy_error: {
          type: 'unauthorized'
        }
      }.to_json
    }
  end

  private

  def log_unauthorized(provided_token)
    expected_digest = Digest::SHA256.hexdigest(@auth_token.to_s)[0, 12]
    provided_digest = provided_token.nil? ? nil : Digest::SHA256.hexdigest(provided_token.to_s)[0, 12]

    @logger&.warn({
      event: 'unauthorized_access',
      session_id: @session_id,
      method: @request.request_method,
      path: @request.path_info,
      user_agent: @request.user_agent,
      remote_addr: @request.ip,
      provided_token: provided_token,
      expected_token_sha256_12: expected_digest,
      provided_token_sha256_12: provided_digest
    })
  end
end
