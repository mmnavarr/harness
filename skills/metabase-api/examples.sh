#!/bin/bash
# Metabase API Examples
# This file contains example commands for interacting with the Metabase API

set -e

# Get API key from 1Password
echo "Retrieving API key from 1Password..."
API_KEY=$(op read "op://Private/52pjp46bnyr2ncfknfonvhju3y/credential" --account defialliancellc.1password.com)

METABASE_URL="https://metabase-alliance.up.railway.app"

# Example 1: Get question details and SQL query
echo -e "\n=== Example 1: Get Question 947 SQL Query ==="
curl -s -X GET "${METABASE_URL}/api/card/947" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq -r '.dataset_query.native.query' > /tmp/metabase_query_947.sql

echo "SQL query saved to /tmp/metabase_query_947.sql"
echo "First 10 lines:"
head -10 /tmp/metabase_query_947.sql

# Example 2: Get question metadata
echo -e "\n=== Example 2: Get Question Metadata ==="
curl -s -X GET "${METABASE_URL}/api/card/947" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq '{id, name, description, display, parameters: .dataset_query.native["template-tags"] | keys}'

# Example 3: List all questions
echo -e "\n=== Example 3: List Recent Questions ==="
curl -s -X GET "${METABASE_URL}/api/card" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq '.data[:5] | .[] | {id, name}'

# Example 4: Execute a query with parameters and get CSV results
echo -e "\n=== Example 4: Execute Question with Parameters (CSV) ==="
curl -s -X POST "${METABASE_URL}/api/card/947/query/csv" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": [
      {"type": "date/single", "target": ["variable", ["template-tag", "date"]], "value": "2025-03-31"},
      {"type": "category", "target": ["variable", ["template-tag", "fund"]], "value": "FUND II"}
    ]
  }' > /tmp/metabase_results.csv

echo "Results saved to /tmp/metabase_results.csv"
echo "First 5 rows:"
head -6 /tmp/metabase_results.csv

# Example 4b: Execute a query with parameters and get JSON results
echo -e "\n=== Example 4b: Execute Question with Parameters (JSON) ==="
curl -s -X POST "${METABASE_URL}/api/card/947/query" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": [
      {"type": "date/single", "target": ["variable", ["template-tag", "date"]], "value": "2025-03-31"},
      {"type": "category", "target": ["variable", ["template-tag", "fund"]], "value": "FUND II"}
    ]
  }' | jq '.data.rows[:3]'

echo -e "\n(Showing first 3 rows of JSON results)"

# Example 5: List all dashboards
echo -e "\n=== Example 5: List Dashboards ==="
curl -s -X GET "${METABASE_URL}/api/dashboard" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq '.data[:5] | .[] | {id, name}'

# Example 6: Get database list
echo -e "\n=== Example 6: List Databases ==="
curl -s -X GET "${METABASE_URL}/api/database" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq '.data[] | {id, name, engine}'

echo -e "\nDone! All examples completed successfully."
