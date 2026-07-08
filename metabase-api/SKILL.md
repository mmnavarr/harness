---
name: metabase-api
description: Query and analyze Metabase questions, dashboards, and SQL queries using the Metabase API with secure authentication via 1Password
---

# Metabase API Skill

Query and analyze Metabase questions, dashboards, and SQL queries using the Metabase API with secure authentication via 1Password.

## Overview

This skill enables you to:
- Retrieve SQL queries from Metabase questions
- Query question metadata and parameters
- List dashboards and cards
- Execute queries programmatically
- Analyze data models and relationships
- Safely modify SQL queries with baseline comparisons

## ⚠️ IMPORTANT: SQL Modification Workflow

**ALWAYS follow this workflow when asked to modify a SQL query:**

> 📋 **Quick Reference:** See [sql-modification-checklist.md](./sql-modification-checklist.md) for a detailed step-by-step checklist.

### Step-by-Step Workflow

1. **Capture Baseline Results**
   - Execute the original query with the same parameters
   - Save results to a baseline file (e.g., `/tmp/baseline_results.csv`)
   - If baseline fails to execute:
     - **STOP and ask the user what to do**
     - Provide error details
     - Do not proceed with modifications until resolved

2. **Make SQL Modifications**
   - Edit the SQL query as requested
   - Save changes to the local file
   - Update the Metabase question via API

3. **Execute Modified Query**
   - Run the updated query with identical parameters
   - Save results to a comparison file (e.g., `/tmp/modified_results.csv`)

4. **Compare Results**
   - Compare line counts
   - Compare MD5 checksums
   - Run `diff` to detect any data changes
   - Report comparison results to user

5. **Report Findings**
   - ✅ If identical: Confirm refactoring was successful
   - ❌ If different: Show differences and ask user to review

### Example Workflow

```bash
# Step 1: Capture baseline
curl -X POST "https://metabase-alliance.up.railway.app/api/card/947/query/csv" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": [
      {"type": "date/single", "target": ["variable", ["template-tag", "date"]], "value": "2025-03-31"},
      {"type": "category", "target": ["variable", ["template-tag", "fund"]], "value": "FUND II"}
    ]
  }' > /tmp/baseline_results.csv

# Check if baseline succeeded
if [ $? -ne 0 ]; then
  echo "❌ Baseline execution failed. Stopping workflow."
  # ASK USER: What should we do?
  exit 1
fi

# Step 2: Make modifications (edit SQL file)
# Step 3: Update Metabase question
# Step 4: Execute modified query (same command, different output file)

# Step 5: Compare results
echo "=== Comparison Results ==="
wc -l /tmp/baseline_results.csv /tmp/modified_results.csv
md5sum /tmp/baseline_results.csv /tmp/modified_results.csv
diff -q /tmp/baseline_results.csv /tmp/modified_results.csv && \
  echo "✅ Results are IDENTICAL" || \
  echo "❌ Results DIFFER - review required"
```

### When Baseline Fails

If the baseline query fails to execute:

**DO:**
- ✋ **STOP the workflow immediately**
- 📋 Capture and show the error message
- 🤔 **ASK THE USER**: "The baseline query failed with error: [ERROR]. What would you like to do? Options: (1) Fix the error first, (2) Proceed without baseline (risky), (3) Cancel modifications"

**DON'T:**
- ❌ Proceed with modifications without a baseline
- ❌ Assume the query will work after modifications
- ❌ Skip comparison steps

## Authentication Setup

### 1. Find the DeFi Alliance 1Password Account

First, identify the correct 1Password account:

```bash
op account list
```

Look for the account with the Alliance domain: `defialliancellc.1password.com`

### 2. Retrieve API Key from 1Password

The Metabase API key is stored in 1Password with UUID: `52pjp46bnyr2ncfknfonvhju3y`

```bash
API_KEY=$(op read "op://Private/52pjp46bnyr2ncfknfonvhju3y/credential" --account defialliancellc.1password.com)
```

## Metabase Instance

- **URL**: `https://metabase-alliance.up.railway.app`
- **API Base**: `https://metabase-alliance.up.railway.app/api`

## Common Operations

### Get Question Details and SQL Query

