#!/usr/bin/env bash
#
# Copy Development Databases to Production (Same Server)
# Usage: bash scripts/copy-dev-to-prod-db.sh
#
# This script copies all nextgen-plaid development databases to production
# on the SAME server (192.168.4.253)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_PATH="/Users/ericsmith66/Development/nextgen-plaid"
BACKUP_DIR="/Users/ericsmith66/backups/nextgen-plaid"
PG_BIN="/opt/homebrew/bin"
PG_USER="nextgen_plaid"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Database pairs (source -> target)
declare -a DATABASES=(
    "nextgen_plaid_development:nextgen_plaid_production"
    "nextgen_plaid_development_queue:nextgen_plaid_production_queue"
    "nextgen_plaid_development_cache:nextgen_plaid_production_cache"
    "nextgen_plaid_development_cable:nextgen_plaid_production_cable"
)

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Copy Development → Production Databases${NC}"
echo -e "${BLUE}  Server: 192.168.4.253 (local)${NC}"
echo -e "${BLUE}  Timestamp: ${TIMESTAMP}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Function to check if command succeeded
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1"
        return 1
    fi
}

# Function to get database password
get_db_password() {
    # Try .env.production first (try both variable names)
    if [ -f "${APP_PATH}/.env.production" ]; then
        local pass=$(grep "^NEXTGEN_PLAID_DATABASE_PASSWORD=" "${APP_PATH}/.env.production" | cut -d '=' -f2 | tr -d '"' | tr -d "'")
        if [ -n "$pass" ]; then
            echo "$pass"
            return 0
        fi
        
        local pass=$(grep "^DATABASE_PASSWORD=" "${APP_PATH}/.env.production" | cut -d '=' -f2 | tr -d '"' | tr -d "'")
        if [ -n "$pass" ]; then
            echo "$pass"
            return 0
        fi
    fi
    
    # Try .env as fallback
    if [ -f "${APP_PATH}/.env" ]; then
        local pass=$(grep "^NEXTGEN_PLAID_DATABASE_PASSWORD=" "${APP_PATH}/.env" | cut -d '=' -f2 | tr -d '"' | tr -d "'")
        if [ -n "$pass" ]; then
            echo "$pass"
            return 0
        fi
        
        local pass=$(grep "^DATABASE_PASSWORD=" "${APP_PATH}/.env" | cut -d '=' -f2 | tr -d '"' | tr -d "'")
        if [ -n "$pass" ]; then
            echo "$pass"
            return 0
        fi
    fi
    
    # Try Keychain as last resort
    local pass=$(security find-generic-password -a 'nextgen-plaid' -s 'nextgen-plaid-DATABASE_PASSWORD' -w 2>/dev/null || echo "")
    if [ -n "$pass" ]; then
        echo "$pass"
        return 0
    fi
    
    echo ""
    return 1
}

# Step 1: Get database password
echo -e "${BLUE}→ Step 1: Getting database password...${NC}"
DB_PASS=$(get_db_password)
if [ -z "$DB_PASS" ]; then
    echo -e "${RED}✗ Could not find database password${NC}"
    echo -e "${YELLOW}  Searched: .env.production, .env, Keychain${NC}"
    exit 1
fi
check_status "Database password retrieved"
export PGPASSWORD="${DB_PASS}"
echo ""

# Step 2: Check PostgreSQL is running
echo -e "${BLUE}→ Step 2: Checking PostgreSQL...${NC}"
if ! ${PG_BIN}/psql -U ${PG_USER} -d postgres -c "SELECT 1" >/dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to PostgreSQL${NC}"
    echo -e "${YELLOW}  Is PostgreSQL running? Try: brew services start postgresql@16${NC}"
    exit 1
fi
check_status "PostgreSQL is running"
echo ""

# Step 3: Verify source databases exist and have data
echo -e "${BLUE}→ Step 3: Verifying source databases...${NC}"
for db_pair in "${DATABASES[@]}"; do
    SOURCE_DB="${db_pair%%:*}"
    
    # Check if database exists
    if ! ${PG_BIN}/psql -U ${PG_USER} -lqt | cut -d \| -f 1 | grep -qw ${SOURCE_DB}; then
        echo -e "${RED}✗ Source database does not exist: ${SOURCE_DB}${NC}"
        exit 1
    fi
    
    # Count tables
    TABLE_COUNT=$(${PG_BIN}/psql -U ${PG_USER} -d ${SOURCE_DB} -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null | xargs)
    
    echo -e "${GREEN}✓${NC} ${SOURCE_DB} (${TABLE_COUNT} tables)"
done
echo ""

