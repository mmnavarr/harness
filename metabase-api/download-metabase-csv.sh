#!/bin/bash
# Download portfolio report from Metabase as CSV
# Usage: ./download-metabase-csv.sh [output_file]
#
# SECURITY NOTICE:
# - This script retrieves the Metabase API key from 1Password
# - NEVER print, echo, or expose the API_KEY variable
# - If verification is needed, only check the first 5 characters
# - The API key is automatically secured in transit via HTTPS

set -e

OUTPUT_FILE="${1:-/tmp/actual.csv}"

echo "Retrieving Metabase API key from 1Password..."
API_KEY=$(op read "op://Private/52pjp46bnyr2ncfknfonvhju3y/credential" --account defialliancellc.1password.com)

if [ -z "$API_KEY" ]; then
  echo "❌ Failed to retrieve API key from 1Password"
  exit 1
fi

echo "✓ API key retrieved (${API_KEY:0:5}...)"
echo "Downloading portfolio report (question 947)..."

curl -X POST "https://metabase-alliance.up.railway.app/api/card/947/query/csv" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": [
      {"type": "date/single", "target": ["variable", ["template-tag", "date"]], "value": "2025-03-31"},
      {"type": "category", "target": ["variable", ["template-tag", "fund"]], "value": "FUND II"}
    ]
  }' > "$OUTPUT_FILE"

if [ $? -ne 0 ]; then
  echo "❌ Failed to download report"
  exit 1
fi

ROW_COUNT=$(wc -l < "$OUTPUT_FILE")
echo "✓ Downloaded $ROW_COUNT rows"
echo "✓ Saved to: $OUTPUT_FILE"
echo ""
echo "First few lines:"
head -5 "$OUTPUT_FILE"
