#!/usr/bin/env bash
# Link Hubsom video to Google Cloud Storage.
#
# Run this once after Firebase Storage has been turned on for `hubsom-web`
# (Firebase console > Build > Storage > Get started; needs the Blaze plan).
# It verifies the bucket exists, publishes storage.rules, and applies CORS so
# browsers can stream clips with range requests (seeking, Safari).
#
# Usage:
#   FIREBASE_TOKEN=xxxxx ./scripts/setup_storage.sh
#   ./scripts/setup_storage.sh          # reads hubsom_app/.firebase-token
#
# CORS needs Google Cloud credentials as well as the Firebase token:
#   gcloud auth login          (or)   GOOGLE_APPLICATION_CREDENTIALS=key.json
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="hubsom-web"
# HUBSOM_STORAGE_BUCKET overrides the project default, matching the
# --dart-define the app is built with.
BUCKET="${HUBSOM_STORAGE_BUCKET:-}"
BUCKET="${BUCKET#gs://}"
if [ -z "$BUCKET" ]; then
  BUCKET="$(grep -o "storageBucket: '[^']*'" lib/core/config/firebase_options.dart |
    head -1 | cut -d"'" -f2)"
fi

if [ -z "$BUCKET" ]; then
  echo "Could not resolve a bucket. Set HUBSOM_STORAGE_BUCKET or fix"
  echo "storageBucket in lib/core/config/firebase_options.dart"
  exit 1
fi
echo "Project: $PROJECT"
echo "Bucket:  $BUCKET"

# 1. Does the bucket exist yet? This is the check the app itself performs.
code="$(curl -s -o /dev/null -w '%{http_code}' \
  "https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o?maxResults=1")"
if [ "$code" = "404" ]; then
  cat <<EOF

Firebase Storage is not enabled on $PROJECT yet — there is no bucket to link.

Turn it on first:
  1. https://console.firebase.google.com/project/$PROJECT/storage
  2. "Get started", accept the rules prompt, pick a location
     (europe-west1 or eur3 is closest to Ghana).
  3. Storage requires the Blaze plan. The free tier that comes with it
     (5 GB stored, 1 GB/day downloaded) covers early traffic.

Using a bucket you made yourself instead? Link it to Firebase Storage first
("Add bucket" on the same page) — the app writes through the Firebase Storage
SDK, so storage.rules must apply to it. Then rebuild and rerun with:
  HUBSOM_STORAGE_BUCKET=your-bucket ./scripts/setup_storage.sh
and build the web app with the matching
  --dart-define=HUBSOM_STORAGE_BUCKET=your-bucket

Then run this script again. Until then the app keeps videos working through
its Firestore-chunk fallback, so nothing is broken — clips are just slower
and cannot be seeked.
EOF
  exit 2
fi
echo "Bucket responds ($code) — Storage is enabled."

# 2. Storage rules.
TOKEN="${FIREBASE_TOKEN:-}"
if [ -z "$TOKEN" ] && [ -f "$ROOT/.firebase-token" ]; then
  TOKEN="$(tr -d '[:space:]' < "$ROOT/.firebase-token")"
fi
if [ -z "$TOKEN" ]; then
  echo "Set FIREBASE_TOKEN or put a CI token in hubsom_app/.firebase-token"
  echo "Create one with: firebase login:ci"
  exit 1
fi

export PATH="${HOME}/.npm-global/bin:${PATH}"
if ! command -v firebase >/dev/null 2>&1; then
  npm install -g firebase-tools --prefix "${HOME}/.npm-global"
fi
firebase deploy --only storage --project "$PROJECT" --non-interactive --token "$TOKEN"
echo "Published storage.rules"

# 3. CORS. Optional: download URLs already send Access-Control-Allow-Origin,
# but direct storage.googleapis.com range requests need this.
if command -v gcloud >/dev/null 2>&1; then
  if gcloud storage buckets update "gs://${BUCKET}" --cors-file=cors.json 2>/dev/null; then
    echo "Applied cors.json"
  else
    echo "Skipped CORS: gcloud has no credentials for $BUCKET."
    echo "  Run: gcloud auth login && gcloud config set project $PROJECT"
    echo "  Then: gcloud storage buckets update gs://${BUCKET} --cors-file=cors.json"
  fi
else
  echo "Skipped CORS: gcloud not installed (optional)."
  echo "  Install the Google Cloud CLI, then:"
  echo "  gcloud storage buckets update gs://${BUCKET} --cors-file=cors.json"
fi

cat <<EOF

Done. Nothing to rebuild or redeploy:
the app probes for the bucket at runtime and switches to Storage on its own
(within 30 minutes for already-open tabs, immediately on next load). Sellers'
existing clips migrate off the Firestore fallback in the background as they
open My videos or Home.
EOF
