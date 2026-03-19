# NextGen Plaid Deployment Guide
**Version:** 1.0 **[OBSOLETE - See Note Below]**  
**Last Updated:** February 16, 2026  
**Target Environment:** Production Server (192.168.4.253)

---

## ⚠️ **IMPORTANT: THIS DOCUMENT IS OBSOLETE**

**This Docker Compose approach has been replaced with a native macOS deployment using LaunchAgents.**

**For current deployment documentation, see:**
- **Authoritative source:** `/Users/ericsmith66/Development/nextgen-plaid/RUNBOOK.md` (v2.0)
- **Team guide:** `docs/team-guides/NEXTGEN-PLAID-DEPLOYMENT-TEAM-GUIDE.md` (v2.0)

**Key Changes:**
- ❌ No longer using Docker Compose
- ✅ Native macOS deployment with Foreman + LaunchAgents
- ✅ Rails 8.1.1 (was 7.x)
- ✅ SmartProxy LLM gateway added (port 3001)
- ✅ Secrets via `.env.production` files (not Keychain)
- ✅ Health endpoint at `/health?token=` implemented

**This document is retained for historical reference only.**

---

## Overview (Original - February 16, 2026)

This document provides a simple, maintainable deployment strategy for NextGen Plaid (Ruby on Rails application) suitable for small teams with limited infrastructure. The approach uses Docker Compose for containerization and Cloudflare Tunnel for secure external access.

## Prerequisites

### Production Server Requirements
- **Hardware:** M3 Ultra macOS (192.168.4.253)
- **Software:** Docker Engine & Docker Compose
- **Storage:** Minimum 20GB free disk space
- **Memory:** Minimum 8GB RAM (16GB recommended)
- **Network:** Access to ATT Fiber internet, Cloudflare Tunnel configured

### Required Tools on Production Server
```bash
# Install Docker (if not present)
brew install --cask docker

# Verify installation
docker --version
docker-compose --version
```

### Cloudflare Tunnel Configuration
Ensure Cloudflare Tunnel is configured to route traffic to the production server. Recommended configuration:
- **Subdomain:** `plaid.api.higroundsolution.com` → `192.168.4.253:3000`
- **Alternative:** Path-based routing `api.higroundsolution.com/plaid/*` → `192.168.4.253:3000`

## Architecture

```
Cloudflare Tunnel → Production Server (192.168.4.253)
                         ↓
                 Docker Compose Network
                         ↓
    +-----------------------------------------------+
    |  NextGen Plaid Container (Port 3000)          |
    |  - Rails application                          |
    |  - Solid Queue worker                         |
    |                                               |
    |  PostgreSQL Container (Port 5432)             |
    |  - nextgen_plaid_production                   |
    |  - nextgen_plaid_production_queue             |
    |  - nextgen_plaid_production_cache             |
    |  - nextgen_plaid_production_cable             |
    +-----------------------------------------------+
```

## Deployment Setup

### 1. Project Structure on Production Server
Create a dedicated directory for NextGen Plaid deployment:
```bash
ssh user@192.168.4.253
mkdir -p ~/apps/nextgen-plaid
cd ~/apps/nextgen-plaid
```

