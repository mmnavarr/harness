---
name: tailscale-railway-networking
description: Use when setting up, operating, or debugging Tailscale networking for Railway services, including subnet routers, Railway private-network reachability, tsmesh gateways, tailnet route approval, split DNS, and cross-project connectivity decisions.
tags: [tailscale, railway, networking, tsmesh, devops]
required_environment_variables:
  - name: TAILSCALE_API_KEY
    prompt: Tailscale API key
    help: Tailscale API access for route approval, key-expiry changes, and DNS updates
    required_for: Tailnet admin API workflows
  - name: TAILSCALE_TAILNET
    prompt: Tailscale tailnet name
    help: Tailnet identifier used by the Tailscale API
    required_for: Tailnet admin API workflows
---

# Tailscale Networking on Railway

## Overview

Railway private networking is project-scoped. Tailscale is useful for laptop-to-Railway private access and explicit gateway patterns, but it does not make `*.railway.internal` DNS globally resolvable across Railway projects.

## When to Use

| Need | Use |
|---|---|
| Laptop or phone needs access to Railway private services | Tailscale subnet router per Railway project; use `tsmesh` for Alliance's client-side CLI workflow. |
| A Railway service needs to call a service in another Railway project | Do **not** rely on subnet-router DNS magic; use Cloudflare Access service tokens, a deliberate Tailscale gateway, Railway public TCP proxy, or project consolidation. |
| You need to expose selected Railway services to tailnet devices | Deploy a Railway `tailscale/tailscale` subnet router and approve advertised routes. |
| You need app SSO / public hostname gating | Use `cloudflare-access-railway-gating`, not this skill. |

## Railway Networking Facts

- Railway private DNS names like `service.railway.internal` resolve only inside the same Railway project/environment.
- Railway private addresses are IPv6 (`fd12::/16`), and Railway's DNS resolver at `fd12::10` is project-scoped.
- A Tailscale subnet router can advertise Railway private routes to the tailnet, but it does not make Project A resolve Project B's `*.railway.internal` names.
- Cross-project service-to-service calls need an explicit bridge or a different architecture; treat accidental reachability as a bug, not a design.

## What Does Not Work

### Cloudflare WARP Connector on Railway

WARP Connector needs kernel-level networking setup (`iptables`, routes, device management) that Railway containers do not expose. It is also a poor match for Railway's IPv6-only private network behavior.

### Subnet Routers for Service-to-Service DNS

A subnet router can help a laptop on the tailnet reach a Railway private address. It does not give one Railway project another project's private DNS view.

For service-to-service cross-project calls, choose one of these instead:

- Cloudflare Access service-token auth through an existing Access-gated hostname.
- A deliberate Tailscale gateway service that exports specific ports.
- Railway public TCP proxy for databases or other TCP services.
- Consolidating tightly coupled services into one Railway project.

## Deploy a Subnet Router on Railway

Railway's official guide is the baseline: https://docs.railway.com/guides/set-up-a-tailscale-subnet-router

The manual deployment shape is:

```graphql
mutation {
  serviceCreate(input: {
    projectId: "PROJECT_ID"
    name: "Tailscale Subnet Router"
    source: { image: "tailscale/tailscale:latest" }
    variables: {
      TS_AUTHKEY: "tskey-auth-xxxxx"
      TS_EXTRA_ARGS: "--advertise-routes=fd12::/16 --accept-routes"
      TS_STATE_DIR: "/var/lib/tailscale"
      TS_HOSTNAME: "railway-PROJECT-NAME"
    }
  }) { id name }
}
```

Environment variables:

- `TS_AUTHKEY` — reusable auth key from https://login.tailscale.com/admin/settings/keys.
- `TS_EXTRA_ARGS` — advertise Railway private routes and accept routes from the tailnet.
- `TS_STATE_DIR` — persistent state directory; mount a volume at `/var/lib/tailscale` if the project has volume capacity.
- `TS_HOSTNAME` — unique name per Railway project so devices are identifiable in the Tailscale admin UI.

