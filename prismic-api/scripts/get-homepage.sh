#!/bin/bash
# Get homepage document data
# Usage: ./get-homepage.sh [jq-filter]
# Examples:
#   ./get-homepage.sh                          # full data
#   ./get-homepage.sh '.metaTagTitle'           # just the title
#   ./get-homepage.sh '.slices[] | .slice_type' # list slice types
#   ./get-homepage.sh '.slices1'                # dark section slices
set -euo pipefail
source "$(dirname "$0")/setup.sh"

JQ_FILTER="${1:-.}"

QUERY='[[at(document.type,"homepage")]]'
ENCODED=$(echo -n "$QUERY" | jq -Rr @uri)

curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=${ENCODED}" | \
  jq ".results[0].data | $JQ_FILTER"
