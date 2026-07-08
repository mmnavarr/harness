#!/bin/bash
# Get full experiment details by UID
# Usage: ./get-experiment.sh <uid> [jq-filter]
# Examples:
#   ./get-experiment.sh headline-wording4
#   ./get-experiment.sh apply-tagline '.data.slices'
set -euo pipefail
source "$(dirname "$0")/setup.sh"

UID_VAL="${1:?Usage: get-experiment.sh <uid> [jq-filter]}"
JQ_FILTER="${2:-.data}"

QUERY="[[at(my.experiment.uid,\"${UID_VAL}\")]]"
ENCODED=$(echo -n "$QUERY" | jq -Rr @uri)

curl -s "https://alliance.cdn.prismic.io/api/v2/documents/search?ref=${PRISMIC_REF}&q=${ENCODED}" | \
  jq ".results[0] | $JQ_FILTER"
