#!/bin/bash
# Shared setup for all Prismic scripts: loads env vars and fetches master ref
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$SKILL_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  op inject -i "$SKILL_DIR/.env.example" -o "$ENV_FILE" --account defialliancellc.1password.com --force >/dev/null 2>&1
fi

source "$ENV_FILE"

export PRISMIC_REF=$(curl -s "https://alliance.cdn.prismic.io/api/v2" | jq -r '.refs[] | select(.isMasterRef == true) | .ref')
