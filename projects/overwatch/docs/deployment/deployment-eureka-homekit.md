# Eureka HomeKit Deployment Guide
**Version:** 1.0  
**Last Updated:** February 16, 2026  
**Target Environment:** Production Server (192.168.4.253)

## Overview

This document provides a simple, maintainable deployment strategy for Eureka HomeKit (Ruby on Rails application with HomeKit integration) suitable for small teams with limited infrastructure. The approach uses Docker Compose for containerization and Cloudflare Tunnel for secure external access.

## Prerequisites

### Production Server Requirements
- **Hardware:** M3 Ultra macOS (192.168.4.253)
- **Software:** Docker Engine & Docker Compose
- **Storage:** Minimum 20GB free disk space
- **Memory:** Minimum 8GB RAM (16GB recommended)
- **Network:** Access to ATT Fiber internet, Cloudflare Tunnel configured
- **HomeKit Requirements:** Local network access for HomeKit device discovery

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
- **Subdomain:** `homekit.api.higroundsolution.com` → `192.168.4.253:3001`
- **Alternative:** Path-based routing `api.higroundsolution.com/homekit/*` → `192.168.4.253:3001`

**Note:** HomeKit requires local network access. Cloudflare Tunnel should only be used for administrative web interface, not for HomeKit device communication.

## Architecture

```
Cloudflare Tunnel → Production Server (192.168.4.253)
                         ↓
                 Docker Compose Network
                         ↓
    +-----------------------------------------------+
    |  Eureka HomeKit Container (Port 3001)         |
    |  - Rails application                          |
    |  - HomeKit bridge service                     |
    |  - Node.js for asset compilation              |
    |                                               |
    |  PostgreSQL Container (Port 5433)             |
    |  - eureka_homekit_production                  |
    |  - eureka_homekit_production_cache            |
    |  - eureka_homekit_production_queue            |
    |                                               |
    |  Redis Container (Port 6380)                  |
    +-----------------------------------------------+
```

**Important:** HomeKit integration requires the container to run with `network_mode: host` or specific host networking to discover local HomeKit devices.

## Deployment Setup

### 1. Project Structure on Production Server
Create a dedicated directory for Eureka HomeKit deployment:
```bash
ssh user@192.168.4.253
mkdir -p ~/apps/eureka-homekit
cd ~/apps/eureka-homekit
```

### 2. Docker Compose Configuration
Create `docker-compose.yml`:
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: eureka-homekit-postgres
    environment:
      POSTGRES_USER: eureka_homekit
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
      POSTGRES_DB: eureka_homekit_production
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5433:5432"  # Different port to avoid conflict with other apps
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U eureka_homekit"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: eureka-homekit-redis
    ports:
      - "6380:6379"  # Different port to avoid conflict
    volumes:
      - redis_data:/data
    restart: unless-stopped

  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: eureka-homekit-app
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    environment:
      RAILS_ENV: production
      DATABASE_URL: postgres://eureka_homekit:${POSTGRES_PASSWORD}@postgres:5432/eureka_homekit_production
      REDIS_URL: redis://redis:6379/0
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      EUREKA_HOMEKIT_DATABASE_PASSWORD: ${POSTGRES_PASSWORD}
      # HomeKit-specific environment variables
      HOMEKIT_BRIDGE_NAME: ${HOMEKIT_BRIDGE_NAME:-EurekaHome}
      HOMEKIT_PIN: ${HOMEKIT_PIN:-031-45-154}
      # Additional environment variables as needed
    ports:
      - "3001:80"
    volumes:
      - ./storage:/rails/storage
      - ./log:/rails/log
      - ./tmp:/rails/tmp
      # For HomeKit device discovery (optional, may need host networking)
      - /var/run/dbus:/var/run/dbus:ro
    # Consider network_mode: host for HomeKit discovery
    # network_mode: host
    restart: unless-stopped
    command: ./bin/thrust ./bin/rails server

  queue:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: eureka-homekit-queue
    depends_on:
      - postgres
      - redis
    environment:
      RAILS_ENV: production
      DATABASE_URL: postgres://eureka_homekit:${POSTGRES_PASSWORD}@postgres:5432/eureka_homekit_production_queue
      REDIS_URL: redis://redis:6379/0
      # ... other environment variables
    volumes:
      - ./storage:/rails/storage
      - ./log:/rails/log
      - ./tmp:/rails/tmp
    restart: unless-stopped
    command: ./bin/rails que:work

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

