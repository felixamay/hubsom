#!/usr/bin/env bash
# Deploy the Flutter web build to Firebase Hosting (hubsom-web).
# Usage:
#   FIREBASE_TOKEN=xxxxx ./scripts/deploy_hosting.sh
#   ./scripts/deploy_hosting.sh   # reads hubsom_app/.firebase-token if present
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TOKEN="${FIREBASE_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f "$ROOT/.firebase-token" ]; then
  TOKEN="$(tr -d '[:space:]' < "$ROOT/.firebase-token")"
fi

if [ -z "$TOKEN" ]; then
  echo "Set FIREBASE_TOKEN or put a CI token in hubsom_app/.firebase-token"
  echo "Create a token on your machine with: firebase login:ci"
  exit 1
fi

if [ ! -d "$ROOT/build/web" ]; then
  echo "build/web is missing. Build first:"
  echo "  flutter build web --release --base-href / \\"
  echo "    --dart-define=HUBSOM_API_BASE_URL=https://hubsom.com \\"
  echo "    --dart-define=FIREBASE_ENABLED=true"
  echo "  (add --dart-define=HUBSOM_STORAGE_BUCKET=<bucket> for a custom bucket)"
  exit 1
fi

# Safari treats main.dart.js?v=stamp as the same cached URL as main.dart.js.
# Copy JS to unique filenames and replace Flutter's service worker with a
# kill-switch so an old PWA worker cannot keep serving last year's HTML.
STAMP="${HOSTING_STAMP:-$(date -u +%Y%m%d%H%M%S)}"
python3 "$ROOT/scripts/stamp_hosting.py" --web-dir "$ROOT/build/web" --stamp "$STAMP"
echo "Stamped hosting assets with unique filenames (${STAMP})"

export PATH="${HOME}/.npm-global/bin:${PATH}"
if ! command -v firebase >/dev/null 2>&1; then
  npm install -g firebase-tools --prefix "${HOME}/.npm-global"
fi

firebase deploy --only hosting --project hubsom-web --non-interactive --token "$TOKEN"