Retrieve a question's metadata including its SQL query:

```bash
# Get full question details
curl -X GET "https://metabase-alliance.up.railway.app/api/card/{QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq '.'

# Extract just the SQL query
curl -X GET "https://metabase-alliance.up.railway.app/api/card/{QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq -r '.dataset_query.native.query'
```

**Example**: For question 947 (Portfolio Report FII-III):
```bash
curl -X GET "https://metabase-alliance.up.railway.app/api/card/947" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq -r '.dataset_query.native.query'
```

### Execute a Query and Get Results

Run a saved question with parameters and get the results. Use `/query/csv` for CSV output or `/query` for JSON.

#### Execute and Get CSV Results

This is the most common way to execute queries and get results in CSV format:

```bash
curl -X POST "https://metabase-alliance.up.railway.app/api/card/{QUESTION_ID}/query/csv" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": [
      {"type": "date/single", "target": ["variable", ["template-tag", "date"]], "value": "2025-03-31"},
      {"type": "category", "target": ["variable", ["template-tag", "fund"]], "value": "FUND II"}
    ]
  }' > results.csv
```

**Real Example from Session**:
```bash
# Execute question 947 and save results to file
curl -X POST "https://metabase-alliance.up.railway.app/api/card/947/query/csv" \
  -H "X-API-Key: $(cat /tmp/metabase_key.txt)" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": [
      {"type": "date/single", "target": ["variable", ["template-tag", "date"]], "value": "2025-03-31"},
      {"type": "category", "target": ["variable", ["template-tag", "fund"]], "value": "FUND II"}
    ]
  }' > /tmp/baseline_results.csv

# View first 20 lines of results
head -20 /tmp/baseline_results.csv
```

#### Execute and Get JSON Results

For JSON output (useful for programmatic processing):

```bash
curl -X POST "https://metabase-alliance.up.railway.app/api/card/{QUESTION_ID}/query" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": [
      {"type": "date/single", "target": ["variable", ["template-tag", "date"]], "value": "2025-03-31"},
      {"type": "category", "target": ["variable", ["template-tag", "fund"]], "value": "FUND II"}
    ]
  }' | jq '.data.rows[:10]'
```

#### Parameter Type Reference

Common parameter types for the `type` field:
- `date/single` - Single date parameter
- `date/range` - Date range parameter
- `category` - Text/category parameter
- `number` - Numeric parameter
- `text` - General text parameter

The `target` array format is always: `["variable", ["template-tag", "PARAMETER_NAME"]]`

### Update Question SQL

To update a question's SQL query, use a PUT request. **Important**: Always GET the question first to preserve other fields.

```bash
# Step 1: Get the current question to preserve fields
curl -X GET "https://metabase-alliance.up.railway.app/api/card/{QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" > /tmp/current_question.json

# Step 2: Prepare the update payload with new SQL
jq --arg newSQL "$(cat your_new_query.sql)" \
  '.dataset_query.native.query = $newSQL' \
  /tmp/current_question.json > /tmp/updated_question.json

# Step 3: Update the question
curl -X PUT "https://metabase-alliance.up.railway.app/api/card/{QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d @/tmp/updated_question.json | jq '{id, name, updated: true}'
```

**Important Notes**:
1. **Preserve template tags**: If your SQL has parameters (like `{{date}}`), keep the `template-tags` object intact
2. **Get first, then update**: Always GET the current question to preserve other fields like `name`, `display`, `visualization_settings`
3. **Database ID**: The `database` field must match your Metabase database ID (usually `1` for the main database)
4. **API Key vs Session**: Can use either X-API-Key header (recommended) or X-Metabase-Session header

**Minimal Update Example** (only SQL, preserving everything else):
```bash
# This approach fetches current config and only updates the SQL query
QUESTION_ID=947
NEW_SQL=$(cat packages/imdb/src/portfolio-report.sql)

# Get current question and update just the SQL
curl -s -X GET "https://metabase-alliance.up.railway.app/api/card/${QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" | \
jq --arg sql "$NEW_SQL" '.dataset_query.native.query = $sql' | \
curl -X PUT "https://metabase-alliance.up.railway.app/api/card/${QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d @-
```