# HomeKit Configuration
HOMEKIT_BRIDGE_NAME=EurekaHome
HOMEKIT_PIN=031-45-154

# Application
EUREKA_HOMEKIT_DATABASE_PASSWORD=${POSTGRES_PASSWORD}

# Optional: External services
# SMTP settings for email notifications
# ACTION_CABLE_URL for WebSocket connections
```

### 4. Database Initialization Script
Create `init.sql` for multi-database setup:
```sql
CREATE DATABASE eureka_homekit_production_cache;
CREATE DATABASE eureka_homekit_production_queue;
GRANT ALL PRIVILEGES ON DATABASE eureka_homekit_production_cache TO eureka_homekit;
GRANT ALL PRIVILEGES ON DATABASE eureka_homekit_production_queue TO eureka_homekit;
```

### 5. HomeKit Networking Considerations
For HomeKit device discovery, you may need to use host networking or additional configuration:

**Option A: Host Networking** (Simpler for discovery)
```yaml
app:
  network_mode: host
  # Remove ports mapping when using host networking
  # ports:
  #   - "3001:80"
```

**Option B: Docker Network with mDNS**
```yaml
# Create a custom network with host-like discovery
networks:
  homekit:
    driver: bridge
    enable_ipv6: false
    ipam:
      config:
        - subnet: 172.20.0.0/16

services:
  app:
    networks:
      - homekit
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

## Deployment Process

### Initial Deployment
```bash
# 1. Clone the repository
git clone https://github.com/ericsmith66/eureka-homekit.git .
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

# 6. Precompile assets (if not done in Dockerfile)
docker-compose exec app bin/rails assets:precompile

# 7. Set up HomeKit bridge (if applicable)
docker-compose exec app bin/rails homekit:setup

# 8. Verify application is running
curl http://localhost:3001/health
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

## HomeKit-Specific Configuration

### 1. HomeKit Bridge Setup
```bash
# Generate HomeKit setup code if not set
docker-compose exec app bin/rails runner "puts 'HomeKit PIN: ' + ENV['HOMEKIT_PIN']"

# Check HomeKit accessory status
docker-compose exec app bin/rails runner "Homekit::Accessory.all.each { |a| puts a.name }"
```

### 2. Device Discovery
Ensure the container can access the local network for mDNS discovery:
```bash
# Test mDNS from within container
docker-compose exec app avahi-browse -a

# If mDNS not working, consider using host networking
```

### 3. HomeKit Pairing
1. Open Home app on iOS device
2. Tap "+" to add accessory
3. Scan QR code or enter setup code (from `HOMEKIT_PIN`)
4. Follow pairing instructions

## Monitoring & Maintenance

### Health Checks
```bash
# Application health
curl http://localhost:3001/health

# Database connection
docker-compose exec postgres pg_isready -U eureka_homekit

# Redis connection
docker-compose exec redis redis-cli ping

# HomeKit bridge status
docker-compose exec app bin/rails runner "puts Homekit::Bridge.running?"
```

### Logs
```bash
# View application logs
docker-compose logs -f app

# View HomeKit-specific logs
docker-compose exec app tail -f log/homekit.log

# View database logs
docker-compose logs -f postgres

