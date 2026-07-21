# How to Run Portfolio Report Comparison

## Security Notice

**IMPORTANT**: When working with the Metabase API:
- Retrieve the API key using: `API_KEY=$(op read "op://Private/52pjp46bnyr2ncfknfonvhju3y/credential" --account defialliancellc.1password.com)`
- **NEVER print the API_KEY or inspect its full value**
- If you absolutely need to verify it, you may ONLY check the first 5 characters
- Never log, echo, or expose the API key in any output

## Quick Steps

1. **Set up API credentials** (if needed for API access)
   ```bash
   API_KEY=$(op read "op://Private/52pjp46bnyr2ncfknfonvhju3y/credential" --account defialliancellc.1password.com)
   ```

2. **Run the updated query in Metabase**
   - Go to Metabase question 947
   - Parameters: `date=2025-03-31`, `fund=FUND II`
   - Download results as CSV to `/tmp/actual.csv`

3. **Run the comparison**
   ```bash
   python .agents/skills/metabase-api/compare-portfolio-reports.py /tmp/expected.csv /tmp/actual.csv
   ```

4. **Review the output**
   - The script will show missing/extra tickers
   - It will highlight rows with value differences (>5% tolerance)
   - Only compares columns present in BOTH files

## Expected Results

After the two fixes applied:
- **CHIBI_TOKEN 1**: Should be MISSING from actual (dissolved on 2025-03-31)
- **CLIQUE_EQUITY 1**: Should have `unit_market_price` ≈ 2.4895

## Columns Being Compared

The expected CSV has these columns:
- entity_name
- ticker
- quantity
- unit_cost
- unit_market_price

The actual Metabase output should have these plus additional calculated fields (base1, native1, etc.). The comparison script will only compare the common columns.

## Files

- **Expected data**: `/tmp/expected.csv` (129 rows including header)
- **Actual data**: Download from Metabase to `/tmp/actual.csv`
- **Comparison script**: `.agents/skills/metabase-api/compare-portfolio-reports.py`
- **Updated SQL**: `packages/imdb/src/metabase/portfolio-report.sql`

## Important Notes

- The expected CSV includes CHIBI_TOKEN 1, but the actual report should NOT (it was dissolved)
- This is expected - the comparison script will report it as "Missing in actual"
- Tolerance is 5% for numeric comparisons
- The script matches rows by ticker only
