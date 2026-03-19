# Remote Instance Inspection Report
**Target:** 192.168.4.253 (Production Server M3 Ultra)  
**Application:** NextGen Plaid  
**Inspection Date:** February 16, 2026  
**Inspector:** DevOps Engineer

## Executive Summary

The remote instance at `/Users/ericsmith66/Development/nextgen-plaid` is running a **development environment** with Puma on port 3000, using development databases. The server is actively processing requests and has substantial data in its databases. This is **not a production deployment** but a development server with production Plaid API keys.

## Environment Details

### Server Specifications
- **Hostname:** nextgen
- **OS:** macOS 25.1.0 (Darwin Kernel Version 25.1.0)
- **Architecture:** ARM64 (Apple Silicon M3 Ultra)
- **Memory:** 256 GB
- **Disk:** 1.8TB total, 233GB used, 1.6TB available (13% used)
- **Network:** Local IP 192.168.4.253, accessible via SSH

### Running Services
| Service | Port | Process ID | Status | Notes |
|---------|------|------------|--------|-------|
| NextGen Plaid (Puma) | 3000 | 12176 | ✅ Running | Development environment |
| Smart Proxy (Rack) | 3002 | 12180 | ✅ Running | Separate Sinatra application |
| Tailwind CSS watcher | - | 12177 | ✅ Running | Asset compilation |
| Solid Queue worker | - | - | ✅ Likely running | Background job processing |

### Application Configuration

#### Rails Environment
- **Environment:** Development (`RAILS_ENV=development` inferred)
- **Evidence:**
  - Active `development.log` (35MB current, 104MB rotated)
  - Minimal `production.log` (9KB)
  - Web Console middleware present (development-only feature)
  - Development database configuration in use
- **Ruby Version:** 3.3.10 (specified in `.ruby-version`)
- **Rails Version:** 8.1.1 (from Gemfile.lock)
- **PostgreSQL Version:** 16.11 (Homebrew)

#### Database Configuration
**Active Databases (Development):**
- `nextgen_plaid_development` (Primary application database)
- `nextgen_plaid_development_queue` (Solid Queue jobs)
- `nextgen_plaid_development_cable` (Action Cable)

**Missing Databases (Production):**
- `nextgen_plaid_production` - **NOT FOUND**
- `nextgen_plaid_production_queue` - **NOT FOUND**
- `nextgen_plaid_production_cable` - **NOT FOUND**

**Database Connection:** Local PostgreSQL instance (no Docker containers)

#### Plaid API Configuration
- **Plaid Environment:** Production (`PLAID_ENV=production` in `.env`)
- **Client ID:** Set (partially redacted in logs)
- **Secret:** Set (partially redacted in logs)
- **Redirect URI:** `https://api.higroundsolutions.com/plaid_oauth/callback`

**Note:** Using production Plaid keys in a development Rails environment.

### Application State

#### Active Processes
```
puma 7.1.0 (tcp://0.0.0.0:3000) [nextgen-plaid]    # Main application
puma 7.1.0 (tcp://0.0.0.0:3002) [smart_proxy]      # Proxy service
ruby bin/rails tailwindcss:watch                    # Asset watcher
```

#### Database Activity
Recent logs show active database transactions:
- Solid Queue heartbeat updates every few seconds
- Active database connections
- Regular job processing

#### Database Contents
**Sample Table Counts (Top 20 tables exist):**
- `account_balance_snapshots`
- `accounts`
- `active_storage_attachments`
- `active_storage_blobs`
- `active_storage_variant_records`
- `agent_logs`
- `ai_workflow_runs`
- `ar_internal_metadata`
- `artifacts`
- `backlog_items`
- `enriched_transactions`
- `financial_snapshots`
- `fixed_incomes`
- `holdings`
- `holdings_snapshots`
- `merchants`
- `option_contracts`
- `other_incomes`
- `ownership_lookups`
- `persona_conversations`

**Data Volume:** Significant data present (based on log activity and table existence)

### Startup Configuration

#### Procfile.dev
```yaml
web: bin/rails server -b 0.0.0.0
css: bin/rails tailwindcss:watch
proxy: cd smart_proxy && SMART_PROXY_PORT=3002 bundle exec rackup -o 0.0.0.0 -p 3002
worker: bin/rails solid_queue:start
```

**Startup Method:** Likely started via `foreman start -f Procfile.dev` or similar process manager.

#### Environment Files
- `.env` - Primary environment variables (contains Plaid production keys)
- `.env.example` - Example configuration
- `.env.production` - Production configuration (not actively used)

### Network Accessibility