# View queue logs
docker-compose logs -f queue
```

### Backup Strategy
```bash
# Database backup script (cron job)
#!/bin/bash
BACKUP_DIR="/backups/eureka-homekit"
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec -T postgres pg_dump -U eureka_homekit eureka_homekit_production > $BACKUP_DIR/db_$DATE.sql
# Keep last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
```

### Automated Backups with Cron
Add to crontab (`crontab -e`):
```cron
0 3 * * * /home/user/apps/eureka-homekit/backup.sh
```

## Troubleshooting

### Common Issues

#### 1. HomeKit Device Discovery Failures
```bash
# Check network mode
docker inspect eureka-homekit-app --format='{{.HostConfig.NetworkMode}}'

# Test mDNS from host
avahi-browse -a

# Consider using host networking
# Stop containers, update docker-compose.yml with network_mode: host, restart
```

#### 2. Database Connection Errors
```bash
# Check if PostgreSQL is running on correct port
docker-compose ps postgres
netstat -an | grep 5433

# Check logs
docker-compose logs postgres

# Test connection manually
docker-compose exec postgres psql -U eureka_homekit -d eureka_homekit_production
```

#### 3. Asset Compilation Failures
```bash
# Check Node.js installation in container
docker-compose exec app node --version
docker-compose exec app npm --version

# Manually precompile assets
docker-compose exec app bin/rails assets:precompile RAILS_ENV=production
```

#### 4. HomeKit Pairing Issues
```bash
# Reset HomeKit pairing
docker-compose exec app rm -f config/homekit/*.json

# Restart app and re-pair
docker-compose restart app
```

### Recovery Procedures

#### Database Recovery
```bash
# Restore from latest backup
docker-compose exec -T postgres psql -U eureka_homekit eureka_homekit_production < /backups/latest.sql
```

#### HomeKit Bridge Reset
```bash
# Remove pairing information
docker-compose exec app rm -rf config/homekit

# Restart application
docker-compose restart app

# Re-pair with Home app using setup code
```

## Security Considerations

### 1. HomeKit Security
- HomeKit uses end-to-end encryption
- Setup code should be kept secure
- Regular review of paired devices

### 2. Network Security
- Cloudflare Tunnel for web interface only
- HomeKit communication stays on local network
- Firewall rules to restrict external access to HomeKit ports

### 3. Container Security
- Regular updates of base images
- Non-root user execution
- Vulnerability scanning

## Performance Optimization

### Resource Limits
Add to `docker-compose.yml`:
```yaml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 1.5G
          cpus: '1.0'
    # ... other config
```

### HomeKit Performance
```bash
# Limit number of accessories if experiencing slowdowns
# Consider splitting into multiple bridges for large setups
```

## Cost Considerations

### Infrastructure Costs
- **Server:** Existing M3 Ultra (no additional cost)
- **Cloudflare Tunnel:** Free tier sufficient
- **Domain:** Existing higroundsolution.com
- **HomeKit:** No additional costs

### Maintenance Overhead
- **Daily:** Check HomeKit device connectivity
- **Weekly:** Review logs, verify backups
- **Monthly:** Apply security updates

## Success Metrics

### Deployment Success Criteria
- [ ] Application responds to health checks
- [ ] Database migrations complete without errors
- [ ] HomeKit bridge running and discoverable
- [ ] Local device discovery working
- [ ] Cloudflare Tunnel routing correctly

### Monitoring Checklist
- [ ] Health endpoint monitoring configured
- [ ] HomeKit bridge status monitoring
- [ ] Error logging to centralized location
- [ ] Backup success notifications

## Support & Escalation

### Primary Contact
- **DevOps Engineer:** [Name/Email]
- **Application Owner:** Eric Smith (ericsmith66@me.com)

### Escalation Path
1. Check application logs and restart if necessary
2. Verify HomeKit network configuration
3. Contact DevOps engineer for infrastructure issues
4. Contact application owner for HomeKit-specific issues

---

**Document Status:** Approved  
**Next Review:** March 16, 2026  
**Review Frequency:** Quarterly or after significant changes