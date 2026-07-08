---
name: cloudflare-access-railway-gating
description: Use when moving Railway-hosted services from public .up.railway.app URLs to Cloudflare Access-gated domains through Cloudflare Tunnels, including per-project connectors, private origins, Access apps, DNS, and ingress configuration.
tags: [cloudflare, railway, access, tunnel, zero-trust, devops]
---

# Gate Railway Services with Cloudflare Access + Tunnels

## When to Use
- Moving Railway services from public `.up.railway.app` URLs to Cloudflare Access-gated domains
- Setting up zero-trust access for internal tools hosted on Railway
- Adding a new service to an existing Cloudflare tunnel

## Architecture
```
User → CF Access (auth) → CF Tunnel → cloudflared (Railway service) → target.railway.internal:PORT
```

Each Railway **project** needs its own tunnel + cloudflared connector service. Multiple services within a project share the same tunnel.

## Prerequisites
- Cloudflare zone (e.g., `alliancetools.xyz`) with API token
- Railway project with running services
- An existing CF Access reusable policy (or create one)

## Current Infrastructure (Apr 2026)
| Project | Tunnel Name | Tunnel ID | Services Gated |
|---------|------------|-----------|----------------|
| Internal Tools | internal-tools | ee65dae9 | Infisical (2222), Symphony (4000), interactive-notebooks (8001), N8N-Primary (5678), Metabase (3000), Aria (3456), Uptime-Kuma (2244), Langfuse-Web (3000), LiteLLM (4000), Conductor (4005) |
| Automations | automations | 56ea41c5 | Scout (3200), Scout-Queues/QueueDash (3301), Scout-Bucket/MinIO-Console (9090), hubspot-ai (3101) |
| Alliance Monorepo | alliance-monorepo | 3816d34a | Admin (8080, Next.js), BullMQ (8080) |

- Reusable SSO policy: `493e3d65-d1df-4be2-99df-0852a82273bb` ("Application SSO alliancemail.com" — @alliancemail.com + infrastructure@defialliance.co), 24h session
- hubspot-ai BULLQUEUE_URL → `http://tailscale-gateway.railway.internal:11862/add-job` (cross-project via Tailscale bridge)
- Zone: `alliancetools.xyz`
- Webhook/API bypass path guidance: `n8n.alliancetools.xyz/webhook` + `/webhook-test`, `hubspot.alliancetools.xyz/webhook`, and Metabase Slack paths `metabase.alliancetools.xyz/api/metabot/slack/*`, `/auth/sso/slack-connect`, and `/auth/sso/slack-connect/callback`. Verify the live Cloudflare Access apps before treating this list as current deployment state.
- App Launcher: `alliancexyz.cloudflareaccess.com`

## Step-by-Step

### 1. Create Cloudflare Tunnel (one per Railway project)

```javascript
// Via Cloudflare MCP
cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/cfd_tunnel`,
  body: {
    name: "project-name",
    config_src: "cloudflare",  // managed via dashboard/API, not local YAML
    tunnel_secret: btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))),
  },
});
```

Then get the tunnel token:
```javascript
cloudflare.request({ method: "GET", path: `/accounts/${accountId}/cfd_tunnel/${tunnelId}/token` });
```

### 2. Deploy cloudflared Connector on Railway

Create a service in the Railway project:
```graphql
mutation {
  serviceCreate(input: {
    projectId: "PROJECT_ID"
    name: "Cloudflared"
    source: { image: "cloudflare/cloudflared" }
    variables: { TUNNEL_TOKEN: "eyJ..." }
  }) { id name }
}
```

Set the start command:
```graphql
mutation {
  serviceInstanceUpdate(
    environmentId: "ENV_ID"
    serviceId: "SERVICE_ID"
    input: { startCommand: "cloudflared tunnel --no-autoupdate run" }
  )
}
```

**Important:** The service may need a redeploy after creation for the tunnel to connect properly. Verify tunnel status shows connections in Cloudflare API.

### 3. Configure Target Service on Railway

For each service to gate:

**a) Set bind address variables (skip deploys until all changes are done):**
```graphql
mutation {
  variableCollectionUpsert(input: {
    projectId: "PROJECT_ID", environmentId: "ENV_ID", serviceId: "SERVICE_ID"
    variables: { HOST: "::" }
    skipDeploys: true
  })
}
```

**b) Remove the public Railway domain:**
```graphql
# First find the domain ID via service.serviceInstances.edges[].node.domains.serviceDomains
mutation { serviceDomainDelete(id: "DOMAIN_ID") }
```

**c) Update any app URL variables** to the new CF Access domain (e.g., BASE_URL, WEBHOOK_URL, etc.)

**d) Trigger redeploy** after all variable changes are made.

### 4. Cloudflare: Access App + DNS + Tunnel Ingress

Do all three in one pass:

**a) Create Access application** with reusable policy:
```javascript
cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/access/apps`,
  body: {
    type: "self_hosted",
    name: "App Name",
    domain: "app.example.xyz",
    destinations: [{ type: "public", uri: "app.example.xyz" }],
    session_duration: "24h",
    app_launcher_visible: true,
    http_only_cookie_attribute: true,
    policies: [{ id: "REUSABLE_POLICY_ID", precedence: 1 }],
  },
});
```