### List All Questions

```bash
curl -X GET "https://metabase-alliance.up.railway.app/api/card" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq '.data[] | {id, name, description}'
```

### Get Dashboard Details

```bash
curl -X GET "https://metabase-alliance.up.railway.app/api/dashboard/{DASHBOARD_ID}" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq '.'
```

### List All Dashboards

```bash
curl -X GET "https://metabase-alliance.up.railway.app/api/dashboard" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq '.data[] | {id, name}'
```

### Create a New Question (Card)

To create a new question/card in Metabase:

```bash
curl -X POST "https://metabase-alliance.up.railway.app/api/card" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My New Question",
    "display": "scalar",
    "description": "Optional description",
    "collection_id": 109,
    "database_id": 2,
    "dataset_query": {
      "type": "native",
      "native": {
        "query": "SELECT COUNT(*) AS total FROM my_table",
        "template-tags": {}
      },
      "database": 2
    },
    "visualization_settings": {}
  }' > /tmp/new_card.json

# Get the new card ID
cat /tmp/new_card.json | jq '.id'
```

**With Parameters:**
```bash
curl -X POST "https://metabase-alliance.up.railway.app/api/card" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Question with Parameters",
    "display": "table",
    "collection_id": 109,
    "database_id": 2,
    "dataset_query": {
      "type": "native",
      "native": {
        "query": "SELECT * FROM users [[WHERE created_at > {{start_date}}]]",
        "template-tags": {
          "start_date": {
            "type": "date",
            "name": "start_date",
            "id": "some-uuid-here",
            "display-name": "Start Date"
          }
        }
      },
      "database": 2
    },
    "visualization_settings": {}
  }' > /tmp/new_card_with_params.json
```

**Display Types:**
- `scalar` - Single number metric
- `table` - Data table
- `bar` - Bar chart
- `line` - Line chart
- `pie` - Pie chart
- `row` - Horizontal bar chart

### Add a Card to a Dashboard

**IMPORTANT**: There is NO direct endpoint like `/api/dashboard/{id}/cards` or `/api/dashboard/{id}/dashcard`.

Instead, you must use **PUT /api/dashboard/{id}** with the full dashboard structure including all existing and new cards.

**Step-by-step Process:**

1. **GET the current dashboard** to retrieve all existing cards
2. **Add your new card** to the `dashcards` array with a temporary negative ID (e.g., `-1`)
3. **PUT the updated dashboard** back with all cards

```bash
# Step 1: Get current dashboard
curl -s -X GET "https://metabase-alliance.up.railway.app/api/dashboard/60" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" > /tmp/dashboard.json

# Step 2: Add new card to dashcards array
cat /tmp/dashboard.json | jq '{
  name: .name,
  description: .description,
  archived: .archived,
  collection_id: .collection_id,
  enable_embedding: .enable_embedding,
  embedding_params: .embedding_params,
  cache_ttl: .cache_ttl,
  parameters: .parameters,
  auto_apply_filters: .auto_apply_filters,
  width: .width,
  tabs: .tabs,
  dashcards: (.dashcards + [{
    "id": -1,
    "card_id": 1128,
    "row": 0,
    "col": 12,
    "size_x": 6,
    "size_y": 3,
    "dashboard_tab_id": 23,
    "series": [],
    "parameter_mappings": [{
      "parameter_id": "7ce49db2",
      "card_id": 1128,
      "target": ["variable", ["template-tag", "demo_day_id"]]
    }],
    "visualization_settings": {},
    "action_id": null,
    "collection_authority_level": null
  }])
}' > /tmp/dashboard_update.json

# Step 3: PUT the updated dashboard
curl -s -X PUT "https://metabase-alliance.up.railway.app/api/dashboard/60" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d @/tmp/dashboard_update.json > /tmp/dashboard_result.json

# Verify
cat /tmp/dashboard_result.json | jq '{dashcard_count: (.dashcards | length)}'
```