Without a volume, a reusable auth key can re-register on redeploy, but the device identity may rotate. With a volume, state survives redeploys.

## Tailnet Admin Operations

Use the Tailscale admin UI or API to approve routes and configure DNS. Never paste API keys into transcripts or committed files.

List devices:

```bash
curl -s "https://api.tailscale.com/api/v2/tailnet/${TAILSCALE_TAILNET}/devices" \
  -H "Authorization: Bearer ${TAILSCALE_API_KEY}"
```

Approve the Railway route and disable key expiry on the subnet-router device:

```bash
curl -X POST "https://api.tailscale.com/api/v2/device/${DEVICE_ID}/routes" \
  -H "Authorization: Bearer ${TAILSCALE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"advertisedRoutes":["fd12::/16"],"enabledRoutes":["fd12::/16"]}'

curl -X POST "https://api.tailscale.com/api/v2/device/${DEVICE_ID}/key" \
  -H "Authorization: Bearer ${TAILSCALE_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"keyExpiryDisabled":true}'
```

Split DNS for `railway.internal` can point tailnet clients at Railway's resolver, but remember that resolver is scoped to the project where the subnet router runs.

## tsmesh Gateways

`tsmesh` is Alliance's client-side CLI for consuming Railway services through Tailscale gateway peers. Use the existing `tsmesh` skill for install, lookup, and laptop-side connection workflows.

Operationally:

- Each gateway peer has a Tailscale IP; verify it with `tailscale status` before trusting any cached value.
- Gateway exports are explicit host/port mappings, not broad network magic.
- If a gateway is redeployed and gets a new peer IP, update client gateway config and any documentation that hardcodes the old peer IP.
- Use gateway exports for intentional cross-project access; do not assume `*.railway.internal` names from another project will resolve.

## Verification

Expected subnet-router logs include:

```text
updated prefs ... routes=[fd12::/16]
Switching ipn state Starting -> Running
boot: Startup complete
```

Smoke test from a tailnet device:

1. Confirm the subnet-router device is online in Tailscale admin.
2. Confirm `fd12::/16` is approved for that device.
3. Confirm Tailscale DNS is active on the client.
4. Connect to a known service in that same Railway project using its private hostname or address.
5. If hostname lookup fails but direct IP works, debug split DNS before changing Railway or Cloudflare config.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Device appears online but private IPs fail | Route advertised but not approved | Approve `fd12::/16` for the subnet-router device. |
| IP works but `*.railway.internal` fails | Split DNS missing or querying the wrong project resolver | Configure tailnet DNS for the project resolver; verify same-project scope. |
| Service in another Railway project does not resolve | Expected Railway project isolation | Use service-token auth, gateway export, TCP proxy, or consolidate projects. |
| Subnet-router reappears as a new device after redeploy | Missing persistent state volume | Add volume at `/var/lib/tailscale` or tolerate reusable-key re-registration. |
| `tsmesh` connection refused | Gateway peer IP changed, gateway down, or export missing | Use `tailscale status`, update gateway config, and verify the gateway export. |
| Route approval API returns 401/403 | Bad Tailscale API key or tailnet | Regenerate key or verify `TAILSCALE_TAILNET`. |

## Safety Rules

- Tailscale reachability is not application authorization. Keep app auth, database auth, and Access policies intact.
- Restrict tailnet ACLs to the minimum users/devices that need private access.
- Treat auth keys and API keys as secrets; never commit them or paste full values into logs.
- Verify live peer IPs, exported ports, and routes before updating operational docs.

## Related Skills

- `tsmesh` — client-side CLI workflow for consuming Alliance Railway services over Tailscale.
- `cloudflare-access-railway-gating` — Cloudflare Access and Tunnel gating for Railway-hosted services.
- `cloudflare-access-tunnel` — general Access/Tunnel setup, path bypasses, webhooks, OAuth callbacks, and service-token patterns.