**b) Create DNS CNAME** (proxied):
```javascript
cloudflare.request({
  method: "POST",
  path: `/zones/${zoneId}/dns_records`,
  body: {
    type: "CNAME",
    name: "app.example.xyz",
    content: `${tunnelId}.cfargotunnel.com`,
    proxied: true, ttl: 1,
  },
});
```

**c) Update tunnel ingress** (PUT replaces entire config — include ALL existing routes):
```javascript
cloudflare.request({
  method: "PUT",
  path: `/accounts/${accountId}/cfd_tunnel/${tunnelId}/configurations`,
  body: {
    config: {
      ingress: [
        { hostname: "app.example.xyz", service: "http://private-domain.railway.internal:PORT", originRequest: {} },
        // ... other existing routes ...
        { service: "http_status:404" },  // catch-all MUST be last
      ],
      "warp-routing": { enabled: false },
    },
  },
});
```

Cloudflared picks up config changes live — no redeploy needed.

### 5. Verify

- `curl -sI https://app.example.xyz` should return **302** redirect to `cloudflareaccess.com` login
- Check cloudflared logs for tunnel errors (connection refused = wrong port or bind address)

## Access Gating Strategies: UI-Only vs Root-Domain

CF Access has a **hard limit of ~4 destinations per Access app**. This constrains which strategy to use.

### Strategy 1: Gate root domain, bypass specific paths (few API routes)
Best for services where the UI IS the root domain and only a few webhook paths need bypassing (e.g., N8N, HubSpot AI). Gate the root domain, then create small bypass apps for webhook paths.

```javascript
// Gate root domain
cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/access/apps`,
  body: {
    type: "self_hosted",
    name: "App Name",
    domain: "app.alliancetools.xyz",
    destinations: [{ type: "public", uri: "app.alliancetools.xyz" }],
    session_duration: "24h",
    app_launcher_visible: true,
    policies: [{ id: "REUSABLE_POLICY_ID", precedence: 1 }],
  },
});

// Bypass webhook paths (more-specific path apps take precedence)
cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/access/apps`,
  body: {
    type: "self_hosted",
    name: "App Webhooks (Bypass)",
    domain: "app.alliancetools.xyz/webhook",
    destinations: [
      { type: "public", uri: "app.alliancetools.xyz/webhook" },
      { type: "public", uri: "app.alliancetools.xyz/webhook-test" },
    ],
    session_duration: "24h",
    policies: [{
      name: "Bypass",
      decision: "bypass",
      include: [{ everyone: {} }],
      precedence: 1,
    }],
  },
});
```

### Strategy 2: Gate only UI path, leave API open (many API routes) ⭐
Best for API-heavy services where the UI is a small subset of routes and the service has its own API auth (API keys, tokens). Gate ONLY the UI paths — everything else passes through ungated. The service's own auth layer protects API routes.

**Use this for**: LiteLLM, API gateways, services with 10+ API route prefixes.

**Why not the bypass approach?** With ~4 destinations per bypass app and 100+ API route prefixes (LiteLLM has `/v1`, `/config`, `/key`, `/model`, `/spend`, `/budget`, `/customer`, etc.), you'd need 25+ bypass apps. Instead, flip the logic.

