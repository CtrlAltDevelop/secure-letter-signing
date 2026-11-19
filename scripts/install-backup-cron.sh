#!/usr/bin/env bash
# Daily backup at 02:30 for one company.   ./scripts/install-backup-cron.sh <brand> [out-dir]
# Adds one crontab line (idempotent) that runs scripts/backup.sh and keeps the newest 14 backups.
set -euo pipefail
BRAND="${1:?usage: ./scripts/install-backup-cron.sh <brand> [out-dir]}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${2:-$ROOT/backups}"
LINE="30 2 * * * cd $ROOT && ./scripts/backup.sh $BRAND $OUT >> $OUT/backup.log 2>&1  # letters-backup-$BRAND"
mkdir -p "$OUT"
( crontab -l 2>/dev/null | grep -v "# letters-backup-$BRAND\$" || true; echo "$LINE" ) | crontab -
echo "Installed: $LINE"
