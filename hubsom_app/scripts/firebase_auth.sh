#!/usr/bin/env bash
# Shared Firebase CLI auth for the deploy / setup scripts.
#
# Two ways to authenticate, in order of preference:
#
#   1. A service account (least privilege, recommended)
#        GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
#      or the JSON itself in an env var, which is what a Cursor secret holds:
#        FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'
#      Roles needed: Firebase Hosting Admin, Firebase Rules Admin.
#      This grants access to this project only.
#
#   2. A CI token from `firebase login:ci`
#        FIREBASE_TOKEN=1//xxxx
#      or hubsom_app/.firebase-token
#      Note this is a personal refresh token: it can reach every Firebase
#      project your Google account can, so prefer option 1.
#
# Sets FIREBASE_AUTH_MODE to "service-account" or "token".

FIREBASE_PROJECT="${FIREBASE_PROJECT:-hubsom-web}"
FIREBASE_AUTH_MODE=""
FIREBASE_TOKEN_VALUE=""

firebase_auth_resolve() {
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  # Inline service-account JSON (Cursor secret / CI variable).
  if [ -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] &&
    [ -n "${FIREBASE_SERVICE_ACCOUNT:-}" ]; then
    local key_file
    key_file="$(mktemp -t hubsom-sa-XXXXXX.json)"
    printf '%s' "$FIREBASE_SERVICE_ACCOUNT" >"$key_file"
    chmod 600 "$key_file"
    export GOOGLE_APPLICATION_CREDENTIALS="$key_file"
    # shellcheck disable=SC2064
    trap "rm -f '$key_file'" EXIT
  fi

  if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] &&
    [ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
    FIREBASE_AUTH_MODE="service-account"
    echo "Auth: service account ($(basename "$GOOGLE_APPLICATION_CREDENTIALS"))"
    return 0
  fi

  FIREBASE_TOKEN_VALUE="${FIREBASE_TOKEN:-}"
  if [ -z "$FIREBASE_TOKEN_VALUE" ] && [ -f "$root/.firebase-token" ]; then
    FIREBASE_TOKEN_VALUE="$(tr -d '[:space:]' <"$root/.firebase-token")"
  fi
  if [ -n "$FIREBASE_TOKEN_VALUE" ]; then
    FIREBASE_AUTH_MODE="token"
    echo "Auth: CI token"
    return 0
  fi

  cat <<EOF
No Firebase credentials found. Provide one of:

  Service account (recommended, this project only):
    GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
    FIREBASE_SERVICE_ACCOUNT='<the JSON contents>'
    Roles: Firebase Hosting Admin + Firebase Rules Admin

  CI token (reaches every project your Google account can):
    FIREBASE_TOKEN=\$(firebase login:ci)
    or write it to hubsom_app/.firebase-token
EOF
  return 1
}

firebase_auth_install_cli() {
  export PATH="${HOME}/.npm-global/bin:${PATH}"
  if ! command -v firebase >/dev/null 2>&1; then
    npm install -g firebase-tools --prefix "${HOME}/.npm-global"
  fi
}

# firebase_deploy --only hosting
firebase_deploy() {
  if [ "$FIREBASE_AUTH_MODE" = "service-account" ]; then
    firebase deploy "$@" --project "$FIREBASE_PROJECT" --non-interactive
  else
    firebase deploy "$@" --project "$FIREBASE_PROJECT" --non-interactive \
      --token "$FIREBASE_TOKEN_VALUE"
  fi
}