#### Local Access
- **Application:** `http://localhost:3000` (responsive, returns HTML)
- **Health Endpoint:** `/health` - Not implemented (returns routing error)
- **Routes:** Multiple application routes active (see inspection logs)

#### External Access
- **Cloudflare Tunnel:** Configured for `api.higroundsolutions.com`
- **Current Routing:** Unknown if traffic is routed to this instance
- **Firewall:** Local macOS firewall, Ubiquiti UDM-SE network firewall

### Security Assessment

#### Strengths
- SSH key authentication required
- Local network isolation
- PostgreSQL running locally (no external exposure)
- Credentials in `.env` file (not in version control)

#### Concerns
- **Mixed Environment:** Production Plaid keys with development Rails environment
- **No Health Monitoring:** No `/health` endpoint for monitoring
- **Development Features:** Web console enabled (potential security risk if exposed)
- **Process Longevity:** Puma process running since "Mon08PM" (multiple days)

### Resource Utilization

#### Memory
- Puma process: ~1GB RSS (based on `ps aux` output)
- Total memory usage: Moderate (256GB available, minimal usage)

#### CPU
- Low CPU utilization (processes showing minimal CPU time)
- Server appears underutilized

#### Storage
- Application directory: ~1GB (estimated)
- Log files: ~140MB active, additional rotated logs
- Database size: Unknown (likely < 1GB based on table counts)

## Implications for Database Sync

### Current State vs Assumptions
| Assumption | Reality | Impact |
|------------|---------|--------|
| Production databases exist | Only development databases exist | Sync script should target development databases |
| Server is production environment | Server is development environment | Data may be less stable but more current |
| Databases may be large | Databases likely moderate size | Sync should complete quickly |
| PostgreSQL standard port | PostgreSQL running on standard port | Connection parameters correct |

### Recommended Sync Approach
1. **Source Databases:** `nextgen_plaid_development`, `nextgen_plaid_development_queue`, `nextgen_plaid_development_cable`
2. **Target Databases:** Same names locally (development environment)
3. **Method:** SSH + pg_dump streaming (as planned)
4. **Safety:** Backup local databases before overwrite

### Special Considerations
1. **Plaid Tokens:** Database contains encrypted Plaid access tokens tied to production Plaid environment
2. **Encryption Keys:** Ensure `ENCRYPTION_KEY` matches between environments for token decryption
3. **Queue Jobs:** Active Solid Queue jobs may be in progress; sync may capture mid-execution state
4. **Data Freshness:** Development data may be more current than any local copy

## Recommendations

### Immediate Actions
1. **Document Environment:** Update deployment documentation to reflect this is a development server
2. **Health Monitoring:** Implement `/health` endpoint for basic monitoring
3. **Process Management:** Consider using process manager (systemd, launchd) for service management
4. **Backup Strategy:** Ensure regular database backups are occurring (existing `backup_dev_databases.sh` script)

### Medium-term Improvements
1. **Environment Separation:** Consider separating development and production environments
2. **Observability:** Implement structured logging and metrics collection
3. **Deployment Automation:** Use Kamal or Docker Compose for consistent deployments
4. **Secret Management:** Move from `.env` files to dedicated secret management

### Database Sync Specific
1. **Schedule Syncs:** Consider regular syncs if development data is valuable for local work
2. **Validation:** Add data validation after sync (row counts, checksums)
3. **Automation:** Integrate sync with existing backup scripts
4. **Rollback:** Ensure easy rollback to previous local database state

## Technical Details

### PostgreSQL Access
```bash
# Remote PostgreSQL path
/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql

# Local PostgreSQL path (assumed)
/opt/homebrew/opt/postgresql@16/bin/psql

# Database user
ericsmith66 (same as system user)
```

### SSH Configuration
```bash
# Connection string
ssh ericsmith66@192.168.4.253

# Port
22 (default)

# Authentication
SSH keys (confirmed working)
```

### Application Paths
```
/Users/ericsmith66/Development/nextgen-plaid/   # Application root
  ├── config/database.yml                       # Database configuration
  ├── .env                                      # Environment variables
  ├── log/development.log                       # Active log file
  └── script/backup_dev_databases.sh            # Existing backup script
```

## Conclusion

The remote instance is a fully functional development environment with active data. It is suitable as a source for database synchronization to local development environments. The planned sync approach using SSH and pg_dump is appropriate and should work without modification.

**Key Takeaway:** This is a development server, not a production deployment. Sync operations should target development databases, and users should be aware they are receiving development data that may include test records and partial data.

---

**Inspection Status:** Complete  
**Next Review:** March 16, 2026  
**Review Trigger:** Significant environment changes or deployment modifications