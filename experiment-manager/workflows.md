# Workflows

## Create a New Experiment (End-to-End)

### 1. Create PostHog Experiment

Use `experiment-create` with:
- `name`: descriptive name with underscores (e.g., `tweet_41`, `one_week_acceptance_2`)
- `feature_flag_key`: same as name
- `parameters`: include variant keys — `["control", "test"]` for 2-variant, add `"test_2"`, `"test_3"` for more
- `filters`: Bayesian stats, 30% MDE
- `metrics`: Application Simple funnel

Standard create call:
```yaml
experiment-create:
  name: <experiment_name>
  feature_flag_key: <experiment_name>
  parameters:
    feature_flag_variants:
      - key: control
      - key: test
  metrics:
    - kind: ExperimentFunnelQuery
      name: Application Simple
      funnels_query:
        series:
          - event: $feature_view
          - event: application_started
        funnel_viz_type: steps
```

> Note: `$feature_view` as step 1 is intentional — it captures experiment exposure, and `application_started` as step 2 is the conversion event. This measures the conversion rate of exposed visitors only.

### 2. Set Custom Exposure Criteria

See [exposure-criteria.md](./exposure-criteria.md) for detailed Chrome-based steps.

### 3. Configure Prismic Content

See [prismic-setup.md](./prismic-setup.md) for navigation and editing details.

**For Type 2 experiments** (most common):
1. Find the target slice(s) using the Content API script
2. Set `experiment_id` on each variant item using the correct format (see [experiment-types.md](./experiment-types.md))
3. If the experiment affects multiple pages, configure all pages
4. Save (but don't publish yet — wait for launch step)

### 4. Wait for User to Request Launch

Do not launch or publish without explicit user confirmation.

---

## Launch an Experiment

Both steps must happen together:

1. **PostHog**: `experiment-update` with `start_date` set to the current ISO timestamp
   ```yaml
   experiment-update:
     id: <experiment_id>
     start_date: <ISO timestamp>  # e.g. 2026-04-01T00:00:00Z
   ```

2. **Prismic**: Publish all affected pages
   - Navigate to each page in the Prismic builder
   - Click "Publish"
   - If multiple pages are affected, publish all of them

---

## Check Experiment Status

Use `experiment-get` for a single experiment or `experiment-get-all` to list all.

Report:
- Status (draft / running / complete)
- Start date and duration
- Statistical significance and conclusion (if available)
- Feature flag state
- Variant traffic split

For detailed results: `experiment-results-get` with the experiment ID.

---

## Follow-Up Experiment (Iterate on a Winner)

When an experiment concludes and you want to test a new variant against the winner:

### 1. Find the Current Setup
Use the Content API script from [prismic-setup.md](./prismic-setup.md) to find existing experiment items.

### 2. Create New PostHog Experiment
- Append `_2`, `_3`, etc. to the name (e.g., `one_week_acceptance` → `one_week_acceptance_2`)
- Keep the same metric configuration

### 3. Update Prismic In-Place
- **Winner becomes new control**: Update the existing winner item's `experiment_id` to `<new_key>:control`
- **Add new variant items**: Create new items with `experiment_id` set to `<new_key>:test`, `<new_key>:test_2`, etc.
- **Remove old losing items**: Delete or clear the `experiment_id` on items from the previous experiment that lost

### 4. Set Exposure Criteria
Follow [exposure-criteria.md](./exposure-criteria.md) for the new flag key.

### 5. Launch
Follow the launch workflow above.

---

## Tweet Experiment

A specific pattern for testing different tweets on the homepage:

1. **Create PostHog experiment**: `tweet_<number>` naming
2. **Set exposure criteria**: `$feature/tweet_<number>`
3. **Find the tweets slice**: Use Content API script searching for the tweet slice in homepage
4. **Add tweet items**: Each variant tweet gets an `experiment_id` matching the flag key
5. **Launch**: PostHog update + Prismic publish

---

## Delete / Clean Up an Experiment

1. **PostHog**: `experiment-delete` with the experiment ID
2. **Prismic**: Remove or clear `experiment_id` fields from affected items, then publish
3. Optionally remove losing variant items from Prismic entirely

---

## Common Pitfalls

- **Forgetting Prismic setup**: Creating the PostHog experiment is only half the job. Always configure Prismic content too.
- **Forgetting multi-page experiments**: Some experiments affect more than one page. Check if the experiment content appears on multiple pages and configure all of them.
- **Wrong experiment_id format**: 2-variant uses bare key, 3+ variant uses `key:variant` suffix. Mixing these up breaks the experiment.
- **Publishing only one page**: If the experiment spans multiple pages, all must be published together.
- **Not setting exposure criteria**: Without custom `$feature_view` exposure, results are diluted by non-exposed visitors.