# Step 4: Check if production app is running
echo -e "${BLUE}→ Step 4: Checking for running production processes...${NC}"
PROD_PIDS=$(ps aux | grep "[r]ails server -e production" | awk '{print $2}' || echo "")
if [ -n "$PROD_PIDS" ]; then
    echo -e "${YELLOW}⚠ Production Rails server is running (PIDs: ${PROD_PIDS})${NC}"
    echo -e "${YELLOW}  This should be stopped before copying databases${NC}"
    read -p "Stop production server now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for PID in $PROD_PIDS; do
            kill $PID 2>/dev/null || true
            echo -e "${GREEN}✓${NC} Stopped process $PID"
        done
        sleep 2
    else
        echo -e "${RED}✗ Cannot proceed with production server running${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} No production processes running"
fi
echo ""

# Step 5: Create backup directory
echo -e "${BLUE}→ Step 5: Preparing backup directory...${NC}"
mkdir -p "${BACKUP_DIR}"
check_status "Backup directory ready: ${BACKUP_DIR}"
echo ""

# Step 6: Backup current production databases (even if empty)
echo -e "${BLUE}→ Step 6: Backing up current production databases...${NC}"
for db_pair in "${DATABASES[@]}"; do
    TARGET_DB="${db_pair##*:}"
    BACKUP_FILE="${BACKUP_DIR}/${TARGET_DB}_${TIMESTAMP}.dump"
    
    # Check if database exists before backing up
    if ${PG_BIN}/psql -U ${PG_USER} -lqt | cut -d \| -f 1 | grep -qw ${TARGET_DB}; then
        ${PG_BIN}/pg_dump -U ${PG_USER} -Fc ${TARGET_DB} > "${BACKUP_FILE}" 2>/dev/null || true
        BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
        echo -e "${GREEN}✓${NC} Backed up ${TARGET_DB} (${BACKUP_SIZE})"
    else
        echo -e "${YELLOW}⚠${NC} ${TARGET_DB} does not exist (will be created)"
    fi
done
echo ""

# Step 7: Show what will be copied
echo -e "${BLUE}→ Step 7: Database copy plan:${NC}"
echo ""
for db_pair in "${DATABASES[@]}"; do
    SOURCE_DB="${db_pair%%:*}"
    TARGET_DB="${db_pair##*:}"
    
    # Get row counts (approximate)
    SOURCE_SIZE=$(${PG_BIN}/psql -U ${PG_USER} -d ${SOURCE_DB} -t -c "SELECT pg_size_pretty(pg_database_size('${SOURCE_DB}'))" 2>/dev/null | xargs || echo "unknown")
    
    if ${PG_BIN}/psql -U ${PG_USER} -lqt | cut -d \| -f 1 | grep -qw ${TARGET_DB}; then
        TARGET_SIZE=$(${PG_BIN}/psql -U ${PG_USER} -d ${TARGET_DB} -t -c "SELECT pg_size_pretty(pg_database_size('${TARGET_DB}'))" 2>/dev/null | xargs || echo "unknown")
    else
        TARGET_SIZE="(will be created)"
    fi
    
    echo -e "  ${YELLOW}${SOURCE_DB}${NC} (${SOURCE_SIZE})"
    echo -e "    ↓"
    echo -e "  ${GREEN}${TARGET_DB}${NC} (${TARGET_SIZE})"
    echo ""
done

# Final confirmation
echo -e "${RED}⚠ WARNING: This will OVERWRITE all data in production databases!${NC}"
echo -e "${YELLOW}  Backups have been created at: ${BACKUP_DIR}/${TIMESTAMP}_*${NC}"
echo ""
read -p "Continue with database copy? (type 'yes' to confirm): " -r
echo ""
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo -e "${YELLOW}Aborted by user${NC}"
    unset PGPASSWORD
    exit 0
fi

# Step 8: Kill any remaining connections to production databases
echo -e "${BLUE}→ Step 8: Terminating existing database connections...${NC}"
for db_pair in "${DATABASES[@]}"; do
    TARGET_DB="${db_pair##*:}"
    
    if ${PG_BIN}/psql -U ${PG_USER} -lqt | cut -d \| -f 1 | grep -qw ${TARGET_DB}; then
        ${PG_BIN}/psql -U ${PG_USER} -d postgres -c "
            SELECT pg_terminate_backend(pid) 
            FROM pg_stat_activity 
            WHERE datname = '${TARGET_DB}' 
              AND pid <> pg_backend_pid();
        " >/dev/null 2>&1 || true
        echo -e "${GREEN}✓${NC} Terminated connections to ${TARGET_DB}"
    fi
done
echo ""

# Step 9: Copy databases
echo -e "${BLUE}→ Step 9: Copying databases (this may take a few minutes)...${NC}"
echo ""

