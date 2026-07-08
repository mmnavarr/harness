#!/bin/bash
# List all experiments with their enabled status and variation count
# Usage: ./list-experiments.sh [jq-filter]
# Examples:
#   ./list-experiments.sh
#   ./list-experiments.sh 'select(.enabled == true)'
set -euo pipefail
source "$(dirname "$0")/setup.sh"

JQ_FILTER="${1:-.}"

QUERY='[[at(document.type,"experiment")]]'
ENCODED=$(echo -n "$QUERY" | jq -Rr @uri)

curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=${ENCODED}&pageSize=100" | \
  jq ".results[] | {uid, enabled: .data.enabled, variations: .data.variations, slice_types: [.data.slices[].slice_type]} | $JQ_FILTER"
