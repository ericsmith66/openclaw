### Project Environment Variables

This document lists the environment variables used in the project, their defaults, acceptable values, and their impact on the system.

#### UI / Feature Flags

| Variable | Default | Acceptable Values | Description |
| :--- | :--- | :--- | :--- |
| `ENABLE_NEW_LAYOUT` | `true` in non-production, `false` in production | `true`, `false` | Enables the authenticated wireframe layout (`authenticated.html.erb`) for signed-in users. In `production`, it is enabled only when explicitly set to `true`. In other environments it defaults to `true` unless explicitly set to `false`. |

#### Access Control

| Variable | Default | Acceptable Values | Description |
| :--- | :--- | :--- | :--- |
| `OWNER_EMAIL` | `ericsmith66@me.com` | Any valid email | Defines the “owner” user. Used to gate owner/admin-only UI sections and endpoints (e.g., Mission Control, Agent Hub, Admin Health). |

#### SmartProxy Configuration

| Variable | Default | Acceptable Values | Description |
| :--- | :--- | :--- | :--- |
| `SMARTPROXY_BASE_URL` | `http://127.0.0.1:3002` | Any valid URL | The base URL for the SmartProxy service. It is used by client scripts and integration tests to communicate with the proxy. |
| `SMARTPROXY_TOKEN` | `sk-continue` | Any string | The authorization token (Bearer) used to authenticate requests to the SmartProxy. Ensure this matches between the proxy and its clients. |
| `SMART_PROXY_PORT` | `3002` | Any valid port number | The port on which the SmartProxy Sinatra application runs (this repo’s `Procfile.dev` uses `3002`). Note: some smoke tests default to `4567` if `SMART_PROXY_PORT` is not set. |
| `SMART_PROXY_ENABLE_WEB_TOOLS` | `false` | `true`, `false` | Enables or disables web search tools within the SmartProxy. When enabled, models can trigger web searches via the `/proxy/tools` or unified chat endpoints. |
| `SMART_PROXY_LOG_LEVEL` | `info` | `debug`, `info`, `warn`, `error` | Sets the logging verbosity for the SmartProxy. Use `debug` for detailed request/response tracing and troubleshooting. |
| `SMART_PROXY_URL` | `http://localhost:${SMART_PROXY_PORT}` | Any valid URL | Base URL used by the Rails app for proxy health checks (e.g., `/admin/health` hits `${SMART_PROXY_URL}/health`). If not set, the app derives it from `SMART_PROXY_PORT`. |
| `PROXY_AUTH_TOKEN` | (empty) | Any string | Optional Bearer token used by some smoke tests/clients when calling SmartProxy endpoints. Note: the repo also uses `SMARTPROXY_TOKEN` in some scripts—keep them consistent if both are used. |

#### LLM Provider Configuration

| Variable | Default | Acceptable Values | Description |
| :--- | :--- | :--- | :--- |
| `OLLAMA_HOST` | `http://localhost:11434` | Any valid URL | The address of the Ollama server. SmartProxy routes requests for Ollama-compatible models to this host. |
| `OLLAMA_MODEL` | `llama3.1:70b` | Any pulled Ollama model | The default model name used for Ollama requests if none is specified by the client. Impact: Determines the AI performance and latency. |
| `GROK_API_KEY` | (empty) | Valid xAI API key | The API key for xAI (Grok). If missing, Grok-related features and live tests will be skipped. |
| `GROK_MODEL` | `grok-4` | `grok-4`, `grok-4-with-live-search` | The specific Grok model version to use. Impact: affects response quality and availability of search features. |
| `XAI_KEY` | (empty) | Valid xAI API key | Used in diagnostic scripts (like `smarproxy_live_search_check.sh`) for direct xAI API sanity checks. |
| `GROK_API_KEY_SAP` | (empty) | Valid xAI API key | Used by SAP/agent workflows that talk to Grok/xAI for RAG/agent operations (and is filtered in VCR cassettes). |
| `FMP_API_KEY` | (empty) | Valid Financial Modeling Prep API key | Used by holdings enrichment (FMP) to fetch security/company metadata (and is filtered in VCR cassettes). |

