# SQL Modification Checklist

**Use this checklist when modifying any Metabase SQL query to ensure safe, verified changes.**

## Pre-Modification Checklist

- [ ] Identified question ID from Metabase URL
- [ ] Retrieved API key from 1Password (`52pjp46bnyr2ncfknfonvhju3y`)
- [ ] Identified required query parameters (date, fund, etc.)
- [ ] Understood the scope of changes requested

## Workflow Steps

### Step 1: Capture Baseline ⚠️ CRITICAL

```bash
# Execute original query and save results
curl -X POST "https://metabase-alliance.up.railway.app/api/card/{QUESTION_ID}/query/csv" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": [
      {"type": "date/single", "target": ["variable", ["template-tag", "date"]], "value": "2025-03-31"},
      {"type": "category", "target": ["variable", ["template-tag", "fund"]], "value": "FUND II"}
    ]
  }' > /tmp/baseline_results.csv
```

**Checklist:**
- [ ] Baseline query executed successfully
- [ ] Results file created (`/tmp/baseline_results.csv`)
- [ ] File contains expected number of rows
- [ ] **IF BASELINE FAILS → STOP and ask user what to do**

### Step 2: Retrieve Original SQL

```bash
# Get current SQL query
curl -X GET "https://metabase-alliance.up.railway.app/api/card/{QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" | jq -r '.dataset_query.native.query' > original_query.sql
```

**Checklist:**
- [ ] SQL query retrieved successfully
- [ ] Saved to local file for reference

### Step 3: Make Modifications

```bash
# Edit the SQL in your local file
# Example: packages/imdb/src/portfolio-report.sql
```

**Checklist:**
- [ ] SQL modifications completed in local file
- [ ] Syntax validated (if possible)
- [ ] Changes reviewed and understood

### Step 4: Update Metabase Question

```bash
# Update the question in Metabase
API_KEY=$(cat /tmp/metabase_key.txt)
QUESTION_ID=947
NEW_SQL=$(cat packages/imdb/src/portfolio-report.sql)

curl -s -X GET "https://metabase-alliance.up.railway.app/api/card/${QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" | \
jq --arg sql "$NEW_SQL" '.dataset_query.native.query = $sql' | \
curl -X PUT "https://metabase-alliance.up.railway.app/api/card/${QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d @- | jq '{id, name, updated_at}'
```

**Checklist:**
- [ ] Update request succeeded
- [ ] Received confirmation with `updated_at` timestamp
- [ ] No API errors

### Step 5: Execute Modified Query

```bash
# Execute modified query with SAME parameters as baseline
curl -X POST "https://metabase-alliance.up.railway.app/api/card/{QUESTION_ID}/query/csv" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": [
      {"type": "date/single", "target": ["variable", ["template-tag", "date"]], "value": "2025-03-31"},
      {"type": "category", "target": ["variable", ["template-tag", "fund"]], "value": "FUND II"}
    ]
  }' > /tmp/modified_results.csv
```

**Checklist:**
- [ ] Modified query executed successfully
- [ ] Results file created (`/tmp/modified_results.csv`)
- [ ] No execution errors

### Step 6: Compare Results

```bash
# Compare row counts
echo "=== Row Counts ==="
wc -l /tmp/baseline_results.csv /tmp/modified_results.csv

# Compare checksums
echo "=== MD5 Checksums ==="
md5sum /tmp/baseline_results.csv /tmp/modified_results.csv

# Check for differences
echo "=== Difference Check ==="
diff -q /tmp/baseline_results.csv /tmp/modified_results.csv && \
  echo "✅ Files are IDENTICAL" || \
  echo "❌ Files DIFFER"
```

**Checklist:**
- [ ] Row counts match
- [ ] MD5 checksums match
- [ ] `diff` reports files are identical
- [ ] Sample data spot-checked

### Step 7: Report Results

**If Results Match (✅):**
- [ ] Confirmed modifications are safe
- [ ] Documented what was changed
- [ ] Reported success to user

**If Results Differ (❌):**
- [ ] Identified what changed
- [ ] Analyzed if changes are expected/desired
- [ ] Reported differences to user for review
- [ ] **If unexpected:** Consider reverting changes

## Emergency Rollback

If modifications cause problems:

```bash
# Revert to original SQL
curl -s -X GET "https://metabase-alliance.up.railway.app/api/card/${QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" | \
jq --arg sql "$(cat original_query.sql)" '.dataset_query.native.query = $sql' | \
curl -X PUT "https://metabase-alliance.up.railway.app/api/card/${QUESTION_ID}" \
  -H "X-API-Key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d @-
```

## Common Scenarios

### Scenario: Baseline Fails

**Action:**
1. Stop workflow immediately
2. Show error to user
3. Ask: "Baseline failed with: [ERROR]. Options: (1) Fix error first, (2) Proceed without baseline (risky), (3) Cancel"
4. Wait for user decision

### Scenario: Results Differ Unexpectedly

**Action:**
1. Show diff output (first 50 lines)
2. Identify which rows/columns changed
3. Ask user to review changes
4. Offer to rollback if needed

### Scenario: Update API Call Fails

**Action:**
1. Check API key validity
2. Verify question ID exists
3. Check for database constraint errors
4. Report error and ask user how to proceed

## Quick Reference

**Files to Keep:**
- `/tmp/baseline_results.csv` - Original query results
- `/tmp/modified_results.csv` - Modified query results
- `original_query.sql` - Backup of original SQL

**Key Commands:**
- **Baseline:** `curl POST /api/card/{ID}/query/csv`
- **Update:** `curl PUT /api/card/{ID}`
- **Compare:** `diff -q baseline.csv modified.csv`
- **Verify:** `md5sum baseline.csv modified.csv`
