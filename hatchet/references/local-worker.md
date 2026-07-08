# Local worker and gRPC behavior

Use this when the user asks to run a Hatchet worker locally, debug BullQueue's Hatchet worker, or understand why CLI inspection works while worker startup fails.

## Repo integration

The Alliance repo starts Hatchet workflows from BullQueue code:

- `apps/bullqueue/src/hatchet.ts`
- `apps/bullqueue/src/hatchetWorker.ts`
- `apps/bullqueue/src/workflows/`
- `apps/bullqueue/src/index.ts` — runtime entrypoint where the Hatchet worker is imported and started

There is no checked-in `hatchet.yaml` at the repo root, so `hatchet worker dev` is not the normal project entrypoint. Use the repo control plane for routine local app startup:

```bash
bun run dev up bullqueue
```

Only use `apps/bullqueue` raw scripts when intentionally bypassing the control plane for low-level debugging.

## gRPC endpoint distinction

`http://railway-monorepo:11744` is the frontend/API route. Workers need Hatchet engine gRPC.

Current project code hardcodes:

```text
hatchet.railway.internal:7077
```

with TLS strategy `none` by default. That internal hostname is available inside Railway's private network. A laptop can use it only if there is a tunnel/export for the gRPC engine port.

## Local worker endpoint shape

Current BullQueue code does not read `HATCHET_CLIENT_HOST_PORT`; `apps/bullqueue/src/hatchet.ts` hardcodes `hatchet.railway.internal:7077` and only reads the token and TLS strategy from env.

For local worker startup, the gRPC tunnel must preserve or alias this exact host and port:

```text
hatchet.railway.internal:7077
```

Keep `HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744` for CLI/API commands, and keep `HATCHET_CLIENT_TOKEN` injected through `fnox`/`mise`; do not paste it into shell history. If the tunnel exposes a different host or port, change `apps/bullqueue/src/hatchet.ts` to read a vetted env override before expecting `bun run dev up bullqueue` to use it.

## Diagnostic guidance

- If `hatchet runs list` works but worker startup fails, suspect gRPC reachability.
- If BullQueue starts but logs `HATCHET_CLIENT_TOKEN not set — skipping Hatchet worker`, set the token through `fnox` and restart through `mise`/the control plane.
- If production BullQueue fails to start Hatchet, inspect `apps/bullqueue/src/hatchet.ts`, Railway variables, and whether `hatchet.railway.internal:7077` changed.
