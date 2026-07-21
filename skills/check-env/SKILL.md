---
name: check-env
description: Compare app env vars against Railway deployment to find missing variables
---

# Check Environment Variables

Compare required environment variables from an app's `env.ts` against what's configured in Railway.

## Arguments

`/check-env [app-name]`

- `app-name` (optional): The app to check (e.g., `admin`, `webapp`, `bullqueue`, `website`)
- If not provided, infer from current working directory or ask the user

## How to Execute

### Step 1: Determine the App

If app name not provided:
1. Check if cwd is inside an app directory (e.g., `apps/admin`)
2. If not, ask the user which app to check from: `admin`, `webapp`, `bullqueue`, `website`

### Step 2: Read Required Variables

Read the app's env.ts. Common locations:
- `apps/{app-name}/env.ts` (admin, website)
- `apps/{app-name}/src/env.ts` (bullqueue, webapp)

If unsure, search with `find apps/{app-name} -name env.ts`.

Extract:
- All server variables (required, no defaults = must be in Railway)
- All client variables
- Note which have defaults (less critical if missing)

### Step 3: Get Railway Variables

Run the skill's bundled script to fetch the configured variable names for the target app.
This returns a JSON array of key names (values are not fetched, saving tokens).

```bash
.agents/skills/check-env/get-railway-vars.sh <app-name>
```

The script handles the service-ID mapping internally. It requires the `railway` CLI to be
authenticated (`railway whoami` should succeed).

### Step 4: Output Table

Print a markdown table comparing required vs configured:

```
## Environment Variables: {app-name}

| Variable | Required | In Railway | Has Default | Status |
|----------|----------|------------|-------------|--------|
| DATABASE_URL | ✅ Yes | ✅ Set | ❌ | ✅ OK |
| SOME_VAR | ✅ Yes | ❌ Missing | ❌ | ❌ MISSING |
| OPTIONAL_VAR | ✅ Yes | ❌ Missing | ✅ Yes | ⚠️ Using default |

### Summary
- ✅ X variables configured correctly
- ⚠️ X variables using defaults
- ❌ X variables missing (will cause runtime errors)
```

## Status Logic

- `✅ OK` - Variable is set in Railway
- `⚠️ Using default` - Not in Railway but has a default value
- `❌ MISSING` - Not in Railway and no default (will fail at runtime)

## Example Usage

```
/check-env admin
/check-env webapp
/check-env
```
