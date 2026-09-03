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
  echo "  flutter build web --release --base-href / --dart-define=HUBSOM_API_BASE_URL=https://hubsom.com"
  exit 1
fi

# Flutter keeps main.dart.js / flutter_bootstrap.js at the same URL every
# release. Stamp query params so browsers do not keep a year-old bundle.
# Also disable Flutter's service worker — older SWs cached main.dart.js forever.
STAMP="${HOSTING_STAMP:-$(date -u +%Y%m%d%H%M%S)}"
if [ -f "$ROOT/build/web/index.html" ]; then
  sed -i "s|flutter_bootstrap.js[^\"']*|flutter_bootstrap.js?v=${STAMP}|g" "$ROOT/build/web/index.html"
fi
for f in flutter_bootstrap.js flutter.js; do
  target="$ROOT/build/web/$f"
  if [ -f "$target" ]; then
    python3 - "$target" "$STAMP" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
stamp = sys.argv[2]
text = path.read_text()
text = re.sub(
    r"_flutter\.loader\.load\(\{[\s\S]*?\}\);",
    "_flutter.loader.load({});",
    text,
    count=1,
)
text = re.sub(r"main\.dart\.js(\?v=[^\"']*)?", f"main.dart.js?v={stamp}", text)
path.write_text(text)
PY
  fi
done
echo "Stamped hosting assets with v=${STAMP} (service worker disabled)"

export PATH="${HOME}/.npm-global/bin:${PATH}"
if ! command -v firebase >/dev/null 2>&1; then
  npm install -g firebase-tools --prefix "${HOME}/.npm-global"
fi

firebase deploy --only hosting --project hubsom-web --non-interactive --token "$TOKEN"
