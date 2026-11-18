#!/usr/bin/env bash
# Build/run one company's backend and app.
#   ./build.sh <brand> up                 start backend (docker compose)
#   ./build.sh <brand> app <platform>     flutter build <apk|ios|macos|windows> for that brand
set -euo pipefail
BRAND="${1:?usage: ./build.sh <brand> up|app <platform>}"
CMD="${2:?usage: ./build.sh <brand> up|app <platform>}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BRAND_DIR="$ROOT/brands/$BRAND"
[ -f "$BRAND_DIR/brand.json" ] || { echo "No brand.json in $BRAND_DIR" >&2; exit 1; }

case "$CMD" in
  up)
    ENV_FILE="$BRAND_DIR/.env"
    [ -f "$ENV_FILE" ] || { echo "Create $ENV_FILE (see brands/.env.example)" >&2; exit 1; }
    BRAND="$BRAND" docker compose -p "letters-$BRAND" --env-file "$ENV_FILE" up -d --build
    ;;
  app)
    PLATFORM="${3:?platform: apk|ios|macos|windows}"
    # copy the brand's files into the app assets so the app works offline on first launch
    rm -rf "$ROOT/app/assets/brand" && mkdir -p "$ROOT/app/assets/brand"
    cp "$BRAND_DIR/brand.json" "$BRAND_DIR/logo.svg" "$ROOT/app/assets/brand/"
    (cd "$ROOT/app" && flutter pub get && flutter build "$PLATFORM" --dart-define=BRAND="$BRAND")
    ;;
  *) echo "unknown command: $CMD" >&2; exit 1 ;;
esac
