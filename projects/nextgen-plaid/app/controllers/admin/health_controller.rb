require "socket"
require "timeout"

class Admin::HealthController < ApplicationController
  before_action :authenticate_user!

  rescue_from Pundit::NotAuthorizedError, with: :render_not_authorized

  def index
    authorize :health, :index?

    respond_to do |format|
      format.json { render json: health_payload }
      format.html
    end
  end

  private

  def render_not_authorized
    if request.format.json?
      render json: { error: "not_authorized" }, status: :forbidden
    else
      user_not_authorized
    end
  end

  def health_payload
    checked_at = Time.current

    solid_queue = check_solid_queue(checked_at)

    components = {
      proxy: check_proxy(checked_at),
      solid_queue: solid_queue,
      action_cable: check_action_cable(checked_at),
      cloudflare: check_cloudflare(checked_at)
    }

    overall_status = components.values.all? { |c| c[:status] == "OK" } ? "OK" : "FAIL"

    {
      status: overall_status,
      checked_at: format_cst_timestamp(checked_at),
      components: components
    }
  end

  def format_cst_timestamp(time)
    return nil unless time

    time.in_time_zone("America/Chicago").strftime("CST %y:%m:%d:%H:%M:%S.%L")
  end

  def stale_threshold
    seconds = ENV.fetch("ADMIN_HEALTH_STALE_SECONDS", 3600).to_i
    seconds.seconds
  end

  def solid_queue_heartbeat_stale_threshold
    seconds = ENV.fetch("SOLID_QUEUE_HEARTBEAT_STALE_SECONDS", 60).to_i
    seconds.seconds
  end

  def check_solid_queue(checked_at)
    # Queue depth across all queues (unfinished jobs)
    unfinished_jobs = SolidQueue::Job.where(finished_at: nil)
    queue_depth_total = unfinished_jobs.count
    queue_depth_by_queue = unfinished_jobs.group(:queue_name).count

    last_finished_at = SolidQueue::Job.where.not(finished_at: nil).maximum(:finished_at)
    last_claimed_at = SolidQueue::ClaimedExecution.maximum(:created_at)
    last_succeeded_at = SolidQueue::Job
      .where.not(finished_at: nil)
      .where.not(id: SolidQueue::FailedExecution.select(:job_id))
      .maximum(:finished_at)

    active_processes = SolidQueue::Process.where("last_heartbeat_at >= ?", checked_at - solid_queue_heartbeat_stale_threshold)
    heartbeat_ok = active_processes.exists?

    os_level = check_job_server_reachability

    stale = last_finished_at.nil? || last_finished_at < checked_at - stale_threshold

    status = if heartbeat_ok && !stale
               "OK"
    else
               "FAIL"
    end

    last_finished_by_class = SolidQueue::Job
      .where.not(finished_at: nil)
      .group(:class_name)
      .maximum(:finished_at)
      .transform_values { |t| format_cst_timestamp(t) }

    recurring_tasks = SolidQueue::RecurringTask.order(:key).map do |t|
      last_exec = SolidQueue::RecurringExecution.where(task_key: t.key).order(run_at: :desc).first
      job = last_exec && SolidQueue::Job.find_by(id: last_exec.job_id)

      {
        key: t.key,
        schedule: t.schedule,
        kind: t.class_name.presence || t.command,
        last_run_at: format_cst_timestamp(last_exec&.run_at),
        last_finished_at: format_cst_timestamp(job&.finished_at)
      }
    end

    {
      status: status,
      queue_depth: {
        total: queue_depth_total,
        by_queue: queue_depth_by_queue
      },
      last_job: {
        finished_at: format_cst_timestamp(last_finished_at),
        claimed_at: format_cst_timestamp(last_claimed_at),
        succeeded_at: format_cst_timestamp(last_succeeded_at)
      },
      dashboard: {
        last_finished_by_class: last_finished_by_class,
        recurring_tasks: recurring_tasks
      },
      processes: {
        heartbeat_ok: heartbeat_ok,
        active_count: active_processes.count
      },
      os_level: os_level,
      alerts: {
        stale_no_jobs_processed: stale
      },
      timestamp: format_cst_timestamp(checked_at)
    }
  rescue NameError => e
    {
      status: "FAIL",
      message: "Solid Queue not available: #{e.class}",
      timestamp: format_cst_timestamp(checked_at)
    }
  end

  def check_job_server_reachability
    host = ENV.fetch("JOB_SERVER_HOST", "192.168.4.253")
    port = ENV.fetch("JOB_SERVER_PORT", 22).to_i

    reachable = false
    error = nil

    begin
      Timeout.timeout(0.5) do
        socket = TCPSocket.new(host, port)
        socket.close
        reachable = true
      end
    rescue => e
      error = e.message
    end

    # Optional local PID check (only meaningful if the health endpoint runs on the same host)
    pid = ENV["SOLID_QUEUE_WORKER_PID"]
    pid_alive = nil
    if pid.present?
      begin
        Process.kill(0, Integer(pid))
        pid_alive = true
      rescue
        pid_alive = false
      end
    end

    {
      host: host,
      port: port,
      reachable: reachable,
      error: error,
      pid: pid,
      pid_alive: pid_alive
    }
  end

  def check_proxy(checked_at)
    # Placeholder: In a real app, we'd hit the proxy's health endpoint or list models
    # SmartProxy is likely on a port or specific URL
    smart_proxy_port = ENV["SMART_PROXY_PORT"] || "3002"
    proxy_url = ENV["SMART_PROXY_URL"] || "http://localhost:#{smart_proxy_port}"
    begin
      response = Faraday.get("#{proxy_url}/health")
      { status: response.success? ? "OK" : "FAIL", message: "Response: #{response.status}", timestamp: format_cst_timestamp(checked_at) }
    rescue => e
      { status: "FAIL", message: e.message, timestamp: format_cst_timestamp(checked_at) }
    end
  end

  def check_action_cable(checked_at)
    # Check if Action Cable server is running
    # This is a bit tricky from within the same process, but we can check if it's mounted
    {
      status: ActionCable.server.present? ? "OK" : "FAIL",
      timestamp: format_cst_timestamp(checked_at)
    }
  end

  def check_cloudflare(checked_at)
    endpoints_str = ENV["CLOUDFLARE_CHECK_ENDPOINTS"]
    # If set to "true" (legacy/incorrect config), don't treat it as a URL
    endpoints = if endpoints_str == "true" || endpoints_str.blank?
                  []
    else
                  endpoints_str.split(",")
    end

    results = endpoints.map do |url|
      # Force HTTPS (port 443) if no scheme is provided or if port 80 is detected
      begin
        stripped_url = url.to_s.strip
        next nil if stripped_url.blank? || stripped_url == "true"

        uri = URI.parse(stripped_url)
        uri.scheme = "https" if uri.scheme.nil? || uri.scheme == "http"
        # If no host is provided but a port is (e.g., ":80"), URI.parse might put ":80" in path or host depending on input
        # We ensure that we have a host and the correct port
        if uri.host.nil? && uri.path.present? && !uri.path.include?("/")
          uri.host = uri.path
          uri.path = ""
        end

        uri.port = 443 if uri.port == 80 || uri.port.nil?
        target_url = uri.to_s

        response = Faraday.get(target_url)
        { url: target_url, status: response.success? ? "OK" : "FAIL", message: "Status: #{response.status}" }
      rescue => e
        { url: url, status: "FAIL", message: e.message }
      end
    end.compact
    { status: results.empty? || results.all? { |r| r[:status] == "OK" } ? "OK" : "FAIL", checks: results, timestamp: format_cst_timestamp(checked_at) }
  end
end