```javascript
// Gate ONLY the UI paths (everything else is open, protected by service's own API auth)
cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/access/apps`,
  body: {
    type: "self_hosted",
    name: "LiteLLM",
    domain: "litellm.alliancetools.xyz/ui",
    destinations: [
      { type: "public", uri: "litellm.alliancetools.xyz/ui" },
      { type: "public", uri: "litellm.alliancetools.xyz/sso" },
      { type: "public", uri: "litellm.alliancetools.xyz/login" },
      { type: "public", uri: "litellm.alliancetools.xyz/onboarding" },
    ],
    session_duration: "24h",
    app_launcher_visible: true,
    http_only_cookie_attribute: true,
    policies: [{ id: "REUSABLE_POLICY_ID", precedence: 1 }],
  },
});
```

**Result:** `/ui` → 302 CF Access login. `/v1/models` → 401 (LiteLLM API key auth). `/config/update` → reaches origin directly.

### Verification for both strategies
```bash
# Strategy 1: root gated, webhooks bypassed
curl -sI https://app.alliancetools.xyz           # → 302 (SSO)
curl -sI https://app.alliancetools.xyz/webhook    # → reaches origin

# Strategy 2: UI gated, API open
curl -sI https://app.alliancetools.xyz/ui         # → 302 (SSO)  
curl -sI https://app.alliancetools.xyz/v1/models  # → reaches origin (401 from app's own auth)
curl -sI https://app.alliancetools.xyz/config/update  # → reaches origin
```

## Cross-Project Communication on Railway

Railway projects have **isolated private networks** — `*.railway.internal` only resolves within the same project. This was **empirically validated in Apr 2026** with real tests showing cross-project DNS resolution fails from within Railway containers.

### What Does NOT Work

**Cloudflare WARP Connector** (site-to-site): Requires system-level kernel networking (iptables, ip route). Railway containers don't expose this. Also IPv4-only — Railway is IPv6 (`fd12:...`). WARP Connector does not support IPv6 routes per Cloudflare docs.

**Tailscale Subnet Router for service-to-service cross-project**: While the subnet router deploys fine and advertises routes, **Railway's DNS is project-scoped** — `*.railway.internal` queries only return results for services in the querying service's own project. A service in Project A cannot resolve hostnames in Project B, even with subnet routers in both projects. This was tested and confirmed in both directions. The DNS resolver at `fd12::10` is per-project, not global.

### Tailscale for Laptop-to-Railway Access

Tailscale subnet routers work for **laptop/phone → Railway private service** access, but they do **not** solve service-to-service cross-project DNS. Use `tailscale-railway-networking` for subnet-router deployment, route approval, split DNS, and gateway operations.

**Validated Apr 2026**:
```
Your Laptop (Tailscale client)
  ↓ WireGuard via tailnet
Tailscale Subnet Router (in Railway Project A)
  ↓ Railway private network
postgres.railway.internal:5432  works from your laptop

Service in Project A → postgres-xyz.railway.internal (Project B) → DNS fails
```

Railway's official subnet-router guide: https://docs.railway.com/guides/set-up-a-tailscale-subnet-router

### Cross-Project Patterns (for service-to-service)

| Approach | Best for | Latency | Complexity | Protocol |
|---|---|---|---|---|
| **Railway public TCP proxy** (`proxy.rlwy.net:PORT`) | Database access across projects | ✅ Low | ✅ Simplest | Any TCP |
| **HTTP API + CF Access Service Token** | App-to-app API calls through existing tunnels | ⚠️ Medium (CF edge hop) | ⚠️ Medium | HTTP only |
| **Consolidate into one project** | Tightly coupled services | ✅ Lowest | ✅ Simple | All (private network) |

**Railway Public TCP Proxy (databases)**
Railway can expose databases via `xxx.proxy.rlwy.net:PORT`. The DB has password auth — it's not "open." For Postgres/MySQL with strong credentials, this is standard practice and the simplest cross-project database solution.

**HTTP API + Service Token (app-to-app)**
Uses your existing CF tunnel infrastructure. Create a CF Access Service Token (docs: https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/), then the calling service includes headers:
```
CF-Access-Client-Id: <id>
CF-Access-Client-Secret: <secret>
```
The request goes through the `alliancetools.xyz` domain → CF Access (service token auth) → tunnel → target service. No SSO flow needed for machine-to-machine.

**Consolidate**
If Service A heavily depends on Database B, they belong in the same Railway project. Railway private networking is fast, free, and transparent within a project.

## Access Service Tokens (Machine-to-Machine / Agent Bypass)

Service tokens let scripts, agents, and services bypass CF Access SSO via headers. Create at the **account level** so one token works across all apps.

### Create a Service Token
```javascript
cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/access/service_tokens`,
  body: {
    name: "Alliance API Access",
    duration: "8760h"  // 1 year
  }
});
// Response includes client_id and client_secret — save the secret immediately, CF won't show it again
```

