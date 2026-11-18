#!/usr/bin/env bash
# Back up one company's database and attachments.   ./scripts/backup.sh <brand> [out-dir]
# Produces <out-dir>/<brand>-<UTC timestamp>/{db.sql.gz,attachments.tar.gz,SHA256SUMS}.
# Letters are E2E ciphertext, so the backup holds no readable bodies; still keep it private.
set -euo pipefail
BRAND="${1:?usage: ./scripts/backup.sh <brand> [out-dir]}"
OUT="${2:-backups}/$BRAND-$(date -u +%Y%m%dT%H%M%SZ)"
PROJECT="letters-$BRAND"
mkdir -p "$OUT"
docker compose -p "$PROJECT" exec -T db pg_dump -U letters --no-owner letters | gzip > "$OUT/db.sql.gz"
docker compose -p "$PROJECT" exec -T server tar -C /app/attachments -cz . > "$OUT/attachments.tar.gz"
(cd "$OUT" && shasum -a 256 db.sql.gz attachments.tar.gz > SHA256SUMS)
echo "Backup written to $OUT"
