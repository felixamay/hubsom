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

# 2. Storage rules. A console-created bucket starts with rules that demand
# Firebase Auth; Hubsom has none, so uploads 403 until these are published.
source "$ROOT/scripts/firebase_auth.sh"
FIREBASE_PROJECT="$PROJECT"
firebase_auth_resolve
firebase_auth_install_cli
firebase_deploy --only storage
echo "Published storage.rules"

# Confirm an anonymous write is actually allowed now — this is the exact call
# the app makes, and the thing default rules block.
probe="$(curl -s -X POST --max-time 20 \
  "https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o?name=shopVideos%2F.rules-probe" \
  -H 'Content-Type: image/jpeg' --data-binary 'probe' || true)"
if printf '%s' "$probe" | grep -q '"error"'; then
  echo
  echo "WARNING: an anonymous upload is still refused:"
  printf '%s\n' "$probe" | head -5
  echo "Check that storage.rules published to bucket $BUCKET."
else
  echo "Verified: the app can upload to $BUCKET"
  curl -s -X DELETE --max-time 15 \
    "https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/shopVideos%2F.rules-probe" \
    >/dev/null || true
fi

# 3. CORS. The download endpoint answers OPTIONS preflights on its own, but a
# real GET carries no Access-Control-Allow-Origin until the bucket has a CORS
# config. Prefer gcloud; fall back to the JSON API with the CLI's own token so
# this works on a machine with no Google Cloud SDK.
if command -v gcloud >/dev/null 2>&1 &&
  gcloud storage buckets update "gs://${BUCKET}" --cors-file=cors.json 2>/dev/null; then
  echo "Applied cors.json (gcloud)"
elif [ "$FIREBASE_AUTH_MODE" = "token" ]; then
  # firebase-tools' public OAuth client, used to mint a short-lived token.
  access_token="$(curl -s --max-time 30 -X POST https://oauth2.googleapis.com/token \
    -d 'client_id=563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com' \
    -d 'client_secret=j9iVZfS8kkCEFUPaAeJV0sAi' \
    -d "refresh_token=${FIREBASE_TOKEN_VALUE}" \
    -d 'grant_type=refresh_token' |
    python3 -c 'import sys,json; print(json.load(sys.stdin).get("access_token",""))')"
  if [ -n "$access_token" ] && curl -s --max-time 30 -o /dev/null -X PATCH \
    -H "Authorization: Bearer ${access_token}" \
    -H 'Content-Type: application/json' \
    -d "{\"cors\": $(cat cors.json)}" \
    "https://storage.googleapis.com/storage/v1/b/${BUCKET}"; then
    echo "Applied cors.json (Storage JSON API)"
  else
    echo "Skipped CORS: could not reach the Storage JSON API."
  fi
else
  echo "Skipped CORS: install gcloud, then"
  echo "  gcloud storage buckets update gs://${BUCKET} --cors-file=cors.json"
fi

# Verify a browser-style cross-origin read is actually allowed.
cors_probe_object='shopVideos%2F.cors-probe'
curl -s --max-time 20 -o /dev/null -X POST \
  "https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o?name=${cors_probe_object}" \
  -H 'Content-Type: video/mp4' --data-binary 'probe' || true
if curl -s --max-time 20 -o /dev/null -D - \
  -H 'Origin: https://hubsom.com' \
  "https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${cors_probe_object}?alt=media" |
  grep -qi 'access-control-allow-origin'; then
  echo "Verified: https://hubsom.com can read clips cross-origin"
else
  echo "NOTE: no Access-Control-Allow-Origin on a real GET. <video> playback"
  echo "  still works (media elements are no-cors), but add the origin to"
  echo "  cors.json if you ever fetch clips with XHR."
fi
curl -s --max-time 15 -o /dev/null -X DELETE \
  "https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${cors_probe_object}" || true

cat <<EOF

Done. Nothing to rebuild or redeploy:
the app probes for the bucket at runtime and switches to Storage on its own
(within 30 minutes for already-open tabs, immediately on next load). Sellers'
existing clips migrate off the Firestore fallback in the background as they
open My videos or Home.
EOF
