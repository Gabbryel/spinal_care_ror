#!/usr/bin/env bash
set -euo pipefail

APP=spinal-care
DB=spinal_care_ror_development

# Fail early with a clear message instead of hanging on an interactive prompt.
heroku whoami >/dev/null 2>&1 || { echo "Not logged in. Run: heroku login"; exit 1; }

heroku pg:backups:capture -a "$APP"

# Only remove the old dump once we're ready to replace it.
rm -f latest.dump
heroku pg:backups:download -a "$APP"

# Recreate the database rather than using pg_restore --clean: local-only tables
# hold foreign keys onto users/members/medical_services, so the drops fail and
# those tables silently keep stale data.
psql -h localhost -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$DB';" >/dev/null
dropdb -h localhost --if-exists "$DB"
createdb -h localhost "$DB"

pg_restore --verbose --no-acl --no-owner -h localhost -d "$DB" latest.dump

# The dump is at production's schema; apply anything newer that's local.
bin/rails db:migrate
