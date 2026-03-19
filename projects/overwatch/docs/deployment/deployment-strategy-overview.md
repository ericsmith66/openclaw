# Multi-App Deployment Strategy Overview
**Version:** 1.0  
**Last Updated:** February 16, 2026  
**Target Environment:** Production Server (192.168.4.253)

## Executive Summary

This document outlines deployment strategies for running multiple Rails applications (NextGen Plaid and Eureka HomeKit) on a single production server with limited infrastructure. Two primary approaches are presented:

1. **Docker Compose Approach** (Recommended for simplicity)
2. **Kamal (MRSK) Approach** (Recommended for Rails-specific deployments)

## Environment Constraints

### Current Infrastructure
- **Production Server:** M3 Ultra macOS at 192.168.4.253
- **Network:** ATT Fiber → Ubiquiti UDM-SE → Cloudflare Tunnel
- **Public Domain:** `api.higroundsolution.com`
- **Team Size:** Small team with limited DevOps expertise
- **Requirements:** Simple, maintainable, low-overhead deployment

### Application Portfolio
| Application | Stack | Key Dependencies | External Access |
|-------------|-------|------------------|-----------------|
| NextGen Plaid | Rails 8, PostgreSQL, Redis, Solid Queue | Plaid API, Financial data | `plaid.api.higroundsolution.com` |
| Eureka HomeKit | Rails 8, PostgreSQL, Redis, HomeKit | HomeKit devices, mDNS | `homekit.api.higroundsolution.com` |

## Option 1: Docker Compose (Recommended)

### Architecture Diagram
```
Cloudflare Tunnel
       ↓
   [Production Server: 192.168.4.253]
       ↓
   +-----------------------------------+
   | Docker Compose Network            |
   |                                   |
   |  +-----------------------------+  |
   |  | NextGen Plaid Stack         |  |
   |  | - App (Port 3000)           |  |
   |  | - PostgreSQL (Port 5432)    |  |
   |  | - Redis (Port 6379)         |  |
   |  +-----------------------------+  |
   |                                   |
   |  +-----------------------------+  |
   |  | Eureka HomeKit Stack        |  |
   |  | - App (Port 3001)           |  |
   |  | - PostgreSQL (Port 5433)    |  |
   |  | - Redis (Port 6380)         |  |
   |  +-----------------------------+  |
   +-----------------------------------+
```

### Advantages
- **Simplicity:** Easy to understand and debug
- **Isolation:** Each app has its own database instance
- **Portability:** Easy to move to different servers
- **Resource Control:** Clear resource limits per service

### Disadvantages
- **Resource Overhead:** Separate database instances use more memory
- **Port Management:** Manual port mapping required
- **Orchestration:** Basic compared to more advanced tools

### Implementation Steps
1. **Setup Directory Structure:**
   ```bash
   /home/user/apps/
   ├── nextgen-plaid/
   │   ├── docker-compose.yml
   │   ├── .env
   │   └── init.sql
   └── eureka-homekit/
       ├── docker-compose.yml
       ├── .env
       └── init.sql
   ```

2. **Configure Cloudflare Tunnel:**
   ```
   plaid.api.higroundsolution.com → 192.168.4.253:3000
   homekit.api.higroundsolution.com → 192.168.4.253:3001
   ```

3. **Deploy Each Application:**
   - Follow individual deployment guides
   - Use `docker-compose up -d` for each app

### Resource Requirements
- **CPU:** 2-4 cores total
- **Memory:** 4GB per app (8GB total)
- **Storage:** 20GB per database (40GB total)
- **Network:** Minimal bandwidth required

## Option 2: Kamal (MRSK) Deployment

### Architecture Diagram
```
Cloudflare Tunnel
       ↓
   [Production Server: 192.168.4.253]
       ↓
   +-----------------------------------+
   | Kamal Deployment                  |
   |                                   |
   |  Shared Infrastructure:           |
   |  - PostgreSQL (Port 5432)         |
   |  - Redis (Port 6379)              |
   |                                   |
   |  +-----------------------------+  |
   |  | NextGen Plaid Container     |  |
   |  | (Traefik routing)           |  |
   |  +-----------------------------+  |
   |                                   |
   |  +-----------------------------+  |
   |  | Eureka HomeKit Container    |  |
   |  | (Traefik routing)           |  |
   |  +-----------------------------+  |
   +-----------------------------------+
```