COPY_SUCCESS=true
for db_pair in "${DATABASES[@]}"; do
    SOURCE_DB="${db_pair%%:*}"
    TARGET_DB="${db_pair##*:}"
    
    echo -e "${BLUE}  Copying ${SOURCE_DB} → ${TARGET_DB}...${NC}"
    
    # Create target database if it doesn't exist
    if ! ${PG_BIN}/psql -U ${PG_USER} -lqt | cut -d \| -f 1 | grep -qw ${TARGET_DB}; then
        ${PG_BIN}/psql -U ${PG_USER} -d postgres -c "CREATE DATABASE ${TARGET_DB} OWNER ${PG_USER};" >/dev/null 2>&1
        echo -e "    ${GREEN}✓${NC} Created database ${TARGET_DB}"
    fi
    
    # Copy using pg_dump | pg_restore
    if ${PG_BIN}/pg_dump -U ${PG_USER} -Fc ${SOURCE_DB} | \
       ${PG_BIN}/pg_restore -U ${PG_USER} -d ${TARGET_DB} --clean --if-exists --no-owner --no-acl 2>&1 | \
       grep -v "^pg_restore: warning" | grep -v "^pg_restore: from TOC entry" >/dev/null; then
        # Some warnings are expected, check if data was actually copied
        TABLE_COUNT=$(${PG_BIN}/psql -U ${PG_USER} -d ${TARGET_DB} -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null | xargs)
        if [ "$TABLE_COUNT" -gt 0 ]; then
            echo -e "    ${GREEN}✓${NC} Copy successful (${TABLE_COUNT} tables)"
        else
            echo -e "    ${RED}✗${NC} Copy may have failed (0 tables in target)"
            COPY_SUCCESS=false
        fi
    else
        # Actually copy the data (the above was just error checking)
        ${PG_BIN}/pg_dump -U ${PG_USER} -Fc ${SOURCE_DB} | \
        ${PG_BIN}/pg_restore -U ${PG_USER} -d ${TARGET_DB} --clean --if-exists --no-owner --no-acl 2>/dev/null
        
        TABLE_COUNT=$(${PG_BIN}/psql -U ${PG_USER} -d ${TARGET_DB} -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null | xargs)
        if [ "$TABLE_COUNT" -gt 0 ]; then
            echo -e "    ${GREEN}✓${NC} Copy successful (${TABLE_COUNT} tables)"
        else
            echo -e "    ${RED}✗${NC} Copy failed (0 tables in target)"
            COPY_SUCCESS=false
        fi
    fi
    echo ""
done

# Clean up password from environment
unset PGPASSWORD

# Step 10: Verify copy with data counts
if [ "$COPY_SUCCESS" = true ]; then
    echo -e "${BLUE}→ Step 10: Verifying data copy...${NC}"
    
    # Use Rails to check data (requires rbenv)
    if [ -f "${APP_PATH}/.ruby-version" ]; then
        cd "${APP_PATH}"
        
        # Source rbenv
        export PATH="$HOME/.rbenv/shims:$PATH"
        if command -v rbenv >/dev/null 2>&1; then
            eval "$(rbenv init -)"
        fi
        
        # Get production data counts
        echo ""
        echo -e "${GREEN}Production Database Contents:${NC}"
        RAILS_ENV=production bundle exec rails runner "
          puts \"  Users: #{User.count}\"
          puts \"  Plaid Items: #{PlaidItem.count}\"
          puts \"  Accounts: #{Account.count}\"
          puts \"  Transactions: #{Transaction.count}\"
          puts \"  Holdings: #{Holding.count}\"
        " 2>/dev/null || echo -e "${YELLOW}  (Could not query via Rails - database may need migrations)${NC}"
    fi
    echo ""
fi

# Final summary
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
if [ "$COPY_SUCCESS" = true ]; then
    echo -e "${GREEN}✅ Database copy completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Backups created:${NC}"
    ls -lh "${BACKUP_DIR}"/*_${TIMESTAMP}.dump 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. Start production application:"
    echo -e "     ${YELLOW}cd ${APP_PATH}${NC}"
    echo -e "     ${YELLOW}source ~/.zprofile && eval \"\$(rbenv init -)\"${NC}"
    echo -e "     ${YELLOW}bundle exec rails server -e production -p 3000 &${NC}"
    echo ""
    echo -e "  2. Test health check:"
    echo -e "     ${YELLOW}curl http://localhost:3000/admin/health${NC}"
    echo ""
    echo -e "  3. Monitor logs:"
    echo -e "     ${YELLOW}tail -f ${APP_PATH}/log/production.log${NC}"
else
    echo -e "${RED}⚠ Database copy completed with errors${NC}"
    echo -e "${YELLOW}Check the output above for details${NC}"
    echo ""
    echo -e "${BLUE}To rollback:${NC}"
    echo -e "  ${YELLOW}bash scripts/restore-database.sh ${TIMESTAMP}${NC}"
fi
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
