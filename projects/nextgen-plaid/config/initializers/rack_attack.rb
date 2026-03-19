# frozen_string_literal: true

class Rack::Attack
  # In test/dev we often use `:null_store`; that would disable throttling.
  # Use an in-memory store so request counts are tracked.
  self.cache.store = ActiveSupport::Cache::MemoryStore.new

  throttle("snapshot_sync/user", limit: 1, period: 60) do |req|
    next unless req.path.match?(%r{\A/net_worth/sync\z}) && req.post?

    req.env["warden"]&.user&.id
  end

  self.throttled_responder = lambda do |req|
    now = Time.now.to_i

    throttle_data = req.env["rack.attack.throttle_data"] || {}
    data = throttle_data["snapshot_sync/user"] || {}
    period = (data[:period] || 60).to_i
    epoch_time = data[:epoch_time].to_i
    retry_after = epoch_time.positive? ? (epoch_time + period - now) : period
    retry_after = [ [ retry_after, 1 ].max, period ].min

    user = req.env["warden"]&.user

    headers = {
      "Content-Type" => "text/plain",
      "Retry-After" => retry_after.to_s
    }

    if user && req.get_header("HTTP_ACCEPT").to_s.include?("text/vnd.turbo-stream.html")
      html = ApplicationController.render(
        partial: "net_worth/sync_status",
        formats: [ :html ],
        locals: {
          status: :rate_limited,
          snapshot: FinancialSnapshot.latest_for_user(user),
          retry_after: retry_after
        }
      )

      body = <<~TURBO
        <turbo-stream action="replace" target="sync-status">
          <template>#{html}</template>
        </turbo-stream>
      TURBO

      headers["Content-Type"] = "text/vnd.turbo-stream.html; charset=utf-8"
      [ 429, headers, [ body ] ]
    else
      [ 429, headers, [ "Refresh limit reached — try again in #{retry_after}s" ] ]
    end
  end
end
