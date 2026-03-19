require "net/http"

class HttpJsonClient
  class Error < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  def initialize(default_headers: {})
    @default_headers = default_headers
  end

  def get_json(url, headers: {}, query: {}, retries: 3)
    uri = URI(url)
    uri.query = URI.encode_www_form(query) if query.any?

    with_retries(retries) do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")

      req = Net::HTTP::Get.new(uri)
      (@default_headers.merge(headers)).each { |k, v| req[k] = v }

      res = http.request(req)
      handle_response(res)
    end
  end

  private

  def with_retries(retries)
    attempts = 0

    begin
      attempts += 1
      yield
    rescue Error => e
      raise if attempts > retries

      status = begin
        Integer(e.status)
      rescue
        0
      end

      if status == 429
        sleep(0.5 * (2**(attempts - 1)))
        retry
      end

      raise
    end
  end

  def handle_response(res)
    status = res.code.to_i
    body = res.body

    unless status.between?(200, 299)
      raise Error.new("HTTP #{status}", status: status, body: body)
    end

    JSON.parse(body)
  rescue JSON::ParserError
    raise Error.new("Invalid JSON response", status: status, body: body)
  end
end