**Key Notes for Adding Cards:**
- **id**: Use a temporary negative ID (e.g., `-1`) for new cards. Metabase will assign a real ID.
- **card_id**: The question ID you want to add
- **row/col**: Position on dashboard (0-based grid)
- **size_x/size_y**: Width and height in grid units
- **dashboard_tab_id**: The tab ID (from dashboard.tabs array)
- **parameter_mappings**: Maps dashboard parameters to card parameters
  - `parameter_id`: Dashboard parameter ID (from dashboard.parameters)
  - `card_id`: Question ID being added
  - `target`: `["variable", ["template-tag", "param_name"]]` where param_name matches the question's template-tag

**Dashboard Grid Layout:**
- Width: Usually 24 columns (when `width: "fixed"`)
- Row 0: First row
- Common scalar card size: `size_x: 6, size_y: 3`
- Common table size: `size_x: 24, size_y: 10-15`

**Example Card Positions:**
```
Row 0: [Card A (6x3)] [Card B (6x3)] [Card C (6x3)] [Card D (6x3)]
       col 0-5        col 6-11        col 12-17       col 18-23

Row 3: [Large Table Card (24x10)]
       col 0-23
```

### Get Database Schema

```bash
curl -X GET "https://metabase-alliance.up.railway.app/api/database/{DATABASE_ID}/metadata" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq '.'
```

## Database Reference

| ID | Name | Engine |
|----|------|--------|
| 2 | Alliance Web App | PostgreSQL |
| 3 | BigQuery | BigQuery Cloud SDK |

### BigQuery PostHog Tables (database 3, schema `posthog`)

| Table | Key Columns |
|-------|-------------|
| `event` | `project_id`, `event`, `timestamp`, `distinct_id`, `properties_email`, `properties_current_url`, `properties_pathname`, `person_properties` |
| `person` | Person profiles |
| `session` | Session data |
| `project` | Project metadata (`id`, `name`) |

### PostHog Project IDs

| ID | Name |
|----|------|
| 33209 | Website Production |
| 36472 | Website Staging |
| 38942 | Space Production |
| 38943 | Space Staging |

| 116544 | Sprint |

### Known Data Freshness Issue

The Fivetran sync from PostHog to BigQuery **stopped syncing around 2025-01-29**. BigQuery PostHog data is stale. For recent data, query the PostHog API directly (see the `posthog` skill).

## Extracting Question IDs from URLs

Metabase question URLs follow this pattern:
```
https://metabase-alliance.up.railway.app/question/{QUESTION_ID}-{QUESTION_SLUG}?param1=value1
```

**Example**:
- URL: `https://metabase-alliance.up.railway.app/question/947-portfolio-report-fii-iii?date=2025-03-31&fund=FUND%20II`
- Question ID: `947`

## Key API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/card` | GET | List all questions |
| `/api/card` | POST | Create a new question |
| `/api/card/{id}` | GET | Get question details |
| `/api/card/{id}` | PUT | Update a question |
| `/api/card/{id}/query` | POST | Execute a question (returns JSON) |
| `/api/card/{id}/query/csv` | POST | Execute a question (returns CSV) |
| `/api/dashboard` | GET | List all dashboards |
| `/api/dashboard/{id}` | GET | Get dashboard details |
| `/api/dashboard/{id}` | PUT | Update dashboard (use to add/remove cards) |
| `/api/database/{id}/metadata` | GET | Get database schema |
| `/api/collection` | GET | List collections |
| `/api/table/{id}` | GET | Get table metadata |

**Note**: There is NO `/api/dashboard/{id}/cards` or `/api/dashboard/{id}/dashcard` endpoint. To add cards to a dashboard, use PUT `/api/dashboard/{id}` with the full dashboard structure.

## Response Structure

### Question (Card) Response

```json
{
  "id": 947,
  "name": "Portfolio Report FII-III",
  "description": "...",
  "dataset_query": {
    "type": "native",
    "native": {
      "query": "SELECT ...",
      "template-tags": {
        "date": {"type": "date"},
        "fund": {"type": "text"}
      }
    },
    "database": 1
  },
  "display": "table",
  "visualization_settings": {...}
}
```

## Result Comparison Techniques

After modifying a SQL query, use these commands to verify results haven't changed:

