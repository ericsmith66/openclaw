# Junie Suggestions

## 2026-01-24 - Development Database Protection & Safety Rails

### Context
Development database was accidentally dropped at 7:36 PM CST during testing work on PRD-2-09. This wiped out:
- All user data and Plaid connections
- Queued nightly jobs (DailyPlaidSyncJob, SyncAllItemsJob, etc.)
- Financial snapshots and other development data

The root cause was running `bin/rails db:drop db:create db:migrate` (without RAILS_ENV=test), which dropped the development database instead of just the test database.

### Recommendations

- [ ] **Override `db:drop` task for development environment**
  - Add rake task that blocks `db:drop` in development without explicit confirmation
  - Require typing environment name to confirm (e.g., "type DEVELOPMENT to confirm")
  - Location: `lib/tasks/database_safety.rake`

- [ ] **Create automated development database backup script**
  - Daily automated dumps of development database
  - Keep last 7 days of backups
  - Store in `tmp/backups/` or external location
  - Add cron job or scheduled task to run daily
  - Location: `lib/tasks/backup.rake` or shell script

- [ ] **Update testing workflow guidelines for Junie**
  - Create explicit rules document about database commands
  - Test database: ALWAYS use `RAILS_ENV=test` prefix
  - Development database: NEVER drop during testing
  - Proper test commands: `RAILS_ENV=test bin/rails db:drop db:create db:migrate`
  - Location: `knowledge_base/development/testing-guidelines.md`

- [ ] **Separate test data seeding strategy**
  - Ensure tests can run independently with fixtures/factories
  - Never require dropping development database
  - Document proper use of `rails db:test:prepare`
  - Location: Update `knowledge_base/development/testing-guidelines.md`

- [ ] **Add development database restore documentation**
  - Document how to restore from backup
  - Document how to reconnect Plaid items after database loss
  - Quick recovery steps
  - Location: `knowledge_base/development/database-recovery.md`

- [ ] **Add pre-commit hook or rake task validator**
  - Check for dangerous commands in test scripts
  - Warn about `db:drop` without RAILS_ENV
  - Optional: Block certain commands in CI/development
  - Location: `.git/hooks/pre-commit` or `lib/tasks/validate.rake`

### Priority
High - Prevent data loss in development environment

### Notes
Once Plaid connections are restored tomorrow, verify all scheduled jobs are properly queued in `config/recurring.yml`.
