#!/usr/bin/env bash
# Restore a backup into a running stack.   ./scripts/restore.sh <brand> <backup-dir>
# DESTRUCTIVE for the target database: it is dropped and recreated. Run only on the stack you mean to overwrite.
set -euo pipefail
BRAND="${1:?usage: ./scripts/restore.sh <brand> <backup-dir>}"
DIR="${2:?backup dir}"
PROJECT="letters-$BRAND"
(cd "$DIR" && shasum -a 256 -c SHA256SUMS)
read -r -p "Overwrite the '$BRAND' database and attachments with $DIR? Type the brand name to continue: " ANSWER
[ "$ANSWER" = "$BRAND" ] || { echo "Aborted." >&2; exit 1; }
docker compose -p "$PROJECT" stop server
docker compose -p "$PROJECT" exec -T db psql -U letters -d postgres -c "DROP DATABASE IF EXISTS letters WITH (FORCE)" -c "CREATE DATABASE letters OWNER letters"
gunzip -c "$DIR/db.sql.gz" | docker compose -p "$PROJECT" exec -T db psql -U letters -d letters -v ON_ERROR_STOP=1 >/dev/null
docker compose -p "$PROJECT" run --rm -T --no-deps --entrypoint sh server -c "tar -C /app/attachments -xz" < "$DIR/attachments.tar.gz"
docker compose -p "$PROJECT" start server
echo "Restored. Verify the audit chain: docker compose -p $PROJECT exec server python manage.py verify_audit"
