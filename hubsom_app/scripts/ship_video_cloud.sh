#!/usr/bin/env bash
# One command to put Hubsom video on Google Cloud Storage and ship the app.
#
#   1. publishes storage.rules to the bucket (without this the app gets 403,
#      because a console-created bucket demands Firebase Auth and Hubsom has
#      none) and verifies an anonymous upload really is allowed
#   2. builds the Flutter web release
#   3. deploys Hosting with a fresh cache-busting stamp
#
# Credentials — either one (see scripts/firebase_auth.sh):
#   FIREBASE_SERVICE_ACCOUNT='<key.json contents>'   # preferred
#   FIREBASE_TOKEN=1//xxxx
#
# Optional:
#   HUBSOM_STORAGE_BUCKET=my-bucket   # non-default bucket
#   HOSTING_STAMP=20260913v114        # defaults to a UTC timestamp
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> 1/3 Storage rules"
# Exit 2 means "no bucket yet"; that is a stop, not a crash.
set +e
./scripts/setup_storage.sh
storage_status=$?
set -e
if [ "$storage_status" = "2" ]; then
  echo
  echo "Stopping: create the bucket first (instructions above)."
  exit 2
elif [ "$storage_status" != "0" ]; then
  exit "$storage_status"
fi

echo
echo "==> 2/3 Build web"
BUCKET_DEFINE="${HUBSOM_STORAGE_BUCKET:-}"
flutter build web --release --base-href / --pwa-strategy=none \
  --dart-define=HUBSOM_API_BASE_URL=https://hubsom.com \
  --dart-define=FIREBASE_ENABLED=true \
  --dart-define=HUBSOM_STORAGE_BUCKET="$BUCKET_DEFINE"

echo
echo "==> 3/3 Deploy Hosting"
./scripts/deploy_hosting.sh

cat <<'EOF'

Done. Video is now on Google Cloud Storage:
  - new uploads stream from the CDN, so seeking and Safari work
  - sellers' existing clips migrate off the Firestore fallback in the
    background as they open Home or My videos
EOF
