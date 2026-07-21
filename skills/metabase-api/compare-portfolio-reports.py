#!/usr/bin/env python3
"""
Compare Metabase portfolio report output with expected CSV from Google Sheets.

Usage:
  python compare-portfolio-reports.py <expected.csv> <actual.csv>

The script will:
1. Load both CSV files
2. Filter out strikethrough lines from expected (if marked)
3. Match rows by ticker
4. Compare numerical values with tolerance
5. Report differences
"""

import csv
import sys
from decimal import Decimal, InvalidOperation


def parse_number(value):
    """Parse a number string, handling various formats."""
    if not value or value.strip() == '':
        return None
    try:
        # Remove commas and convert to Decimal for precise comparison
        clean_value = value.replace(',', '').strip()
        return Decimal(clean_value)
    except (InvalidOperation, ValueError):
        return None


def load_csv(filepath, skip_strikethrough=False):
    """Load CSV file and return dict keyed by ticker."""
    rows = {}
    with open(filepath, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ticker = row.get('ticker', '').strip()
            if not ticker:
                continue

            # Skip if marked as strikethrough (you can add column check here)
            if skip_strikethrough and row.get('strikethrough', '').lower() == 'true':
                continue

            rows[ticker] = row

    return rows


def compare_values(expected_val, actual_val, tolerance=0.05):
    """Compare two numeric values with tolerance (default 5%)."""
    exp = parse_number(str(expected_val))
    act = parse_number(str(actual_val))

    if exp is None and act is None:
        return True, 0
    if exp is None or act is None:
        return False, float('inf')

    diff = abs(exp - act)
    rel_diff = diff / abs(exp) if exp != 0 else diff

    return rel_diff <= Decimal(str(tolerance)), float(rel_diff)


def main():
    if len(sys.argv) != 3:
        print("Usage: python compare-portfolio-reports.py <expected.csv> <actual.csv>")
        sys.exit(1)

    expected_file = sys.argv[1]
    actual_file = sys.argv[2]

    print(f"Loading expected data from: {expected_file}")
    expected = load_csv(expected_file, skip_strikethrough=True)

    print(f"Loading actual data from: {actual_file}")
    actual = load_csv(actual_file)

    print(f"\nExpected rows: {len(expected)}")
    print(f"Actual rows: {len(actual)}")

    # Compare
    print("\n" + "="*80)
    print("COMPARISON RESULTS")
    print("="*80)

    # Check for missing tickers
    missing_in_actual = set(expected.keys()) - set(actual.keys())
    missing_in_expected = set(actual.keys()) - set(expected.keys())

    if missing_in_actual:
        print(f"\n⚠️  Missing in actual ({len(missing_in_actual)}):")
        for ticker in sorted(missing_in_actual):
            print(f"  - {ticker}")

    if missing_in_expected:
        print(f"\n⚠️  Extra in actual ({len(missing_in_expected)}):")
        for ticker in sorted(missing_in_expected):
            print(f"  - {ticker}")

    # Compare matching rows
    print("\n" + "-"*80)
    print("VALUE DIFFERENCES (tolerance: 5%)")
    print("-"*80)

    numeric_columns = ['quantity', 'unit_cost', 'unit_market_price', 'base1', 'native1',
                      'base2', 'native2', 'base3', 'native3']

    differences = []
    for ticker in sorted(set(expected.keys()) & set(actual.keys())):
        exp_row = expected[ticker]
        act_row = actual[ticker]

        row_diffs = []
        for col in numeric_columns:
            if col not in exp_row or col not in act_row:
                continue

            matches, rel_diff = compare_values(exp_row[col], act_row[col], tolerance=0.05)
            if not matches:
                row_diffs.append({
                    'column': col,
                    'expected': exp_row[col],
                    'actual': act_row[col],
                    'rel_diff': rel_diff
                })

        if row_diffs:
            differences.append({
                'ticker': ticker,
                'entity': exp_row.get('entity_name', ''),
                'diffs': row_diffs
            })

    if differences:
        for item in differences:
            print(f"\n{item['entity']} - {item['ticker']}")
            for diff in item['diffs']:
                print(f"  {diff['column']:20s}: {diff['expected']:>15s} → {diff['actual']:>15s}  "
                      f"(diff: {diff['rel_diff']:.2%})")
    else:
        print("\n✅ All values match within tolerance!")

    print("\n" + "="*80)
    print(f"Summary: {len(differences)} rows with differences out of {len(set(expected.keys()) & set(actual.keys()))} compared")
    print("="*80)


if __name__ == '__main__':
    main()
