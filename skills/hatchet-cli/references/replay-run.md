# Replay a Hatchet Run

These are instructions for an AI agent to replay a previously executed Hatchet run, optionally with modified input. Follow each step in order.

> **Replaying re-executes side effects.** Both replay and re-trigger create a brand-new run of the task code — emails, database writes, and external API calls happen again. Before Step 2, run `hatchet profile list`, confirm which tenant/environment `HATCHET_PROFILE` targets and that `RUN_ID` is the run you mean, and get explicit user approval unless the workflow is idempotent and targets local development.

## Step 1: Inspect the Original Run

First, understand what happened in the original run:

```bash
hatchet runs get RUN_ID -o json -p HATCHET_PROFILE
```

From the response, note:

- `.run.displayName` -- the workflow name (needed if re-triggering with new input)
- `.run.input` -- the original input JSON
- `.run.status` -- why you might be replaying (e.g. `FAILED`)
- `.tasks[].status` and `.tasks[].errorMessage` -- which specific tasks failed and why

## Step 2a: Replay with the Same Input

If you want to re-run the exact same workflow with the same input (e.g. after fixing a bug in the task code):

```bash
hatchet runs replay RUN_ID -o json -p HATCHET_PROFILE
```

This creates a new run of the same workflow with the same input. The response includes the new run IDs in `.ids[]`.

## Step 2b: Replay with New Input

If you need to change the input (e.g. fixing bad input data), you must trigger a new run instead of using replay:

Create a private temp file with `mktemp` (unique name, `0600` permissions) and install a `trap` so the file is removed even if a later step fails. Replay input may contain sensitive data from the original run, so never use a predictable filename:

```bash
HATCHET_INPUT_FILE=$(mktemp "${TMPDIR:-/tmp}/hatchet-input.XXXXXX")
trap 'rm -f "$HATCHET_INPUT_FILE"' EXIT
cat > "$HATCHET_INPUT_FILE" << 'ENDJSON'
NEW_INPUT_JSON
ENDJSON
```

Then trigger a fresh run using the workflow name from Step 1:

```bash
RUN_ID=$(hatchet trigger manual -w WORKFLOW_NAME -j "$HATCHET_INPUT_FILE" -p HATCHET_PROFILE -o json | jq -r '.runId')
```

The `trap` removes the temp file when your shell session exits; in a long-lived session, remove it earlier once the trigger has been accepted:

```bash
rm -f "$HATCHET_INPUT_FILE"
```

## Step 3: Watch the New Run

After either Step 2a or 2b, you have a new run ID. Poll for completion:

```bash
hatchet runs get <NEW_RUN_ID> -o json -p HATCHET_PROFILE
```

Check `.run.status` and `.tasks[].status` every 5 seconds until all reach a terminal state (`COMPLETED`, `FAILED`, `CANCELLED`).

If the new run also fails, use the debug instructions:

1. `hatchet runs logs <NEW_RUN_ID> -p HATCHET_PROFILE` for application logs
2. `hatchet runs events <NEW_RUN_ID> -o json -p HATCHET_PROFILE` for lifecycle events

## Common Replay Workflow

The typical flow when an agent is iterating on task code:

1. Trigger a run and it fails
2. Read the logs/events to understand why
3. Fix the code (the worker auto-reloads if `reload: true` in `hatchet.yaml`)
4. Replay the run with `hatchet runs replay RUN_ID -o json -p HATCHET_PROFILE`
5. If it fails again, repeat from step 2
