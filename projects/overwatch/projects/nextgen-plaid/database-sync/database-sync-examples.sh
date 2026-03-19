#!/bin/bash
# Database Sync Examples
# These are example commands for syncing NextGen Plaid databases from remote to local

REMOTE_HOST="192.168.4.253"
REMOTE_USER="ericsmith66"
REMOTE_PSQL="/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql"
REMOTE_PG_DUMP="/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump"
LOCAL_PG_RESTORE="/opt/homebrew/opt/postgresql@16/bin/pg_restore"

# Example 1: Simple test - dump schema only
echo "=== Example 1: Dump remote schema ==="
ssh ${REMOTE_USER}@${REMOTE_HOST} "${REMOTE_PG_DUMP} --schema-only nextgen_plaid_development" | head -50

# Example 2: Stream sync single database (most efficient)
echo -e "\n=== Example 2: Stream sync single database ==="
echo "Command:"
echo "ssh ${REMOTE_USER}@${REMOTE_HOST} \"${REMOTE_PG_DUMP} --format=custom --no-owner --no-acl nextgen_plaid_development\" | \\"
echo "  ${LOCAL_PG_RESTORE} --no-owner --no-acl --clean --if-exists -d nextgen_plaid_development"

# Example 3: Backup local database first
echo -e "\n=== Example 3: Backup local database ==="
echo "Command:"
echo "pg_dump --format=custom --no-owner --no-acl -d nextgen_plaid_development -f ./backup_$(date +%Y%m%d_%H%M%S).dump"

# Example 4: Full sync script (simplified)
echo -e "\n=== Example 4: Full sync script outline ==="
cat << 'EOF'
#!/bin/bash
set -euo pipefail

DATABASES=(
  "nextgen_plaid_development"
  "nextgen_plaid_development_queue"
  "nextgen_plaid_development_cable"
)

for db in "${DATABASES[@]}"; do
  echo "Syncing $db..."
  
  # Backup local if exists
  if psql -l | grep -q " $db "; then
    pg_dump --format=custom --no-owner --no-acl -d "$db" -f "${db}_backup_$(date +%Y%m%d_%H%M%S).dump"
  fi
  
  # Drop and recreate local database
  psql -c "DROP DATABASE IF EXISTS $db;" postgres
  psql -c "CREATE DATABASE $db;" postgres
  
  # Stream sync
  ssh ericsmith66@192.168.4.253 \
    "/opt/homebrew/Cellar/postgresql@16/16.11_1/bin/pg_dump --format=custom --no-owner --no-acl $db" | \
    pg_restore --no-owner --no-acl --clean --if-exists -d "$db"
  
  echo "✓ $db synced"
done
EOF

# Example 5: Check database sizes
echo -e "\n=== Example 5: Check remote database sizes ==="
echo "Command:"
cat << 'EOF'
ssh ericsmith66@192.168.4.253 << 'SSH_EOF'
  /opt/homebrew/Cellar/postgresql@16/16.11_1/bin/psql -d nextgen_plaid_development -c "
    SELECT 
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
    FROM pg_tables
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 10;
  "
SSH_EOF
EOF

# Example 6: Dry-run test
echo -e "\n=== Example 6: Dry-run test ==="
echo "Command:"
echo "ssh ${REMOTE_USER}@${REMOTE_HOST} \"${REMOTE_PG_DUMP} --schema-only nextgen_plaid_development 2>/dev/null | wc -l\""
echo "Expected output: Number of lines in schema dump"

echo -e "\n=== Next Steps ==="
echo "1. Review the prototype Ruby script: database-sync-prototype.rb"
echo "2. Test connectivity: ruby test-database-connectivity.rb"
echo "3. Review the plan: database-sync-plan.md"
echo "4. Provide feedback on approach before full implementation"