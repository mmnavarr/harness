#!/bin/bash
# Full-text search across all Prismic documents
# Usage: ./search-content.sh <search-term> [jq-filter]
# Examples:
#   ./search-content.sh "escape velocity"
#   ./search-content.sh "crypto" '{uid, type}'
set -euo pipefail
source "$(dirname "$0")/setup.sh"

SEARCH="${1:?Usage: search-content.sh <search-term> [jq-filter]}"
JQ_FILTER="${2:-{uid, type, id}}"

QUERY="[[fulltext(document, \"${SEARCH}\")]]"
ENCODED=$(echo -n "$QUERY" | jq -Rr @uri)

curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=${ENCODED}&pageSize=100" | \
  jq ".results[] | $JQ_FILTER"