### 2. Docker Compose Configuration
Create `docker-compose.yml`:
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: nextgen-plaid-postgres
    environment:
      POSTGRES_USER: nextgen_plaid
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
      POSTGRES_DB: nextgen_plaid_production
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nextgen_plaid"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nextgen-plaid-app
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      RAILS_ENV: production
      DATABASE_URL: postgres://nextgen_plaid:${POSTGRES_PASSWORD}@postgres:5432/nextgen_plaid_production
      REDIS_URL: redis://redis:6379/0
      PLAID_CLIENT_ID: ${PLAID_CLIENT_ID}
      PLAID_SECRET: ${PLAID_SECRET}
      PLAID_ENV: ${PLAID_ENV:-production}
      ENCRYPTION_KEY: ${ENCRYPTION_KEY}
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      NEXTGEN_PLAID_DATABASE_PASSWORD: ${POSTGRES_PASSWORD}
      # Additional environment variables as needed
    ports:
      - "3000:80"
    volumes:
      - ./storage:/rails/storage
      - ./log:/rails/log
      - ./tmp:/rails/tmp
    restart: unless-stopped
    command: ./bin/thrust ./bin/rails server

  redis:
    image: redis:7-alpine
    container_name: nextgen-plaid-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

  solid_queue:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nextgen-plaid-queue
    depends_on:
      - postgres
      - redis
    environment:
      RAILS_ENV: production
      DATABASE_URL: postgres://nextgen_plaid:${POSTGRES_PASSWORD}@postgres:5432/nextgen_plaid_production_queue
      REDIS_URL: redis://redis:6379/0
      # ... other environment variables
    volumes:
      - ./storage:/rails/storage
      - ./log:/rails/log
      - ./tmp:/rails/tmp
    restart: unless-stopped
    command: ./bin/rails solid_queue:start

volumes:
  postgres_data:
  redis_data:
```

### 3. Environment Configuration
Create `.env` file (DO NOT commit to version control):
```bash
# Database
POSTGRES_PASSWORD=strong_password_here

# Rails
RAILS_MASTER_KEY=$(cat config/master.key)
ENCRYPTION_KEY=64_char_hex_string_from_openssl_rand_hex_32

# Plaid API
PLAID_CLIENT_ID=your_client_id
PLAID_SECRET=your_secret
PLAID_ENV=production
PLAID_REDIRECT_URI=https://plaid.api.higroundsolution.com/plaid_oauth/callback

# Application
OWNER_EMAIL=ericsmith66@me.com
NEXTGEN_PLAID_DATABASE_PASSWORD=${POSTGRES_PASSWORD}
```

### 4. Database Initialization Script
Create `init.sql` for multi-database setup:
```sql
CREATE DATABASE nextgen_plaid_production_queue;
CREATE DATABASE nextgen_plaid_production_cache;
CREATE DATABASE nextgen_plaid_production_cable;
GRANT ALL PRIVILEGES ON DATABASE nextgen_plaid_production_queue TO nextgen_plaid;
GRANT ALL PRIVILEGES ON DATABASE nextgen_plaid_production_cache TO nextgen_plaid;
GRANT ALL PRIVILEGES ON DATABASE nextgen_plaid_production_cable TO nextgen_plaid;
```

## Deployment Process

### Initial Deployment
```bash
# 1. Clone the repository
git clone https://github.com/ericsmith66/nextgen-plaid.git .
# or copy project files to the server

# 2. Set up environment
cp .env.example .env
# Edit .env with production values

# 3. Build and start containers
docker-compose build
docker-compose up -d

# 4. Run database migrations
docker-compose exec app bin/rails db:migrate

# 5. Run database setup for shards
docker-compose exec app bin/rails db:migrate:cache
docker-compose exec app bin/rails db:migrate:queue
docker-compose exec app bin/rails db:migrate:cable

# 6. Seed production data (if needed)
docker-compose exec app bin/rails prod_setup:seed

# 7. Verify application is running
curl http://localhost:3000/health
```

### Update Deployment (Zero-Downtime)
```bash
# 1. Pull latest changes
git pull origin main

# 2. Rebuild containers
docker-compose build

# 3. Run migrations
docker-compose exec app bin/rails db:migrate

# 4. Restart containers with zero-downtime strategy
docker-compose up -d --scale app=2 --no-recreate
# Wait for new container to be healthy
sleep 30
docker-compose up -d --scale app=1 --no-recreate

# 5. Verify deployment
docker-compose logs --tail=50 app
```

## Monitoring & Maintenance

### Health Checks
```bash
# Application health
curl http://localhost:3000/health

# Database connection
docker-compose exec postgres pg_isready -U nextgen_plaid

