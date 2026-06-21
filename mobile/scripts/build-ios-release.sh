#!/usr/bin/env bash
# Build iOS release (Mac) — sans signature IPA automatique
set -euo pipefail
API_URL="${1:-https://api.sombateka.cd}"
SENTRY_DSN="${2:-}"

cd "$(dirname "$0")/.."

if [[ ! -f assets/icon/app_icon.png ]]; then
  python3 scripts/generate_store_assets.py
fi

flutter pub get
dart run flutter_launcher_icons 2>/dev/null || true
dart run flutter_native_splash:create 2>/dev/null || true

pushd ios >/dev/null
pod install
popd >/dev/null

DEFINES=(--dart-define=ST_API_BASE_URL="$API_URL")
if [[ -n "$SENTRY_DSN" ]]; then
  DEFINES+=(--dart-define=SENTRY_DSN="$SENTRY_DSN")
fi

flutter build ios --release "${DEFINES[@]}" --no-codesign

echo ""
echo "✅ Build iOS terminé"
echo "   Ouvrez ios/Runner.xcworkspace → Product → Archive → Distribute"
