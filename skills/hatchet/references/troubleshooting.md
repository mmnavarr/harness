# Hatchet troubleshooting

Use this when setup fails, the CLI connects to the wrong URL, DNS fails, or token/profile metadata looks stale.

## Route checks

Check API reachability:

```bash
curl http://railway-monorepo:11744/api/v1/health
```

Expected body:

```text
null
```

If DNS fails, use tsmesh to inspect live routes:

```bash
$HOME/go/bin/tsmesh services --project alliance-monorepo
$HOME/go/bin/tsmesh lookup --project alliance-monorepo --service Hatchet
```

The known Hatchet UI/API route is `railway-monorepo:11744`, targeting `hatchet.railway.internal:8888`.

## CLI profile gotchas

Hatchet CLI profiles are token-derived. A token contains claims for:

- API server URL (`server_url`)
- gRPC broadcast address (`grpc_broadcast_address`)
- tenant id (`sub`)
- expiration (`exp`)

If `hatchet profile add` or later commands try to connect to an internal, old, or unreachable URL, run CLI commands with explicit environment overrides:

```bash
HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744 \
HATCHET_CLIENT_TLS_STRATEGY=none \
hatchet runs list --profile railway-monorepo --output json --since 24h
```

Do not solve this by printing or decoding the token in chat. If decoding is needed locally, redact sensitive fields before reporting.

## Common symptoms

| Symptom | Likely cause | Fix |
|---|---|---|
| `unknown command "login"` | Hatchet CLI has no login command | Use `hatchet profile add --token ...` |
| `No profiles configured` | CLI has no saved profile | Add `railway-monorepo` profile using injected token |
| API route returns login page at `/` | Normal UI behavior | Use `/api/v1/health` for health checks |
| CLI points at wrong API host | Token embedded stale/internal `server_url` | Use `HATCHET_CLIENT_SERVER_URL=http://railway-monorepo:11744` override |
| Worker fails while REST commands work | gRPC engine endpoint not reachable from laptop | Export/tunnel engine port or run worker inside Railway |
| TLS/gRPC errors | Local Hatchet engine endpoint is plaintext | Use `HATCHET_CLIENT_TLS_STRATEGY=none` |

## Mutating actions

Commands such as cancel, replay, trigger, cron edits, and rate-limit changes can affect production workflows. Before running them, state the impact and get explicit user confirmation unless the user already asked for that exact mutation.
