#!/usr/bin/env bash
# Prints a two-line frontmatter block for product-map pages:
#   lastCheckedCommit: <short-sha>
#   lastCheckedDate: <YYYY-MM-DD>
#
# Run from inside the alliance-network repo, or set REPO=/path/to/repo.
set -euo pipefail

if [ -n "${REPO:-}" ]; then
  cd "$REPO"
fi

git fetch origin master --quiet || true
hash=$(git rev-parse --short origin/master)
date=$(date +%F)

printf 'lastCheckedCommit: %s\nlastCheckedDate: %s\n' "$hash" "$date"