#### Test Environment Controls

| Variable | Default | Acceptable Values | Description |
| :--- | :--- | :--- | :--- |
| `SMART_PROXY_LIVE_TEST` | `false` | `true`, `false` | Enables live smoke tests that hit a running SmartProxy instance. These are skipped by default to avoid external dependencies during normal test runs. |
| `INTEGRATION_TESTS` | (empty) | `1`, any value | Enables integration tests that involve multiple components or real HTTP calls. Impact: significantly increases test duration and requires external services (like SmartProxy) to be running. |
| `DRY_RUN` | (empty) | Any value | If set, certain operations (like pushing to external queues) will be skipped and logged instead. Useful for testing logic without side effects. |
| `SKIP_VCR` | (empty) | `true`, `1` | If set, VCR will be disabled, forcing tests to make real network requests instead of using recorded cassettes. |

#### Plaid Integration

| Variable | Default | Acceptable Values | Description |
| :--- | :--- | :--- | :--- |
| `PLAID_CLIENT_ID` | (empty) | Valid Plaid Client ID | Required for authenticating with the Plaid API. Impact: System cannot sync bank data without this. |
| `PLAID_SECRET` | (empty) | Valid Plaid Secret | The secret key for your Plaid environment (sandbox, development, or production). Must match the environment. |
| `PLAID_ENV` | `sandbox` | `sandbox`, `development`, `production` | Specifies which Plaid environment to use. Impact: Determines whether you use test data or real financial data. |

#### Admin Health / Solid Queue Monitoring

| Variable | Default | Acceptable Values | Description |
| :--- | :--- | :--- | :--- |
| `ADMIN_HEALTH_STALE_SECONDS` | `3600` | Integer seconds | Threshold used by `/admin/health` to flag “stale” background processing if no jobs have finished recently. |
| `SOLID_QUEUE_HEARTBEAT_STALE_SECONDS` | `60` | Integer seconds | Threshold used by `/admin/health` to determine whether Solid Queue worker process heartbeats are fresh. |
| `JOB_SERVER_HOST` | `192.168.4.253` | Hostname/IP | Host checked (TCP connect) by `/admin/health` for OS-level reachability of the job server. |
| `JOB_SERVER_PORT` | `22` | Port number | Port checked (TCP connect) by `/admin/health` for OS-level reachability of the job server. |
| `SOLID_QUEUE_WORKER_PID` | (empty) | PID (integer) | Optional local PID to check on the same host as the web process. If set, `/admin/health` will attempt a `kill(0, pid)` style liveness check. |

#### Cloudflare / External Endpoint Checks

| Variable | Default | Acceptable Values | Description |
| :--- | :--- | :--- | :--- |
| `CLOUDFLARE_CHECK_ENDPOINTS` | (empty) | Comma-separated URLs | Optional list of endpoints the health page will request and report (e.g., `https://example.com/health,https://api.example.com/ping`). If unset/blank (or incorrectly set to `true`), checks are skipped. |

#### System & Infrastructure

| Variable | Default | Acceptable Values | Description |
| :--- | :--- | :--- | :--- |
| `DATABASE_URL` | (calculated) | Valid DB connection string | The connection string for the primary database. In production, this usually points to a PostgreSQL instance. |
| `REDIS_URL` | `redis://localhost:6379/1` | Valid Redis URL | The connection string for Redis, used for caching and background job queuing (Sidekiq/SolidQueue). |
| `RAILS_ENV` | `development` | `development`, `test`, `production` | The standard Rails environment setting. Impact: affects caching, error handling, and resource optimization. |
| `SECRET_KEY_BASE` | (empty) | Long random string | Used for encrypting sessions and other security-sensitive data. Must be kept secret and stable in production. |
| `ACTION_CABLE_URL` | (empty) | WebSocket URL (ws/wss) | Optional override for Action Cable URL in development when Rails is accessed via a different host/port than it’s bound to (e.g., `ws://192.168.4.253:3000/cable`). |
