# Hatchet CLI Agent Skills

This skill package teaches AI agents how to use the Hatchet CLI to manage workflows, workers, and runs.

## When to use these skills

Read the relevant reference document before performing any Hatchet CLI task:

- **Setting up the CLI or creating a profile** → `references/setup-cli.md`
- **Starting a worker** → `references/start-worker.md`
- **Triggering a workflow and waiting for results** → `references/trigger-and-watch.md`
- **Debugging a failed or stuck run** → `references/debug-run.md`
- **Replaying a run with the same or new input** → `references/replay-run.md`

## Key conventions

- Always specify a profile with `-p HATCHET_PROFILE` unless a default profile is set.
- Use `-o json` for machine-readable output when parsing responses.
- Create workflow input files with `mktemp` and remove them with a `trap` (see `references/trigger-and-watch.md`); never use predictable temp filenames.
- Confirm the target profile/environment with the user before mutating commands (trigger, replay, cancel) outside local development.
- Never put a literal API token on a command line; expand it from an environment variable (see `references/setup-cli.md`).
