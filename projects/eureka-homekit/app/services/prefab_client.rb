require "open3"
require "timeout"

class PrefabClient
  class ConnectionError < StandardError; end

  BASE_URL = ENV.fetch("PREFAB_API_URL", "http://localhost:8080")
  READ_TIMEOUT = ENV.fetch("PREFAB_READ_TIMEOUT", "15000").to_i
  READ_RETRY_TIMEOUT = ENV.fetch("PREFAB_READ_RETRY_TIMEOUT", "30000").to_i
  WRITE_TIMEOUT = ENV.fetch("PREFAB_WRITE_TIMEOUT", "5000").to_i

  def self.homes
    fetch_json("/homes")
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    []
  end

  def self.rooms(home)
    fetch_json("/rooms/#{ERB::Util.url_encode(home)}")
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    []
  end

  def self.accessories(home, room)
    fetch_json("/accessories/#{ERB::Util.url_encode(home)}/#{ERB::Util.url_encode(room)}")
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    []
  end

  def self.accessory_details(home, room, accessory)
    fetch_json("/accessories/#{ERB::Util.url_encode(home)}/#{ERB::Util.url_encode(room)}/#{ERB::Util.url_encode(accessory)}")
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    nil
  end

  def self.scenes(home)
    fetch_json("/scenes/#{ERB::Util.url_encode(home)}")
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    []
  end

  # Write operations
  def self.update_characteristic(home, room, accessory, service_id, characteristic_id, value, request_id: nil)
    url = "#{BASE_URL}/accessories/#{ERB::Util.url_encode(home)}/#{ERB::Util.url_encode(room)}/#{ERB::Util.url_encode(accessory)}"

    payload = {
      serviceId: service_id,
      characteristicId: characteristic_id,
      value: value.to_s
    }.to_json
    result, success, latency, exit_status = execute_curl_put(url, payload, request_id: request_id)

    if success
      Rails.logger.info("PrefabClient [#{request_id}]: update_characteristic success - #{characteristic_id}=#{value}")
      { success: true, value: value, latency_ms: latency }
    else
      Rails.logger.error("PrefabClient [#{request_id}]: update_characteristic failed - exit_code=#{exit_status}, error=#{result.strip}")
      { success: false, error: result.strip, latency_ms: latency, exit_status: exit_status }
    end
  rescue StandardError => e
    Rails.logger.error("PrefabClient [#{request_id}]: error: #{e.message}")
    { success: false, error: e.message, latency_ms: nil, exit_status: nil }
  end

  def self.execute_scene(home, scene_uuid, request_id: nil)
    url = "#{BASE_URL}/scenes/#{ERB::Util.url_encode(home)}/#{ERB::Util.url_encode(scene_uuid)}/execute"

    result, success, latency, exit_status = execute_curl_post(url, request_id: request_id)

    if success
      Rails.logger.info("PrefabClient [#{request_id}]: execute_scene success - #{scene_uuid}")
      { success: true, latency_ms: latency }
    else
      Rails.logger.error("PrefabClient [#{request_id}]: execute_scene failed - exit_code=#{exit_status}, error=#{result.strip}")
      { success: false, error: result.strip, latency_ms: latency, exit_status: exit_status }
    end
  rescue StandardError => e
    Rails.logger.error("PrefabClient [#{request_id}]: error: #{e.message}")
    { success: false, error: e.message, latency_ms: nil, exit_status: nil }
  end

  private

  def self.fetch_json(path)
    url = "#{BASE_URL}#{path}"
    result, success = execute_curl(url)

    if success
      JSON.parse(result)
    else
      # accessory_details paths have 3 slashes after accessories (home/room/accessory)
      # while accessories list paths have 2 slashes (home/room)
      is_detail_request = path.start_with?("/accessories/") && path.count("/") >= 4
      is_detail_request ? nil : []
    end
  end

  def self.execute_curl(url)
    result, success, latency, exit_status = execute_curl_base(url, method: "GET", timeout_ms: READ_TIMEOUT)

    if !success && exit_status == 28
      Rails.logger.warn("PrefabClient: GET timeout (#{READ_TIMEOUT}ms) for #{url}. Retrying with #{READ_RETRY_TIMEOUT}ms.")
      result, success, latency, exit_status = execute_curl_base(url, method: "GET", timeout_ms: READ_RETRY_TIMEOUT)
    end

    [ result, success, latency, exit_status ]
  end

  def self.execute_curl_put(url, payload, request_id: nil)
    execute_curl_base(url, method: "PUT", payload: payload, request_id: request_id)
  end

  def self.execute_curl_post(url, payload = nil, request_id: nil)
    execute_curl_base(url, method: "POST", payload: payload, request_id: request_id)
  end

  def self.execute_curl_base(url, method:, payload: nil, request_id: nil, timeout_ms: WRITE_TIMEOUT)
    start_time = Time.now
    begin
      args = [ "curl", "-s", "-m#{timeout_ms / 1000.0}", "-X", method, "-H", "Content-Type: application/json" ]
      args.push("-d", payload) if payload
      args.push(url)

      stdout = ""
      stderr = ""
      exit_status = nil

      Timeout.timeout(timeout_ms / 1000.0 + 1.0) do
        stdout, stderr, wait_thr = Open3.capture3(*args)
        exit_status = wait_thr.exitstatus
      end

      success = exit_status == 0
      latency = ((Time.now - start_time) * 1000).round(2)

      result = stdout
      error = stderr

      unless success
        Rails.logger.error("PrefabClient [#{request_id}]: curl #{method} failed with exit code #{exit_status}")
        Rails.logger.error("PrefabClient [#{request_id}]: curl error output: #{error}")
      end

      [ result, success, latency, exit_status ]
    rescue StandardError => e
      latency = ((Time.now - start_time) * 1000).round(2)
      Rails.logger.error("PrefabClient [#{request_id}]: curl #{method} error: #{e.message}")
      [ "", false, latency, nil ]
    end
  end
end