```bash
# 1. Compare row counts
wc -l /tmp/baseline_results.csv /tmp/modified_results.csv

# 2. Compare MD5 checksums (quickest way to verify identity)
md5sum /tmp/baseline_results.csv /tmp/modified_results.csv

# 3. Quick diff check (returns nothing if identical)
diff -q /tmp/baseline_results.csv /tmp/modified_results.csv

# 4. Show actual differences (if any)
diff /tmp/baseline_results.csv /tmp/modified_results.csv | head -50

# 5. Compare specific columns or rows
# Compare first 10 data rows
head -11 /tmp/baseline_results.csv | diff - <(head -11 /tmp/modified_results.csv)

# 6. Advanced: Compare sorted results (useful for order-independent comparisons)
diff <(sort /tmp/baseline_results.csv) <(sort /tmp/modified_results.csv)
```

### Interpreting Comparison Results

| Result | Meaning | Action |
|--------|---------|--------|
| **Identical MD5** | ✅ Results are byte-for-byte identical | Safe to deploy |
| **Different row count** | ❌ Query returns different number of rows | **STOP** - Logic changed |
| **Same count, different MD5** | ⚠️ Data values changed | Review differences carefully |
| **Different order only** | ⚠️ Sort order changed | Verify if order matters |

## Useful jq Filters

```bash
# Extract SQL query
jq -r '.dataset_query.native.query'

# Extract parameters
jq -r '.dataset_query.native["template-tags"] | keys[]'

# Extract question name and ID
jq '{id, name, description}'

# Extract all table names from schema
jq -r '.tables[].name'
```

## Tips

1. **Always specify the account**: Use `--account defialliancellc.1password.com` when retrieving credentials
2. **Use jq for parsing**: Pipe curl output through jq for easier JSON handling
3. **Save queries to files**: For large SQL queries, save them to `.sql` files for easier editing
4. **Check parameters**: Use `.dataset_query.native["template-tags"]` to see required parameters
5. **Export formatted SQL**: Use `jq -r` to get raw string output without quotes

## Error Handling

### Common API Errors

- **401 Unauthorized**: Check API key is correct and valid
- **404 Not Found**: Verify question/dashboard ID exists
- **400 Bad Request**: Check parameter format and types match template tags
- **"API endpoint does not exist."**: Endpoint doesn't exist or method is wrong

### ⚠️ CRITICAL: Always Save API Responses Before Parsing with jq

**Problem**: When piping curl output directly to jq, you'll get cryptic errors if the API returns plain text instead of JSON:
```
jq: parse error: Invalid numeric literal at EOF at line 1, column 15
```

This happens when:
- API returns plain text like `"Unauthenticated"` or `"API endpoint does not exist."`
- API returns HTML error pages
- Request fails before returning JSON

**Solution**: Always save the response to a file first, then check it before parsing:

```bash
# ❌ BAD: Direct piping can fail with cryptic errors
curl -X GET "https://metabase-alliance.up.railway.app/api/card/123" \
  -H "X-API-Key: ${API_KEY}" | jq '.name'

# ✅ GOOD: Save first, then parse
curl -X GET "https://metabase-alliance.up.railway.app/api/card/123" \
  -H "X-API-Key: ${API_KEY}" > /tmp/response.json

cat /tmp/response.json | jq '.name'
# or check raw response first:
cat /tmp/response.json
```

This way you can see the actual error message before jq tries to parse it.

## Security Notes

- API key is stored securely in 1Password
- Never commit API keys to git
- Always use the `--account` flag to specify the correct 1Password account
- API key format: `mb_*` (Metabase API key prefix)

## Official Documentation

**When in doubt, always refer to the official Metabase API documentation:**

🔗 **[Metabase API Documentation](https://www.metabase.com/docs/latest/api)**

The official docs provide:
- Complete API endpoint reference
- Request/response schemas
- Authentication methods
- Advanced query options
- Troubleshooting guides

### Quick Links

- [API Introduction](https://www.metabase.com/docs/latest/api/getting-started)
- [Card (Question) API](https://www.metabase.com/docs/latest/api/card)
- [Dashboard API](https://www.metabase.com/docs/latest/api/dashboard)
- [Database API](https://www.metabase.com/docs/latest/api/database)
- [Collection API](https://www.metabase.com/docs/latest/api/collection)