### Add Service Auth Policy to All Access Apps (Bulk)
Each Access app needs a `non_identity` policy to accept service tokens. Add in bulk:

```javascript
// For each self_hosted Access app:
// 1. GET existing policies to find max precedence
const policiesResp = await cloudflare.request({
  method: "GET",
  path: `/accounts/${accountId}/access/apps/${app.id}/policies`
});

// 2. Check if service auth already exists
const hasServiceAuth = policiesResp.result?.some(p => p.decision === 'non_identity');
if (hasServiceAuth) continue;

// 3. Create with unique precedence (max + 1)
const maxPrec = Math.max(...policiesResp.result.map(p => p.precedence || 0), 0);
await cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/access/apps/${app.id}/policies`,
  body: {
    name: "Service Token Auth",
    decision: "non_identity",
    precedence: maxPrec + 1,
    include: [{ "any_valid_service_token": {} }]
  }
});
```

**⚠️ Pitfall: Precedence must be unique per app.** Using `precedence: 1` will fail with `policy precedences must be unique` if the app already has a policy at that precedence. Always read existing policies first and pick `max + 1`.

### Usage Headers
```bash
curl -H "CF-Access-Client-Id: <id>.access" \
     -H "CF-Access-Client-Secret: <secret>" \
     https://app.alliancetools.xyz/api/endpoint
```

The `any_valid_service_token` include rule means ANY valid service token can bypass — not just a specific one. To restrict to a specific token, use `{ "service_token": { "token_id": "<token-uuid>" } }` instead.

### Existing Tokens (Apr 2026)
| Token Name | Purpose |
|---|---|
| Hermes Agent | Agent container automated access |
| Alliance API Access | General programmatic / agent access |

## Cross-Project Communication

Railway projects have **isolated private networks** — `*.railway.internal` only resolves within the same project/environment. Isolation is at the WireGuard level, not just DNS. Use `tailscale-railway-networking` for Tailscale subnet-router and gateway details, and `tsmesh` for Alliance's client-side CLI workflow.

**Quick reference for cross-project patterns:**
- **Database access**: Use Railway's public TCP proxy (`metro.proxy.rlwy.net:PORT`)
- **HTTP API-to-API**: Use CF Access Service Tokens (machine-to-machine auth through existing tunnels) — docs: https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/
- **Tightly coupled services**: Consolidate into one Railway project
- **Laptop-to-Railway private access**: Deploy a Tailscale subnet router per project using `tailscale-railway-networking`; use the `tsmesh` skill for tailnet/device operations

## Debugging OAuth/Webhook Integrations Behind CF Access

When an OAuth flow or webhook integration isn't working behind CF Access, follow this systematic approach:

### Step 1: Test if the bypass is actually working
```bash
# A CF Access block shows as 302 redirect to cloudflareaccess.com:
curl -sI https://app.alliancetools.xyz/api/webhook | head -5
# HTTP/2 302  location: https://xxx.cloudflareaccess.com/cdn-cgi/access/login/...

