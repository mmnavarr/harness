---
name: hatchet
description: Use this skill whenever the user asks about Hatchet CLI, Hatchet runs/jobs/workflows, failed Hatchet jobs, the Hatchet TUI, or connecting to the Alliance Railway Hatchet instance at railway-monorepo:11744. It explains the project-specific tsmesh route, fnox/mise token setup, safe read-only defaults, and when local worker gRPC access is or is not available.
---

# Hatchet on Railway

Use this skill to connect the Hatchet CLI to the Alliance Hatchet deployment exposed through Tailscale Railway Mesh at `http://railway-monorepo:11744`.

## Project facts

- Hatchet UI/API through tsmesh: `http://railway-monorepo:11744`
- Current tsmesh export target: `hatchet.railway.internal:8888`
- BullQueue worker code uses Hatchet gRPC: `hatchet.railway.internal:7077`
- Local CLI inspection uses the UI/API URL; local worker execution also needs a reachable gRPC endpoint.
- The repo's BullQueue worker starts from `apps/bullqueue/src/hatchetWorker.ts`, not from a checked-in `hatchet.yaml`.

## Safety defaults

- Prefer read-only inspection first: list workflows, list failed runs, inspect one run.
- Do not cancel, replay, or trigger runs unless the user explicitly asks for that mutation.
- Never print or paste `HATCHET_CLIENT_TOKEN` into chat or logs.
- Prefer `fnox` + `mise` environment injection for token handling instead of copying secrets into shell history.

## Progressive references

Read only the reference you need:

| Need | Read |
|---|---|
| Initial CLI profile setup, token handling, routine commands | `references/cli-setup.md` |
| Local worker/gRPC behavior and repo integration | `references/local-worker.md` |
| Failures, stale token metadata, tsmesh/DNS issues | `references/troubleshooting.md` |

Before running the workflow, verify `hatchet --version` works and Tailscale/tsmesh can resolve `railway-monorepo`; read `references/cli-setup.md` for full preconditions.

## Standard workflow

1. Verify the mesh/API route if connection state is uncertain:
   ```bash
   curl http://railway-monorepo:11744/api/v1/health
   ```
   Expected body: `null`.

2. Ensure the user has stored the token with `fnox` if it is not already available:
   ```bash
   fnox set HATCHET_CLIENT_TOKEN -g --provider keychain
   ```
   The `-g` flag is optional. Use the keychain provider so the token is injected by the normal `mise`/`fnox` environment path without committing it or printing it.

3. Configure a Hatchet CLI profile through the injected token. If the token is not visible in the current shell, run the command through `mise exec` in a shell that expands the variable after mise injects it. Include the API/TLS overrides on `profile add` because the CLI validates the token against Hatchet before saving the profile:
   ```bash
   mise exec -- sh -c 'HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 HATCHET_CLIENT_TLS_STRATEGY=none hatchet profile add --name railway-monorepo --token "$HATCHET_CLIENT_TOKEN"'
   hatchet profile set-default --name railway-monorepo
   ```

4. Run read-only commands with explicit API/TLS overrides. The overrides make the CLI use the tsmesh API route even if the token embeds an internal or stale server URL:
   ```bash
   HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
   HATCHET_CLIENT_TLS_STRATEGY=none \
   hatchet runs list --profile railway-monorepo --output json --since 7d --status FAILED
   ```

5. Report what was checked, the command shape used, and the safe next action. Keep token values redacted.

## Useful read-only commands

```bash
HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet workflows list --profile railway-monorepo --output json

HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet runs list --profile railway-monorepo --output json --since 7d --status FAILED

HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet runs get <run-id> --profile railway-monorepo --output json

HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet tui --profile railway-monorepo
```

## Output format

For investigations, respond with:

```markdown
## Hatchet CLI status
- Route checked: ...
- Profile: ...
- Command run: ...

## Findings
- ...

## Next action
- ...
```
