---
name: feature-flag-manager
description: "Create PostHog feature flags and apply (gate) them in code. Use this skill whenever the user wants to create a feature flag, roll out/roll back a flag, hide a page or feature behind a flag, or wire a boolean flag into the website/webapp. For experiment/A-B-test flags with control/test variants, use the experiment-manager skill instead — this skill is for plain boolean on/off flags."
---

# Feature Flag Manager

Create boolean PostHog feature flags and gate code behind them.

> **Scope note:** This skill covers **boolean** (on/off) flags. For variant A/B
> experiments (`control`/`test`/`test_2`...), use the **experiment-manager** skill —
> those go through the experiment APIs and need Prismic + exposure setup.

> **Status:** Work in progress. The PostHog-side creation steps and the website
> application pattern are documented and validated. Other apps (webapp, admin) are
> not yet covered.

## Quick reference

- **Website PostHog project**: `33209` — `https://us.posthog.com/project/33209/feature_flags/`
- **Naming**: use underscores, lowercase (e.g. `launches`, `new_pricing`) — keep the
  flag `key` and any code reference identical, including `_` vs `-`.
- **Default rollout**: create `active: true` but **0% rollout** so code can ship safely
  hidden; roll out later by bumping the percentage / adding release conditions in PostHog.

## Credentials / reaching PostHog

Authentication is the same as the **experiment-manager** skill — use the configured
**PostHog MCP** (project `33209`). See `.agents/skills/experiment-manager/SKILL.md`
§ "Tools". The MCP `feature-flag` domain handles flag create/read/update/delete.

If the MCP is unavailable, the raw PostHog REST API works as a fallback
(`POST /api/projects/33209/feature_flags/`) using the personal API key retrieved the
same way experiment-manager retrieves it.

## Workflows

### 1. Create a boolean feature flag

1. Check it doesn't already exist (search flags by key).
2. Create with:
   - `key`: the flag name (underscores, lowercase)
   - `name`: same as key (or a short human label)
   - `active`: `true`
   - `filters.groups`: a single group, `rollout_percentage: 0` (off for everyone)
3. Record the flag **id** and key; report the PostHog flag URL back to the user.

Raw-API shape (when not using MCP):
```json
{
  "key": "launches",
  "name": "launches",
  "active": true,
  "filters": { "groups": [ { "properties": [], "rollout_percentage": 0 } ] }
}
```

### 2. Apply (gate) the flag in code

See [applying-flags.md](./applying-flags.md) for the concrete website pattern
(server-side gate, route layout, local-dev override, and the boolean-vs-variant gotcha).

### 3. Roll out / roll back

- **Roll out**: in PostHog, raise `rollout_percentage` (or add release-condition groups
  targeting specific users/properties), keeping `active: true`.
- **Roll back**: set `rollout_percentage` to `0` (or `active: false`). Code stays put;
  only the flag changes.

## Common pitfalls

- **Boolean flag read as "control"**: the website's `shouldShowForExperiment()` helper is
  for variant experiments only. For a boolean flag use `isBooleanFlagEnabled()` — see
  [applying-flags.md](./applying-flags.md).
- **Key mismatch**: the PostHog `key` and the string used in code must match exactly,
  including `_` vs `-`.
- **Forgetting the flag is off by default**: a 0%-rollout flag returns false/undefined for
  everyone until you roll it out — expected, not a bug.
