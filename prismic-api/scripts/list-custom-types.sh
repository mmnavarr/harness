#!/bin/bash
# List all custom types or get a specific one
# Usage: ./list-custom-types.sh [type-id]
# Examples:
#   ./list-custom-types.sh                    # list all
#   ./list-custom-types.sh experiment         # get specific type definition
set -euo pipefail
source "$(dirname "$0")/setup.sh"

TYPE_ID="${1:-}"

if [ -n "$TYPE_ID" ]; then
  curl -s -X GET "https://customtypes.prismic.io/customtypes/${TYPE_ID}" \
    -H "repository: alliance" \
    -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" | jq '.'
else
  curl -s -X GET "https://customtypes.prismic.io/customtypes" \
    -H "repository: alliance" \
    -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" | jq '.[] | {id, label, repeatable}'
fi