# A working bypass shows the origin server's response (any status except 302 to CF):
curl -sI https://app.alliancetools.xyz/api/webhook | head -5
# HTTP/2 401  x-metabase-version: v0.60.1.1  ← origin server headers = bypass works
```

**Key indicator:** Look for `x-*` headers from the origin app or status codes like 401/400/404 from the app itself. A `302` to `cloudflareaccess.com` means the bypass isn't working.

### Step 2: Identify ALL paths in the flow (not just the obvious ones)
OAuth flows typically have **multiple legs**. Read the app's source code to map them all:

| Flow Step | Example Path | Who Hits It |
|-----------|-------------|-------------|
| **Initiate** | `/auth/sso/provider` | User's browser (sets state cookie) |
| **Consent** | `provider.com/oauth/authorize` | Browser redirect (external) |
| **Callback** | `/auth/sso/provider/callback` | Browser redirect from provider |
| **Token exchange** | `/api/session/sso` | App backend (server-to-server) |

**Common miss:** Only bypassing the callback but not the initiate endpoint. The initiate step often sets a CSRF/state cookie that the callback validates.

### Step 3: Distinguish CF Access issues from app-level auth issues
Once you confirm the bypass works (step 1), the remaining errors are from the **application itself**:

- `401 "Account linking requires an authenticated session"` → App expects a logged-in user session (cookie not sent or not valid)
- `400 "OIDC state cookie is invalid, expired, or missing"` → OAuth flow was initiated from the wrong place (state cookie never set)
- `503 "Integration not fully configured"` → App-level config issue (missing secrets, etc.)

### Step 4: Check cookie propagation
When CF Access is bypassed for specific paths, cookies set on CF Access-gated paths (like `metabase.SESSION`) should still be sent on bypassed paths **because they share the same domain**. But verify:

- **SameSite attribute**: `Lax` cookies are sent on top-level navigations (GET redirects) — fine for OAuth callbacks. `Strict` cookies are NOT sent on cross-site redirects from OAuth providers.
- **Path attribute**: Cookies with `path=/` are sent on all paths. Cookies with specific paths only on matching paths.
- **The OIDC state cookie flow**: If the app uses a state cookie (e.g., `metabase.OIDC_STATE`), the **initiate** endpoint sets it and the **callback** reads it. If the user starts the OAuth flow from the external provider's site (not the app), the state cookie is never set → callback fails.

### Example: Metabase Metabot + Slack (Apr 2026)

Paths that need bypassing for the Slack integration:
```
/api/metabot/slack/commands      ← Slack slash commands
/api/metabot/slack/events        ← Slack event subscriptions  
/api/metabot/slack/interactive   ← Slack interactivity
/auth/sso/slack-connect          ← OAuth flow initiation (sets OIDC state cookie)
/auth/sso/slack-connect/callback ← OAuth callback (validates state cookie)
```

**Gotcha**: The Slack app install flow (from `api.slack.com/apps`) redirects directly to the callback, bypassing the initiate endpoint. The OIDC state cookie is never set, causing "OIDC state cookie is invalid" errors. The user must start the flow **from within Metabase** (which hits `/auth/sso/slack-connect` first) for the state cookie to be set.

**Gotcha**: `link-only` auth mode (default) requires the user to be logged into Metabase first. If the session cookie isn't sent on the bypassed path, the initiate endpoint returns 401.

## Critical Pitfalls

### Port Detection
- **Never assume the port.** Check deploy logs for the actual listening port.
- Railway auto-assigns ports (often 8080) when no `PORT` env var is set.
- The tunnel ingress must match the actual listening port, not a guessed default.
- Run `grep -i "listen\|local:\|port" deploy_logs` to find it.

### Bind Address — Framework-Specific
| Framework | Env Var for Bind Address | Default |
|-----------|------------------------|---------| 
| **Next.js 15** | `HOSTNAME=0.0.0.0` | `localhost` (breaks tunnel!) |
| **Node/Express** | `HOST=::` or `HOST=0.0.0.0` | varies |
| **Phoenix/Elixir** | Do NOT set `PORT` — let Railway auto-detect | 4000 |
| **General** | `HOST=::` | varies |

**Next.js 15 uses `HOSTNAME`, NOT `HOST`.** Setting `HOST=::` does nothing for Next.js. If the cloudflared logs show "connection refused", this is usually the cause.

**Phoenix/Elixir apps** may break (healthcheck fails) if you set `PORT` explicitly. Leave PORT unset and let Railway auto-detect. The tunnel addresses the service by private domain + port directly.

### Railway IPv6 Private Networking — Critical Dual-Stack Issue
Railway private networking (`*.railway.internal`) resolves to **IPv6 only** (`fd12:...` addresses). Railway containers have `net.ipv6.bindv6only=1`, meaning binding to `::` does **NOT** enable dual-stack — it only listens on IPv6.

**Impact:** Railway healthchecks use IPv4, so services bound to `::` only will **fail healthchecks** even though the app is running. Meanwhile, services bound to `0.0.0.0` pass healthchecks but cloudflared can't reach them (IPv6 connection refused).

**Language-specific dual-stack behavior on Railway:**
| Runtime | Binding to `::` | Dual-stack? |
|---------|-----------------|-------------|
| **Go** (e.g., MinIO, MinIO Console) | ✅ Works | Yes — Go handles dual-stack correctly |
| **Elixir/BEAM** (e.g., Phoenix) | ✅ Works | Yes — BEAM handles dual-stack correctly |
| **Python** (uvicorn, gunicorn) | ❌ IPv6 only | No — fails Railway IPv4 healthcheck |
| **Node.js** (Express, etc.) | ❌ IPv6 only | No — fails Railway IPv4 healthcheck |

**Fix for Python/Node.js — IPv6→IPv4 TCP Proxy:**
Bind the app to `0.0.0.0:APP_PORT` (passes healthcheck), then run a Python TCP proxy that listens on `[::]:PROXY_PORT` and forwards to `127.0.0.1:APP_PORT`. Point cloudflared tunnel ingress to `PROXY_PORT`.

Example startCommand pattern:
```bash
python3 -c "
import socket,threading
def fwd(s,d):
 try:
  while b:=s.recv(65536):d.sendall(b)
 except:pass
 finally:s.close();d.close()
