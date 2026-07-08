#!/bin/bash
# List all shared slices or get a specific one
# Usage: ./list-slices.sh [slice-id]
# Examples:
#   ./list-slices.sh                    # list all
#   ./list-slices.sh page_heading       # get specific slice definition
set -euo pipefail
source "$(dirname "$0")/setup.sh"

SLICE_ID="${1:-}"

if [ -n "$SLICE_ID" ]; then
  curl -s -X GET "https://customtypes.prismic.io/slices/${SLICE_ID}" \
    -H "repository: alliance" \
    -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" | jq '.'
else
  curl -s -X GET "https://customtypes.prismic.io/slices" \
    -H "repository: alliance" \
    -H "Authorization: Bearer ${PRISMIC_ACCESS_TOKEN}" | jq '.[] | {id, name}'
fi
