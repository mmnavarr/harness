---
name: tsmesh
description: Connect to Railway internal services (Postgres, Redis, Langfuse, etc.) via the Tailscale Railway Mesh CLI
---

# tsmesh — Tailscale Railway Mesh

`tsmesh` exposes Railway internal services over Tailscale so you can connect to production databases, Redis, Langfuse, and other services directly from the laptop without going through Railway's public TCP proxies.

## Safety Rules

1. **Read-only by default.** Use read-only credentials for database access unless a write is explicitly confirmed by the user.
2. **Never run destructive operations without explicit confirmation.** No `DELETE`, `DROP`, `TRUNCATE`, `FLUSHDB`, queue retries/flushes, or admin actions unless the user has confirmed.
3. **Do not paste query results containing PII or credentials** into external channels or logs.
4. **Treat Redis, Elasticsearch, Admin, and BullMQ as production mutable systems.** Accidental writes or job triggers can cause real user-visible effects.
5. **Do not write credentials to disk without secure permissions.** Prefer inline `$(op read ...)` substitution; if a temp file is needed use `mktemp` + `chmod 600` + a `trap` for cleanup.

## Installation

Check if tsmesh is installed:

```bash
$HOME/go/bin/tsmesh --version 2>/dev/null || echo "not installed"
```

If not installed:

```bash
# Ensure Go is available
which go || brew install go

# Configure SSH for private GitHub repo (persistent, all GitHub HTTPS URLs)
git config --global url."git@github.com:".insteadOf "https://github.com/" 2>/dev/null

# Set GOPRIVATE so the Go toolchain skips the public proxy for Alliancexyz modules
go env -w GOPRIVATE=github.com/Alliancexyz/*

# Install
go install github.com/Alliancexyz/tailscale-railway-mesh/cmd/tsmesh@latest
```

The binary lands at `$HOME/go/bin/tsmesh`. Add `$HOME/go/bin` to `PATH` if needed, or invoke as `$HOME/go/bin/tsmesh`.

## Gateway Config

The config lives at `~/.config/tailscale-railway-mesh/gateways.json`. It must exist before any tsmesh command will work. Check:

```bash
cat ~/.config/tailscale-railway-mesh/gateways.json
```

If missing, create it:

```bash
mkdir -p ~/.config/tailscale-railway-mesh
cat > ~/.config/tailscale-railway-mesh/gateways.json << 'EOF'
{
  "gateways": [
    {
      "project": "alliance-monorepo",
      "name": "Alliance Monorepo",
      "aliases": ["monorepo", "mr"],
      "url": "http://100.101.43.43:9090"
    },
    {
      "project": "automations",
      "name": "Automations",
      "aliases": ["a"],
      "url": "http://100.73.198.49:9090"
    },
    {
      "project": "internal-tools",
      "name": "Internal Tools",
      "aliases": ["internal tools", "it"],
      "url": "http://100.110.158.108:9090"
    }
  ]
}
EOF
```

> **Note**: The gateway IPs are the Tailscale peer IPs for each Railway project's tsmesh node. If a gateway becomes unreachable, run `tailscale status` to verify the peer IP hasn't changed and update this file.

## Common Commands

```bash
TSMESH=$HOME/go/bin/tsmesh

# List all projects/gateways
$TSMESH projects

# List all exported services for a project
$TSMESH services --project alliance-monorepo

# Look up the Tailscale URL for a service
$TSMESH lookup --project alliance-monorepo --service Postgres-Space
# → railway-monorepo:44846

# Look up the raw IP:port (useful for psql, redis-cli)
$TSMESH lookup --project alliance-monorepo --service Redis-Space --url ip
# → 100.101.43.43:11946
```

## Known Services

Run `$HOME/go/bin/tsmesh services --project alliance-monorepo` for the live list — IPs can change after Railway reprovisioning.

**Alliance Monorepo** exports: Postgres-Space, Redis-Space, BullMQ, Elasticsearch, Admin, Loki

**Internal Tools** (separate project/gateway): Langfuse-Web, Infisical, litellm — use `--project internal-tools`

## Connecting to Postgres-Space

Prefer inline credential substitution to avoid writing secrets to disk:

```bash
/opt/homebrew/opt/libpq/bin/psql "$(
  op read "op://Employee/ogbyajj73uwcimih5m4nnf5eue/connection_url" \
    --account defialliancellc.1password.com
)" -c "SELECT 1;"
```

If a temp file is needed for repeated queries in a session, use secure permissions and clean up:

```bash
TMPFILE=$(mktemp)
chmod 600 "$TMPFILE"
trap "rm -f $TMPFILE" EXIT
op read "op://Employee/ogbyajj73uwcimih5m4nnf5eue/connection_url" \
  --account defialliancellc.1password.com > "$TMPFILE"
/opt/homebrew/opt/libpq/bin/psql "$(cat "$TMPFILE")" -c "SELECT 1;"
```

## Connecting to Redis-Space

Use `REDISCLI_AUTH` to avoid exposing the password in process listings:

```bash
REDIS_IP=$($HOME/go/bin/tsmesh lookup --project alliance-monorepo --service Redis-Space --url ip)
REDIS_PASS=$(railway variables --service Redis-Space --json \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('REDISPASSWORD',''))")
REDISCLI_AUTH="$REDIS_PASS" redis-cli -h "${REDIS_IP%%:*}" -p "${REDIS_IP##*:}"
```

## Connecting to Langfuse

Langfuse lives in the **Internal Tools** Railway project (not Alliance Monorepo). See `.agents/skills/langfuse/SKILL.md` for the full auth flow; the key is pointing `LANGFUSE_BASE_URL` at the Internal Tools gateway instead of the Cloudflare-gated public domain.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `connection refused` on gateway URL | Tailscale not running or peer IP changed | Run `tailscale status`; update `gateways.json` if IP changed |
| `fatal: could not read Username` during install | HTTPS clone of private repo | Run `git config --global url."git@github.com:".insteadOf "https://github.com/"` and re-run |
| Module not found / proxy error during install | `GOPRIVATE` not set | Run `go env -w GOPRIVATE=github.com/Alliancexyz/*` and re-run |
| `--service is required` error | Missing `--service` flag on `lookup` | Add `--service <name>` |
| `--project is required` error | Multiple gateways configured, need to pick one | Add `--project alliance-monorepo` (or `mr`) |
| Binary not found in `PATH` | `$HOME/go/bin` not in shell PATH | Use full path `$HOME/go/bin/tsmesh` or add `export PATH="$HOME/go/bin:$PATH"` to shell profile |

## Maintenance

If something in this skill broke or felt out of date during a real session (changed gateway IP, new service, renamed project), follow the `skill-improve` protocol to propose updates instead of patching inline.