srv=socket.socket(socket.AF_INET6,socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
srv.bind(('::',PROXY_PORT));srv.listen(128)
while True:
 c,_=srv.accept();b=socket.socket(socket.AF_INET,socket.SOCK_STREAM);b.connect(('127.0.0.1',APP_PORT))
 threading.Thread(target=fwd,args=(c,b),daemon=True).start();threading.Thread(target=fwd,args=(b,c),daemon=True).start()
" &
actual-app-start-command --host 0.0.0.0 --port APP_PORT
```

Then update tunnel ingress to route to `http://service.railway.internal:PROXY_PORT`.

**Disabling healthchecks:** Set `healthcheckPath: null` (not empty string `""`) via `serviceInstanceUpdate` mutation. This is useful for Go/Elixir services bound to `::` that don't need the proxy workaround.

**Tunnel-only Python/Node.js services (no public Railway domain):** If the service ONLY needs to be reachable via the CF tunnel (no public `.up.railway.app` domain), the simplest approach is `HOST=::` + `healthcheckPath: null`. Cloudflared (Go) connects via IPv6 natively, so it reaches the service fine. Railway's IPv4 healthcheck is the only thing that breaks, and disabling it is safe since the tunnel handles connectivity. The socat dual-stack proxy is only needed when you need BOTH a public Railway domain AND tunnel access on the same service. Example: LiteLLM with `HOST=::`, `PORT=4000`, healthcheck disabled — cloudflared reaches `litellm.railway.internal:4000` over IPv6 without issues.

### Railway Domain Deletion Lock
- `serviceDomainDelete` can return "operation already in progress" during/after deploys
- Wait for deploy to complete, then retry
- If persistently stuck, verify via `service.serviceInstances.edges[].node.domains.serviceDomains` — it may already be empty
- The `RAILWAY_PUBLIC_DOMAIN` variable disappearing confirms the domain is actually removed

### Uptime-Kuma 2.x Stuck Migration
If Uptime-Kuma fails with `Aggregate table migration is already in progress`:
```sh
# Fix via Railway startCommand (temporarily):
sh -c 'sqlite3 /data/kuma.db "DELETE FROM setting WHERE key='"'"'migrateAggregateTableState'"'"';" && sqlite3 /data/kuma.db "UPDATE knex_migrations_lock SET is_locked=0;" && node server/server.js'
```
Remove the custom startCommand after migration succeeds.

### URL Variables to Update
When migrating a service, search its variables for any referencing the old public URL:
- `BASE_URL`, `WEBHOOK_URL`, `SITE_URL`
- `*_AUTH_URL`, `*_PUBLIC_*_URL`
- `CYRUS_BASE_URL`, `N8N_EDITOR_BASE_URL`, etc.
- `RAILWAY_SERVICE_*_URL` vars are auto-generated by Railway and not critical

### Tunnel Ingress Config
- `PUT` replaces the entire config — always include ALL existing routes
- The catch-all `{ service: "http_status:404" }` MUST be the last entry
- Use `GET /cfd_tunnel/{id}/configurations` to read current config before updating
