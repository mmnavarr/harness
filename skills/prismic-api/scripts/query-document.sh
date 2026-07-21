#!/bin/bash
# Query a Prismic document by type and optional UID
# Usage: ./query-document.sh <type> [uid] [jq-filter]
# Examples:
#   ./query-document.sh homepage
#   ./query-document.sh experiment headline-wording4
#   ./query-document.sh experiment headline-wording4 '.data.variations'
set -euo pipefail
source "$(dirname "$0")/setup.sh"

TYPE="${1:?Usage: query-document.sh <type> [uid] [jq-filter]}"
UID_VAL="${2:-}"
JQ_FILTER="${3:-.}"

if [ -n "$UID_VAL" ]; then
  QUERY="[[at(my.${TYPE}.uid,\"${UID_VAL}\")]]"
else
  QUERY="[[at(document.type,\"${TYPE}\")]]"
fi

ENCODED=$(echo -n "$QUERY" | jq -Rr @uri)
RESPONSE=$(curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=${ENCODED}&pageSize=100")

if [ -n "$UID_VAL" ]; then
  echo "$RESPONSE" | jq ".results[0] | $JQ_FILTER"
else
  echo "$RESPONSE" | jq ".results[] | $JQ_FILTER"
fi
