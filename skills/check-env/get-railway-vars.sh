#!/usr/bin/env bash
# Fetches the set variable names for a given app from Railway and prints them as a JSON array.
# Usage: ./get-railway-vars.sh <app-name>
# app-name: admin | webapp | bullqueue | website

set -euo pipefail

APP="${1:-}"

ENV_ID="d34f7b5b-9b12-4c43-9bb2-4e147c9eed7d"

if [[ -z "$APP" ]]; then
  echo "Usage: $0 <app-name>" >&2
  echo "Valid apps: admin | webapp | bullqueue | website" >&2
  exit 1
fi

case "$APP" in
  admin)     SERVICE_ID="48cca3e3-8a44-452d-885d-b6abd0d43a47" ;;
  webapp)    SERVICE_ID="0cce270b-f1d1-491f-9d08-2e587f38ab4f" ;;
  bullqueue) SERVICE_ID="6142fda2-41a4-47f0-8f40-cf42d872ecb7" ;;
  website)   SERVICE_ID="f8a09749-1985-4313-86ba-63841a8d10cf" ;;
  *)
    echo "Unknown app: $APP. Valid apps: admin | webapp | bullqueue | website" >&2
    exit 1
    ;;
esac

railway variables \
  --service "$SERVICE_ID" \
  --environment "$ENV_ID" \
  --json 2>/dev/null \
  | jq 'keys'
