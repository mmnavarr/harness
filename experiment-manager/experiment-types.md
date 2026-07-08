# Experiment Types

## Type 1 — Experiment Slice

**Mechanism**: An `experiment` slice in the page's slice zone points to a separate Prismic experiment document. That document holds variant slices.

**When to use**: Swapping entire content blocks (e.g., replacing a whole hero section).

**Prismic setup**:
1. Create an experiment document in Prismic with variant slices
2. Add an `experiment` slice to the target page's slice zone
3. Link the experiment slice to the experiment document

**Identifying in Prismic**: Look for slices with `slice_type: "experiment"` that reference an experiment document.

---

## Type 2 — experiment_id on Repeatable Items

**Mechanism**: Individual items within a slice's repeatable zone carry an `experiment_id` text field. The website code reads this field and shows/hides items based on the PostHog feature flag evaluation.

**When to use**: Testing individual items like tweets, text cards, links, or any repeatable slice item.

**Prismic setup**:
1. Find the target slice and its repeatable items
2. Set the `experiment_id` field on each item that participates in the experiment

**experiment_id format**:

| Variants | Control item | Test item | Additional variants |
|----------|-------------|-----------|-------------------|
| 2 variants | `<flag_key>` (bare key) | `<flag_key>` (bare key) | — |
| 3+ variants | `<flag_key>:control` | `<flag_key>:test` | `<flag_key>:test_2`, `test_3`, etc. |

**Why the format differs**: With 2 variants, both items share the bare flag key — the code uses the flag value (`control` vs `test`) to pick which to show. With 3+ variants, each item needs an explicit variant suffix so the code can match the flag value to the correct item.

**Identifying in Prismic**: Use the Content API script (see [prismic-setup.md](./prismic-setup.md)) to search for items with `experiment_id` containing the flag key.

---

## Type 3 — ExperimentVariant Component

**Mechanism**: The `ExperimentVariant` React component wraps inline content in the website code. It reads the PostHog flag at render time and shows the matching variant.

**When to use**: Inline text variants within components where Prismic content structure doesn't support the change (e.g., changing a heading string, swapping a CTA label).

**Setup**: Requires code changes in the website app — not a Prismic-only operation.

**Example**:
```tsx
<ExperimentVariant
  experimentId="my_experiment"
  variants={{
    control: <span>Original text</span>,
    test: <span>New text</span>,
  }}
/>
```