# Queue health
docker-compose exec solid_queue bin/rails runner "puts SolidQueue::Job.count"
```

### Logs
```bash
# View application logs
docker-compose logs -f app

# View database logs
docker-compose logs -f postgres

# View queue logs
docker-compose logs -f solid_queue
```

### Backup Strategy
```bash
# Database backup script (cron job)
#!/bin/bash
BACKUP_DIR="/backups/nextgen-plaid"
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec -T postgres pg_dump -U nextgen_plaid nextgen_plaid_production > $BACKUP_DIR/db_$DATE.sql
# Keep last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
```

### Automated Backups with Cron
Add to crontab (`crontab -e`):
```cron
0 2 * * * /home/user/apps/nextgen-plaid/backup.sh
```

## Troubleshooting

### Common Issues

#### 1. Database Connection Errors
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check logs
docker-compose logs postgres

# Test connection manually
docker-compose exec postgres psql -U nextgen_plaid -d nextgen_plaid_production
```

#### 2. Application Won't Start
```bash
# Check Rails logs
docker-compose logs app

# Check environment variables
docker-compose exec app env | grep RAILS

# Test database connection from app container
docker-compose exec app bin/rails runner "ActiveRecord::Base.connection.execute('SELECT 1')"
```

#### 3. Queue Jobs Not Processing
```bash
# Check queue worker status
docker-compose ps solid_queue

# View queue logs
docker-compose logs solid_queue

# Check job count
docker-compose exec app bin/rails runner "puts SolidQueue::Job.where(finished_at: nil).count"
```

### Recovery Procedures

#### Database Recovery
```bash
# Restore from latest backup
docker-compose exec -T postgres psql -U nextgen_plaid nextgen_plaid_production < /backups/latest.sql
```

#### Application Rollback
```bash
# Revert to previous Git commit
git log --oneline
git checkout <previous_commit_hash>
docker-compose build
docker-compose up -d
```

## Security Considerations

### 1. Secrets Management
- Store `.env` file securely (not in version control)
- Consider using Docker Secrets or HashiCorp Vault for production
- Rotate encryption keys periodically

### 2. Network Security
- Cloudflare Tunnel provides DDoS protection and SSL termination
- No direct internet exposure of containers
- Internal Docker network isolation

### 3. Container Security
- Regular updates of base images
- Non-root user execution (already configured in Dockerfile)
- Regular vulnerability scanning

## Performance Optimization

### Resource Limits
Add to `docker-compose.yml`:
```yaml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
    # ... other config
```

### Database Optimization
```bash
# Regular vacuum and analyze
docker-compose exec postgres vacuumdb -U nextgen_plaid -d nextgen_plaid_production
```

## Cost Considerations

### Infrastructure Costs
- **Server:** Existing M3 Ultra (no additional cost)
- **Cloudflare Tunnel:** Free tier sufficient
- **Domain:** Existing higroundsolution.com
- **Plaid API:** Production pricing based on usage

### Maintenance Overhead
- **Daily:** Check logs, verify backups
- **Weekly:** Review performance metrics
- **Monthly:** Apply security updates, rotate secrets

## Success Metrics

### Deployment Success Criteria
- [ ] Application responds to health checks
- [ ] Database migrations complete without errors
- [ ] Plaid API connectivity verified
- [ ] Background jobs processing
- [ ] Cloudflare Tunnel routing correctly

### Monitoring Checklist
- [ ] Health endpoint monitoring configured
- [ ] Error logging to centralized location
- [ ] Backup success notifications
- [ ] Performance metrics collection

## Support & Escalation

### Primary Contact
- **DevOps Engineer:** [Name/Email]
- **Application Owner:** Eric Smith (ericsmith66@me.com)

### Escalation Path
1. Check application logs and restart if necessary
2. Contact DevOps engineer for infrastructure issues
3. Contact application owner for business logic issues

---

**Document Status:** Approved  
**Next Review:** March 16, 2026  
**Review Frequency:** Quarterly or after significant changes