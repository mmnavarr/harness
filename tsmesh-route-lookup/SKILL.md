---
name: tsmesh-route-lookup
description: Use this skill whenever a user asks for Tailscale Railway Mesh route information, service export URLs, import URLs, listener ports, gateway project routes, or questions like "what is our Tailscale export URL for service X?" Prefer the tsmesh CLI and /agent/* JSON endpoints over scraping the dashboard. This skill is especially relevant in this repository and for agents operating against deployed Tailscale Railway Mesh gateways.
---

# Tailscale Railway Mesh Route Lookup

Use this skill to answer route questions from Tailscale Railway Mesh gateways. The reliable interfaces are the `tsmesh` CLI and the `/agent/*` JSON endpoints. Avoid scraping `/dashboard`; it is for humans and can change visually without changing the machine contract.

## First Choice: tsmesh

Use the installed `tsmesh` binary when it is available locally:

```sh
tsmesh lookup --project "railway automations" --service hubspot-ai --direction export --url tailscale
```

For structured output:

```sh
tsmesh lookup --project "railway automations" --service hubspot-ai --direction export --url tailscale --json
```

When the user asks for a "Tailscale export URL," return the `tailscale` URL, for example:

```text
railway-automations:14548
```

## Gateway Config

`tsmesh` reads gateway locations from JSON. The default path is:

```text
~/.config/tailscale-railway-mesh/gateways.json
```

Override with `TSMESH_GATEWAYS_CONFIG` or `--config`.

Example config:

```json
{
  "gateways": [
    {
      "project": "automations",
      "name": "Automations",
      "aliases": ["railway automations", "railway-automations"],
      "url": "http://100.64.0.10:9090"
    }
  ]
}
```

Gateway URLs should stay private because they expose route metadata for operators and trusted agents.

## Common Commands

List configured projects:

```sh
tsmesh projects
```

List services for a project:

```sh
tsmesh services --project "railway automations"
```

List export routes only:

```sh
tsmesh services --project "railway automations" --direction export
```

Print a Railway internal app URL:

```sh
tsmesh lookup --project "railway automations" --service hubspot-ai --direction export --url internal
```

Print a peer target URL:

```sh
tsmesh lookup --project "railway automations" --service postgres --direction import --url target
```

## HTTP Endpoints

Use these read-only endpoints when calling a gateway directly:

| Endpoint | Purpose |
|---|---|
| `/agent/context` | Gateway identity, sync state, route counts, capabilities, and examples. |
| `/agent/routes` | Full export/import route inventory with agent-friendly URLs. |
| `/agent/lookup?service=<name>&direction=<export|import>` | Single-service route lookup. |

Example direct lookup:

```sh
curl 'http://100.64.0.10:9090/agent/lookup?service=hubspot-ai&direction=export'
```

Example response:

```json
{
  "ok": true,
  "query": {
    "service": "hubspot-ai",
    "direction": "export"
  },
  "gateway": {
    "project_name": "Automations",
    "hostname": "railway-automations",
    "tailscale_ip": "100.64.0.10"
  },
  "match": {
    "service": "hubspot-ai",
    "direction": "export",
    "port": 14548,
    "internal_url": "tailscale-gateway.railway.internal:14548",
    "tailscale_url": "railway-automations:14548",
    "ip_url": "100.64.0.10:14548",
    "target": "hubspot-ai.railway.internal:3100"
  }
}
```

## Matching Behavior

Lookup is designed for natural-language prompts:

- Exact case-insensitive service match wins first.
- Canonical match runs second, ignoring spaces, hyphens, underscores, and punctuation.
- Include `direction` when the user asks for exports or imports.
- Ambiguous matches return `multiple_matches` with `candidates`; do not guess silently.
- Missing matches return `not_found`.

`/agent/lookup` status codes:

| Status | Error | Meaning |
|---|---|---|
| `400` | `missing_service` | The `service` query parameter is empty. |
| `400` | `invalid_direction` | `direction` is not `export` or `import`. |
| `404` | `not_found` | No route matched the requested service and direction. |
| `409` | `multiple_matches` | Multiple routes matched; inspect `candidates` and ask the user or include `direction`. |

## URL Types

`tsmesh lookup --url` supports:

| Value | Meaning |
|---|---|
| `tailscale` | Tailscale hostname URL. Best answer for "Tailscale export URL." |
| `internal` | Railway internal gateway URL for apps inside the project. |
| `ip` | Tailscale IP URL. |
| `target` | Backend target host and port. |

If the user asks for a route in prose, answer with the narrowest useful value first, then mention project/service/direction only if it removes ambiguity.

## Safety

Do not include secrets in answers. Never print Tailscale auth keys, Railway API tokens, captured Railway variable files, or private route manifests in public outputs. Keep `/routes` and `/agent/*` data on trusted private networks.
