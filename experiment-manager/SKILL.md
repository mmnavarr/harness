---
name: experiment-manager
description: "Manage A/B test experiments end-to-end: create PostHog experiments, check their status/results, and configure them in Prismic CMS. Use this skill whenever the user mentions experiments, A/B tests, tweet tests, variant testing, PostHog experiments, or wants to set up, check, or modify any experiment on the website or apply page. Also use when they reference feature flags related to experiments, or ask about experiment results/conclusions."
---

# Experiment Manager

Full lifecycle management of A/B experiments across PostHog and Prismic CMS.

## Quick reference

- **PostHog project**: `33209` (PostHog → Project Settings → Project ID) — `https://us.posthog.com/project/33209/experiments/`
- **Homepage document**: `ZErWzRAAACoAyw6N` (Prismic → Homepage → document ID in URL) — `https://alliance.prismic.io/builder/pages/ZErWzRAAACoAyw6N`
- **Standard config**: Bayesian, 30% MDE, `$feature_view` custom exposure, Application Simple funnel metric
- **Naming**: always use underscores (`tweet_41`, not `tweet-41`)

## Three experiment types

| Type | Mechanism | Prismic setup | When to use |
|------|-----------|--------------|-------------|
| **Type 1** | Experiment slice → experiment document | Experiment document with variant slices | Swapping entire content blocks |
| **Type 2** | `experiment_id` field on slice items | Text field on repeatable items | Testing individual items (tweets, text cards, links) |
| **Type 3** | `ExperimentVariant` component | Code changes required | Inline text variants in components |

Details: [experiment-types.md](./experiment-types.md)

## Homepage structure

| Prismic tab | Slice zone | Theme |
|-------------|-----------|-------|
| Main | `slices` | Dark (hero) |
| Light Section | `slices1` | Light (middle) |
| Dark Section | `slices2` | Dark (footer) |

## Workflows

### Create an experiment

1. Create PostHog experiment via `experiment-create`
2. Set custom exposure criteria via Chrome — see [exposure-criteria.md](./exposure-criteria.md)
3. Configure Prismic content — see [prismic-setup.md](./prismic-setup.md)
4. Wait for user to request launch/publish

### Check experiment status

Use `experiment-get` or `experiment-get-all`. Report status, conclusion, dates, flag state, variant split.

### Iterate on a winner (follow-up experiment)

1. Find existing Prismic config — see [prismic-setup.md](./prismic-setup.md) § "Finding experiments"
2. Create new PostHog experiment (append `_2`, `_3`, etc.)
3. Update existing Prismic items in-place (winner → new control)
4. Add items for new variants
5. Set exposure criteria

Details: [workflows.md](./workflows.md)

### Launch and publish

Both must happen together:
1. **PostHog**: `experiment-update` with `start_date` set to current ISO timestamp
2. **Prismic**: Click "Publish" in the page editor via Chrome

## Tools

### PostHog MCP
> Requires: PostHog MCP configured in Claude Code settings (project ID `33209`, found in PostHog → Project Settings → Project ID)

`experiment-create`, `experiment-get`, `experiment-get-all`, `experiment-update`, `experiment-results-get`, `experiment-delete`

### Prismic
- **Local**: Prismic API skill at `.agents/skills/prismic-api/`
- **Cowork**: Chrome browser at `https://alliance.prismic.io`
