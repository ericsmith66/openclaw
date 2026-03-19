#!/usr/bin/env bash
#
# Database Backup Script for nextgen-plaid
# Purpose: Create timestamped backups of all production databases
# Usage: ./scripts/backup-database.sh [--retention-days=30]
#
# Exit Codes:
#   0 - Success (all backups created and validated)
#   1 - Failure (one or more backups failed)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="${HOME}/backups/nextgen-plaid"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS="${1:-30}" # Default 30 days retention
PG_DUMP="/opt/homebrew/opt/postgresql@16/bin/pg_dump"

# Databases to backup
DATABASES=(
    "nextgen_plaid_production"
    "nextgen_plaid_production_queue"
    "nextgen_plaid_production_cable"
    "nextgen_plaid_production_cache"
)

# Track success/failure
BACKUP_SUCCESS=0
BACKUP_FAILED=0
FAILED_DBS=()

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Database Backup - nextgen-plaid${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Timestamp: ${TIMESTAMP}${NC}"
echo -e "${BLUE}  Retention: ${RETENTION_DAYS} days${NC}"
echo -e "${BLUE}  Location:  ${BACKUP_DIR}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Verify PostgreSQL is accessible
echo -e "${YELLOW}→ Verifying PostgreSQL connectivity...${NC}"
if ! "${PG_DUMP}" --version > /dev/null 2>&1; then
    echo -e "${RED}✗ PostgreSQL pg_dump not found at ${PG_DUMP}${NC}"
    exit 1
fi
echo -e "${GREEN}✓ PostgreSQL tools available${NC}"
echo ""

# Check disk space
echo -e "${YELLOW}→ Checking available disk space...${NC}"
AVAILABLE_SPACE=$(df -h "${BACKUP_DIR}" | tail -1 | awk '{print $4}')
echo -e "${GREEN}✓ Available space: ${AVAILABLE_SPACE}${NC}"
echo ""

# Backup each database
echo -e "${BLUE}Starting backup of ${#DATABASES[@]} databases...${NC}"
echo ""

for DB in "${DATABASES[@]}"; do
    BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}_${DB}.dump"
    
    echo -e "${YELLOW}→ Backing up ${DB}...${NC}"
    
    # Perform backup
    if "${PG_DUMP}" --format=custom --no-owner --no-acl --verbose \
        --file="${BACKUP_FILE}" "${DB}" 2>&1 | grep -q "completed"; then
        
        # Validate backup file
        if [[ -f "${BACKUP_FILE}" ]] && [[ -s "${BACKUP_FILE}" ]]; then
            FILE_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
            echo -e "${GREEN}✓ Backup successful: ${DB}${NC}"
            echo -e "${GREEN}  → File: $(basename "${BACKUP_FILE}")${NC}"
            echo -e "${GREEN}  → Size: ${FILE_SIZE}${NC}"
            ((BACKUP_SUCCESS++))
        else
            echo -e "${RED}✗ Backup file validation failed: ${DB}${NC}"
            echo -e "${RED}  → File is missing or empty${NC}"
            ((BACKUP_FAILED++))
            FAILED_DBS+=("${DB}")
        fi
    else
        echo -e "${RED}✗ Backup failed: ${DB}${NC}"
        ((BACKUP_FAILED++))
        FAILED_DBS+=("${DB}")
    fi
    echo ""
done

# Cleanup old backups (retention policy)
echo -e "${YELLOW}→ Cleaning up backups older than ${RETENTION_DAYS} days...${NC}"
DELETED_COUNT=0
while IFS= read -r old_file; do
    rm -f "${old_file}"
    ((DELETED_COUNT++))
done < <(find "${BACKUP_DIR}" -name "*.dump" -type f -mtime "+${RETENTION_DAYS}")

if [[ ${DELETED_COUNT} -gt 0 ]]; then
    echo -e "${GREEN}✓ Deleted ${DELETED_COUNT} old backup(s)${NC}"
else
    echo -e "${GREEN}✓ No old backups to delete${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Backup Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}✓${NC} Successful: ${BACKUP_SUCCESS}/${#DATABASES[@]}"
echo -e "  ${RED}✗${NC} Failed:     ${BACKUP_FAILED}/${#DATABASES[@]}"

if [[ ${BACKUP_FAILED} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Failed databases:${NC}"
    for failed_db in "${FAILED_DBS[@]}"; do
        echo -e "  - ${failed_db}"
    done
fi

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# List all backups with this timestamp
echo -e "${BLUE}Backup files created:${NC}"
ls -lh "${BACKUP_DIR}/${TIMESTAMP}"_*.dump 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""

# Exit with appropriate code
if [[ ${BACKUP_FAILED} -gt 0 ]]; then
    echo -e "${RED}Backup completed with errors (exit code 1)${NC}"
    exit 1
else
    echo -e "${GREEN}All backups completed successfully (exit code 0)${NC}"
    echo -e "${GREEN}Backup timestamp: ${TIMESTAMP}${NC}"
    exit 0
fi
