#!/usr/bin/env bash
# Build iOS release (Mac) — sans signature IPA automatique
set -euo pipefail
API_URL="${1:-https://api.sombateka.cd}"
SENTRY_DSN="${2:-}"
TERMS_URL="${3:-https://sombateka.cd/terms}"
PRIVACY_URL="${4:-https://sombateka.cd/privacy}"
DELETE_ACCOUNT_URL="${5:-https://sombateka.cd/account-deletion}"
SUPPORT_EMAIL="${6:-support@sombateka.cd}"

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

DEFINES=(
  --dart-define=ST_API_BASE_URL="$API_URL"
  --dart-define=ST_TERMS_URL="$TERMS_URL"
  --dart-define=ST_PRIVACY_URL="$PRIVACY_URL"
  --dart-define=ST_DELETE_ACCOUNT_URL="$DELETE_ACCOUNT_URL"
  --dart-define=ST_SUPPORT_EMAIL="$SUPPORT_EMAIL"
  --dart-define=ST_SOCIAL_AUTH_ENABLED=true
  --dart-define=ST_APPLE_SIGNIN_ENABLED=true
)
if [[ -n "$SENTRY_DSN" ]]; then
  DEFINES+=(--dart-define=SENTRY_DSN="$SENTRY_DSN")
fi

flutter build ios --release "${DEFINES[@]}" --no-codesign

echo ""
echo "✅ Build iOS terminé"
echo "   Ouvrez ios/Runner.xcworkspace → Product → Archive → Distribute"