### Advantages
- **Rails Optimized:** Built specifically for Rails deployments
- **Automatic SSL:** Traefik handles SSL certificates
- **Zero-Downtime:** Built-in zero-downtime deployment
- **Shared Infrastructure:** Can share databases between apps

### Disadvantages
- **Learning Curve:** Requires understanding of Kamal concepts
- **Complexity:** More moving parts (Traefik, accessories)
- **Resource Sharing:** Potential for interference between apps

### Implementation Steps
1. **Install Kamal on Development Machine:**
   ```bash
   gem install kamal
   ```

2. **Configure Kamal for Each Application:**
   ```yaml
   # config/deploy.yml (NextGen Plaid)
   service: nextgen-plaid
   image: your-registry/nextgen-plaid
   servers:
     - 192.168.4.253
   registry:
     username: your-username
     password: <%= ENV["REGISTRY_PASSWORD"] %>
   env:
     clear:
       RAILS_ENV: production
     secret:
       - RAILS_MASTER_KEY
       - PLAID_CLIENT_ID
   accessories:
     postgres:
       image: postgres:16-alpine
       host: 192.168.4.253
       port: 5432
       env:
         clear:
           POSTGRES_DB: nextgen_plaid_production
         secret:
           - POSTGRES_PASSWORD
       volumes:
         - /var/lib/postgresql/data:/var/lib/postgresql/data
   ```

3. **Deploy Applications:**
   ```bash
   # NextGen Plaid
   cd /path/to/nextgen-plaid
   kamal setup
   kamal deploy

   # Eureka HomeKit
   cd /path/to/eureka-homekit
   kamal setup
   kamal deploy
   ```

## Option 3: Hybrid Approach

### Architecture
```
Cloudflare Tunnel
       ↓
   [Production Server: 192.168.4.253]
       ↓
   +-----------------------------------+
   | Shared Services (Docker Compose)  |
   | - PostgreSQL (multi-database)     |
   | - Redis (multiple databases)      |
   |                                   |
   |  +-----------------------------+  |
   |  | NextGen Plaid (Docker)      |  |
   |  +-----------------------------+  |
   |                                   |
   |  +-----------------------------+  |
   |  | Eureka HomeKit (Docker)     |  |
   |  +-----------------------------+  |
   +-----------------------------------+
```

### Advantages
- **Resource Efficient:** Shared database instance
- **Simplified Management:** Single PostgreSQL/Redis to maintain
- **Isolation:** Application containers remain separate

### Implementation
1. **Create Shared Infrastructure:**
   ```yaml
   # shared-services/docker-compose.yml
   version: '3.8'
   services:
     postgres:
       image: postgres:16-alpine
       environment:
         POSTGRES_USER: postgres
         POSTGRES_PASSWORD: ${SHARED_POSTGRES_PASSWORD}
       volumes:
         - postgres_data:/var/lib/postgresql/data
         - ./init.sql:/docker-entrypoint-initdb.d/init.sql
       ports:
         - "5432:5432"
     
     redis:
       image: redis:7-alpine
       command: redis-server --appendonly yes
       volumes:
         - redis_data:/data
       ports:
         - "6379:6379"
   ```

2. **Application Docker Compose Files:** Connect to shared services
   ```yaml
   # nextgen-plaid/docker-compose.yml
   services:
     app:
       # ...
       environment:
         DATABASE_URL: postgres://postgres:${SHARED_POSTGRES_PASSWORD}@192.168.4.253:5432/nextgen_plaid_production
         REDIS_URL: redis://192.168.4.253:6379/0
   ```

## Recommendation

### For Small Teams Starting Out: **Docker Compose (Option 1)**
- **Why:** Lowest learning curve, clear separation, easy debugging
- **When to choose:** Team new to DevOps, need quick deployment, limited time for setup
- **Implementation time:** 2-4 hours per application

### For Rails-Focused Teams: **Kamal (Option 2)**
- **Why:** Rails-optimized, automatic SSL, better deployment experience
- **When to choose:** Team familiar with Rails ecosystem, need automatic SSL, plan to scale
- **Implementation time:** 4-8 hours per application

