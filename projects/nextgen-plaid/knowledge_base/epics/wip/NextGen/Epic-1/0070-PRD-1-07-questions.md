I found /admin/health already exists (Admin::HealthController#index) but it’s currently an HTML dashboard with a placeholder check_worker (Sidekiq-oriented) and no Solid Queue metrics.
Before I implement PRD-1-07, a few clarifications to ensure the right behavior:
1)
Response format: PRD says “Response: JSON …” — should /admin/health return JSON always, or return HTML by default and JSON when requested (e.g., Accept: application/json or .json)?
-- it should return json the view code should interpret and display html.


2.)
“Solid Queue process running”: do you want an OS-level process check (e.g., ps/PID/hostname) or an app-level liveness signal (recommended) such as a heartbeat written to DB/Redis by the worker?
-- both 
3.)
“Recent job executions / last job timestamp”: which timestamp should we use? -- cst yy:mm:dd:ss.ms
◦
last finished job (finished_at), yes
◦
last claimed job, yes
◦
or last successfully completed job only? yes
4)
Queue depth: do you want depth for all queues combined, or specific queue(s) (e.g., default, mailers, etc.)? all
5)
Alert threshold: Acceptance says “no jobs processed in 1 hour” — should that be configurable via ENV, or hard-coded to 1 hour?
If you’re OK with sensible defaults, I can proceed with: agree 
•
HTML remains for browser, JSON for .json/Accept: application/json
•
DB-based metrics from Solid Queue tables
•
1 hour threshold configurable via ENV with 1h default
•
queue depth aggregated across all queues