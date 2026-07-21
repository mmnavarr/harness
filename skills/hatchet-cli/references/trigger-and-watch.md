# Trigger a Workflow and Watch for Completion

These are instructions for an AI agent to trigger a Hatchet workflow and poll until it completes. Follow each step in order.

## Prerequisites

- A Hatchet worker must be running (`hatchet worker dev -p HATCHET_PROFILE`). If no worker is running, the task will stay QUEUED forever.
- You must know the workflow name and have the input JSON ready.
- Confirm the target before triggering: run `hatchet profile list` and verify which tenant/environment `HATCHET_PROFILE` points at. Triggering runs real task code — emails, database writes, external API calls. Get explicit user approval before triggering against a shared environment (staging/production) or any non-idempotent workflow.
- Run all steps in the same shell session so `$HATCHET_INPUT_FILE`, `$RUN_ID`, and the cleanup `trap` stay in effect.

## Step 1: Write Input to a Temp File

Create a private temp file with `mktemp` (unique name, `0600` permissions, symlink-safe) and install a `trap` so the file is removed even if a later step fails:

```bash
HATCHET_INPUT_FILE=$(mktemp "${TMPDIR:-/tmp}/hatchet-input.XXXXXX")
trap 'rm -f "$HATCHET_INPUT_FILE"' EXIT
cat > "$HATCHET_INPUT_FILE" << 'ENDJSON'
INPUT_JSON
ENDJSON
```

Replace `INPUT_JSON` with the actual JSON payload for the workflow.

## Step 2: Trigger the Workflow

```bash
RUN_ID=$(hatchet trigger manual -w WORKFLOW_NAME -j "$HATCHET_INPUT_FILE" -p HATCHET_PROFILE -o json | jq -r '.runId')
```

The `-o json` flag makes the command output `{"runId": "...", "workflow": "..."}` to stdout. The command above captures the run ID directly into `$RUN_ID` for the next steps.

## Step 3: Poll for Completion

Run the following command every 5 seconds until the run reaches a terminal state:

```bash
hatchet runs get <RUN_ID> -o json -p HATCHET_PROFILE
```

Parse the JSON response and check the status:

- Look at `.run.status` for the overall run status and `.tasks[].status` for individual task statuses.
- Terminal statuses are: `COMPLETED`, `FAILED`, `CANCELLED`.
- Non-terminal statuses are: `QUEUED`, `RUNNING`. Keep polling if you see these.

## Step 4: Handle Failure

If the run status is `FAILED`, gather diagnostic information:

### Fetch logs

```bash
hatchet runs logs <RUN_ID> -p HATCHET_PROFILE
```

This prints application-level log output (e.g. print statements, logger calls from your task code). Look for error messages, stack traces, or unexpected output.

### Fetch events

```bash
hatchet runs events <RUN_ID> -o json -p HATCHET_PROFILE
```

This returns the lifecycle event log showing how the task was dispatched, started, and failed. Look at the `eventType` and `message` fields to understand the failure sequence.

## Step 5: Clean Up

The `trap` from Step 1 removes the input file when your shell session exits, even after a failure or interrupt. In a long-lived session, remove it earlier once the trigger has been accepted:

```bash
rm -f "$HATCHET_INPUT_FILE"
```

## Common Issues

- **Task stays QUEUED**: The worker is not running, or the workflow/task name does not match what the worker registered. Start or restart the worker.
- **Task FAILED immediately**: Check the logs for a stack trace. The task code likely threw an exception.
- **Task CANCELLED**: Something cancelled the run externally. Check events to see the cancellation source.