### For Resource-Constrained Environments: **Hybrid (Option 3)**
- **Why:** Most resource-efficient, single point of management
- **When to choose:** Limited server resources, experienced with Docker networking
- **Implementation time:** 3-6 hours total

## Security Considerations

### All Approaches
1. **Cloudflare Tunnel:** Provides DDoS protection and SSL termination
2. **Secret Management:** Use `.env` files or Docker secrets (not in version control)
3. **Network Isolation:** Ensure containers can't access each other unnecessarily
4. **Regular Updates:** Update base images and dependencies regularly

### Approach-Specific Security
- **Docker Compose:** Use separate networks for each app stack
- **Kamal:** Leverage Traefik security features and automatic certificate rotation
- **Hybrid:** Implement network policies between shared services and apps

## Monitoring Strategy

### Basic Monitoring (All Approaches)
```bash
# Health checks
curl https://plaid.api.higroundsolution.com/health
curl https://homekit.api.higroundsolution.com/health

# Container status
docker ps
docker stats

# Log aggregation
docker-compose logs -f
```

### Advanced Monitoring (Recommended)
- **Loki/Promtail:** Centralized logging
- **Prometheus:** Metrics collection
- **Grafana:** Dashboards and alerting
- **Uptime Kuma:** Simple uptime monitoring

## Backup Strategy

### Database Backups
```bash
# Individual approach
docker-compose exec -T postgres pg_dump -U user database > backup.sql

# Shared approach
pg_dump -h 192.168.4.253 -U postgres nextgen_plaid_production > backup.sql

# Automated with cron
0 2 * * * /path/to/backup-script.sh
```

### Configuration Backups
- **Docker Compose files:** Version controlled in repository
- **Environment variables:** Securely backed up (not in version control)
- **SSL certificates:** Cloudflare manages, but keep local backups

## Cost Analysis

### Infrastructure Costs
| Resource | Docker Compose | Kamal | Hybrid |
|----------|----------------|-------|--------|
| Server | Existing M3 Ultra | Existing M3 Ultra | Existing M3 Ultra |
| Database | 2 instances | 1-2 instances | 1 instance |
| Memory | Higher | Medium | Lower |
| Storage | 2x databases | 1-2x databases | 1x database |
| Management | Low | Medium | Medium |

### Time Costs
| Task | Docker Compose | Kamal | Hybrid |
|------|----------------|-------|--------|
| Initial setup | 4-8 hours | 8-12 hours | 6-10 hours |
| Ongoing maintenance | 2-4 hours/month | 1-2 hours/month | 2-3 hours/month |
| Debugging | Easy | Moderate | Moderate |

## Migration Path

### Start Simple, Evolve as Needed
1. **Phase 1:** Docker Compose for both apps (quick start)
2. **Phase 2:** Implement centralized logging and monitoring
3. **Phase 3:** Evaluate Kamal for simplified deployments
4. **Phase 4:** Consider Kubernetes if scaling beyond single server

### When to Re-evaluate
- Team grows beyond 3 developers
- Need to deploy more than 5 applications
- Requirements for high availability (multi-server)
- Need advanced scaling features

## Success Criteria

### Minimum Viable Deployment
- [ ] Both applications accessible via Cloudflare Tunnel
- [ ] Database persistence across container restarts
- [ ] Basic health monitoring in place
- [ ] Backup strategy implemented and tested
- [ ] Deployment documented and repeatable

### Enhanced Deployment
- [ ] Zero-downtime deployments
- [ ] Automated SSL certificate management
- [ ] Centralized logging
- [ ] Performance monitoring
- [ ] Automated backups with verification

## Next Steps

### Immediate Actions (Week 1)
1. Choose deployment approach (recommend Docker Compose)
2. Set up production server with Docker
3. Deploy NextGen Plaid using chosen approach
4. Test end-to-end functionality

### Week 2
1. Deploy Eureka HomeKit
2. Implement basic monitoring
3. Set up backup procedures
4. Document deployment process

### Week 3-4
1. Review deployment experience
2. Consider improvements (Kamal, centralized logging)
3. Plan for future applications
4. Train team members on deployment process

---

**Document Status:** Approved  
**Next Review:** March 16, 2026  
**Owner:** DevOps Engineer