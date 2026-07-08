---
name: cloudflare-access-tunnel
description: Use when protecting internal services behind Cloudflare Access with Tunnel routing, replacing public URLs with Access-gated endpoints, or configuring reusable policies, DNS CNAMEs, ingress routes, webhook bypasses, and OAuth callback bypasses.
tags: [cloudflare, access, tunnel, zero-trust, devops]
related_skills: []
---

# Cloudflare Access + Tunnel Setup

## When to Use
- Protecting internal services (Metabase, N8N, Grafana, etc.) behind Cloudflare Access SSO
- Replacing public URLs with Access-gated endpoints routed through Cloudflare Tunnels
- Setting up zero-trust access for services on Railway, Fly, or any private network

## Prerequisites
- Cloudflare account with a zone (domain) configured
- An existing Cloudflare Tunnel running (e.g., `cloudflared` as a sidecar service)
- MCP cloudflare tools available (`mcp_cloudflare_execute`, `mcp_cloudflare_search`)

## Architecture
```
User → <subdomain>.domain.com → CF Access (SSO check) → CF Tunnel → private-domain:port
```

## Step-by-Step

### 0. Triage Services

Not every service in a project needs Access gating. Categorize first:
- **Web UIs** (with public domains) → migrate to CF Access
- **Databases** (Postgres, Redis, etc.) → skip, TCP-only via internal networking or TCP proxy
- **Object storage APIs** (MinIO S3) → may only need domain removal, not Access gating (unless there's a console UI)
- **Background workers / cron jobs** (no public domain, no web port) → skip
- **Removed/inactive services** (deploy status `REMOVED`) → skip

Check each service's domains, variables (look for PORT, HOST, URL patterns), and latest deploy status before planning.

### 1. Gather Existing Config (Reference Pattern)

Always start by examining an existing working setup to replicate its pattern.

```javascript
// List existing Access apps
cloudflare.request({ method: "GET", path: `/accounts/${accountId}/access/apps` })

// Get tunnel and its config
cloudflare.request({ method: "GET", path: `/accounts/${accountId}/cfd_tunnel` })
cloudflare.request({ method: "GET", path: `/accounts/${accountId}/cfd_tunnel/${tunnelId}/configurations` })

// Get existing DNS records
cloudflare.request({ method: "GET", path: `/zones/${zoneId}/dns_records` })
```

Key things to note from the reference:
- **Reusable policy ID** — policies with `"reusable": true` can be shared across apps
- **Tunnel ID** — needed for CNAME target (`<tunnelId>.cfargotunnel.com`)
- **Ingress pattern** — `hostname` → `service` URL format

### 2. Prepare Services (Railway-specific)

For each service being migrated:
```graphql
# Set HOST=:: for IPv6 binding (required for Railway private networking + tunnel)
mutation {
  variableCollectionUpsert(input: {
    projectId: "...", environmentId: "...", serviceId: "..."
    variables: { HOST: "::" }
    skipDeploys: true
  })
}

# Remove public domain
mutation { serviceDomainDelete(id: "DOMAIN_ID") }

# Redeploy after all changes
mutation { serviceInstanceRedeploy(environmentId: "...", serviceId: "...") }
```

### 3. Create Access Applications

```javascript
// Create a self_hosted Access app with a reusable policy
cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/access/apps`,
  body: {
    type: "self_hosted",
    name: "My Service",
    domain: "myservice.domain.com",
    destinations: [{ type: "public", uri: "myservice.domain.com" }],
    session_duration: "24h",
    app_launcher_visible: true,
    auto_redirect_to_identity: false,
    http_only_cookie_attribute: true,
    policies: [{ id: "REUSABLE_POLICY_ID", precedence: 1 }],
  },
});
```

The reusable policy attaches automatically — no need to create per-app policies.

### 4. Create DNS CNAME Records

```javascript
cloudflare.request({
  method: "POST",
  path: `/zones/${zoneId}/dns_records`,
  body: {
    type: "CNAME",
    name: "myservice.domain.com",
    content: "<tunnelId>.cfargotunnel.com",
    proxied: true,  // MUST be proxied for Access to work
    ttl: 1,
  },
});
```

### 5. Update Tunnel Ingress Config

**IMPORTANT**: This is a full PUT — include ALL existing routes plus new ones, with catch-all last.

```javascript
cloudflare.request({
  method: "PUT",
  path: `/accounts/${accountId}/cfd_tunnel/${tunnelId}/configurations`,
  body: {
    config: {
      ingress: [
        // ALL existing routes
        { hostname: "existing.domain.com", service: "http://existing.internal:8080", originRequest: {} },
        // New routes
        { hostname: "myservice.domain.com", service: "http://myservice.internal:3000", originRequest: {} },
        // Catch-all MUST be last
        { service: "http_status:404" },
      ],
      "warp-routing": { enabled: false },
    },
  },
});
```

### 6. Verify

```bash
# Should return 302 redirect to cloudflareaccess.com login
curl -sI https://myservice.domain.com | head -3
```

### 7. Multi-Project Tunneling (Railway)

Each Railway project has its own isolated private network. A `cloudflared` connector in Project A **cannot** reach `*.railway.internal` addresses in Project B.

**⚠️ CRITICAL: Use a SEPARATE tunnel per Railway project.** Do NOT share a tunnel token across projects. If two connectors from different projects register under the same tunnel, Cloudflare load-balances requests across them randomly — a request for `scout.railway.internal:3200` could be routed to the Internal Tools connector, which can't resolve that hostname. This causes intermittent 502 errors.

#### Create a new tunnel for each project:

```javascript
// 1. Create a new tunnel with config_src: "cloudflare" for remote management
cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/cfd_tunnel`,
  body: {
    name: "project-name",  // e.g., "automations"
    config_src: "cloudflare",  // Manage via dashboard/API, not local YAML
    tunnel_secret: btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))),
  },
});
// Returns: { id, name }

// 2. Get the tunnel token (separate API call)
const tokenResp = await cloudflare.request({
  method: "GET",
  path: `/accounts/${accountId}/cfd_tunnel/${tunnelId}/token`,
});
// tokenResp.result is the base64 TUNNEL_TOKEN for cloudflared

// 2. Configure the new tunnel's ingress (only routes for THIS project's services)
cloudflare.request({
  method: "PUT",
  path: `/accounts/${accountId}/cfd_tunnel/${newTunnelId}/configurations`,
  body: { config: { ingress: [
    { hostname: "svc.domain.com", service: "http://svc.railway.internal:3000", originRequest: {} },
    { service: "http_status:404" },
  ], "warp-routing": { enabled: false } } },
});

// 3. Point DNS CNAMEs to the NEW tunnel ID
// <subdomain>.domain.com → <newTunnelId>.cfargotunnel.com (proxied)
```

#### Deploy cloudflared in the new project:

```graphql
# Create the service from Docker image
mutation {
  serviceCreate(input: {
    projectId: "TARGET_PROJECT_ID"
    name: "Cloudflared"
    source: { image: "cloudflare/cloudflared:latest" }
  }) { id name }
}

# Set the NEW tunnel's token
mutation {
  variableCollectionUpsert(input: {
    projectId: "...", environmentId: "...", serviceId: "NEW_SVC_ID"
    variables: { TUNNEL_TOKEN: "eyJ...<new tunnel token>" }
  })
}

# Set the start command
mutation {
  serviceInstanceUpdate(serviceId: "NEW_SVC_ID", input: {
    startCommand: "cloudflared tunnel --no-autoupdate run"
  })
}
```

**Verify**: Check `GET /accounts/{accountId}/cfd_tunnel/{newTunnelId}` — the `connections` array should show 4 connections (each `cloudflared` instance opens 4). Confirm the origin IP differs from the other project's tunnel connections.

### 8. Bypass Access for Webhook Paths

When a service behind Access needs to receive inbound webhooks (e.g., n8n from HubSpot, Stripe, etc.), external callers can't authenticate through Access. The solution is a **separate Access app** with path-scoped destinations and a `bypass` policy.

**Key insight**: Create a second Access app whose `destinations` use path prefixes (e.g., `domain.com/webhook`). Cloudflare matches the more specific path first, so the bypass app handles webhook traffic while the original app continues to protect the UI.

```javascript
// Create a bypass Access app for webhook paths
cloudflare.request({
  method: "POST",
  path: `/accounts/${accountId}/access/apps`,
  body: {
    type: "self_hosted",
    name: "My Service Webhooks (Bypass)",
    domain: "myservice.domain.com/webhook",  // Primary path
    destinations: [
      { type: "public", uri: "myservice.domain.com/webhook" },
      { type: "public", uri: "myservice.domain.com/webhook-test" }  // Optional: test paths
    ],
    session_duration: "24h",
    app_launcher_visible: false,  // Hide from app launcher
    auto_redirect_to_identity: false,
    http_only_cookie_attribute: true,
    policies: [
      {
        name: "Bypass Webhooks",
        decision: "bypass",
        precedence: 1,
        include: [{ everyone: {} }],
        exclude: [],
        require: []
      }
    ]
  }
});
```

**Verify**:
```bash
# Webhook path should return the origin response (no 302 redirect)
curl -sI https://myservice.domain.com/webhook/some-id | head -3
# UI should still redirect to Access login
curl -sI https://myservice.domain.com/ | head -3
```

**Notes**:
- No DNS or tunnel changes needed — the bypass app shares the same hostname, just scoped to paths
- The `destinations` URI supports paths and wildcards per [CF docs](https://developers.cloudflare.com/cloudflare-one/policies/access/app-paths/)
- There may be a brief propagation delay (~5 seconds) before the bypass takes effect
- For tighter security, use a `non_identity` policy with Service Tokens instead of `bypass` — but only if the caller can send `CF-Access-Client-Id` / `CF-Access-Client-Secret` headers (most SaaS webhooks like HubSpot cannot)

### Bypass for OAuth/SSO Callback Flows

**⚠️ CRITICAL: OAuth flows have TWO legs — you must bypass BOTH.** This is the #1 mistake when whitelisting OAuth callbacks.

The flow is:
1. **Initiate** → e.g. `/auth/sso/slack-connect` — sets OIDC state cookie in the browser, then redirects to the OAuth provider
2. **Callback** → e.g. `/auth/sso/slack-connect/callback` — the provider redirects back with `?code=...&state=...`

If you only bypass the callback (step 2) but NOT the initiate (step 1), the state cookie never gets set because step 1 gets intercepted by Cloudflare Access. The callback then fails with errors like "OIDC state cookie is invalid, expired, or missing."

**Example (Metabase Metabot Slack integration):**

The Slack app manifest defines these endpoints that ALL need bypassing:
```
/api/metabot/slack/commands      ← slash commands
/api/metabot/slack/events        ← event subscriptions
/api/metabot/slack/interactive   ← interactivity (buttons, modals)
/auth/sso/slack-connect          ← OAuth initiate (sets state cookie) ← EASY TO MISS
/auth/sso/slack-connect/callback ← OAuth callback (exchanges code for token)
```

**Debugging approach:** Test each path with `curl -sI https://domain/path` and check:
- `HTTP/2 302` + `location: https://*.cloudflareaccess.com/...` → **still behind Access** (needs bypass)
- `HTTP/2 4xx` + `x-metabase-version` (or other origin headers) → **bypass working**, origin is responding

```javascript
// Create bypasses for ALL OAuth flow paths
const paths = [
  { name: "App Slack Commands", path: "domain.com/api/metabot/slack/commands" },
  { name: "App Slack Events", path: "domain.com/api/metabot/slack/events" },
  { name: "App Slack Interactive", path: "domain.com/api/metabot/slack/interactive" },
  { name: "App Slack SSO Initiate", path: "domain.com/auth/sso/slack-connect" },
  { name: "App Slack SSO Callback", path: "domain.com/auth/sso/slack-connect/callback" }
];

for (const p of paths) {
  await cloudflare.request({
    method: "POST",
    path: `/accounts/${accountId}/access/apps`,
    body: {
      name: p.name,
      domain: p.path,
      type: "self_hosted",
      session_duration: "24h",
      policies: [{
        name: "Bypass - Everyone",
        decision: "bypass",
        precedence: 1,
        include: [{ everyone: {} }]
      }]
    }
  });
}
```

**After bypasses are confirmed working, always verify the backend response.** A `4xx` from the origin server (with origin headers like `x-metabase-version`) means the bypass works but the **app itself** is rejecting the request. Common causes:
- **Metabase**: `slack-connect-authentication-mode` set to `link-only` → returns 401 "Account linking requires an authenticated session" on unauthenticated `/auth/sso/slack-connect` requests. Fix: change to `sso` mode if you want Slack as a full login provider, or have users log in first.
- **N8N**: webhook paths require the workflow to be active
- **Generic**: missing API keys, CSRF tokens, or app-level auth that's separate from CF Access

**General rule for ANY third-party OAuth integration behind Access:** Find the initiate URL (the one that starts the flow by setting cookies and redirecting to the provider) and the callback URL (where the provider redirects back). Bypass BOTH. Common patterns:
- `/auth/sso/<provider>` + `/auth/sso/<provider>/callback`
- `/oauth/<provider>/authorize` + `/oauth/<provider>/callback`
- `/api/auth/<provider>` + `/api/auth/<provider>/callback`

## Design Pattern: Gate Only UI Paths (for API-heavy services)

For services with both a UI and many API routes (e.g., LiteLLM with 100+ endpoints):
- **Audit the API first**: every route left outside Cloudflare Access must enforce app-level authentication/authorization (API keys, bearer tokens, signed webhooks, session cookies validated by the app, etc.). A frontend Access login does **not** protect direct API callers.
- **Prefer the smallest exposure**: path-scope bypass apps to the exact OAuth/webhook/API prefixes that need unauthenticated preflight or third-party callbacks. Avoid whole-hostname bypass unless the full hostname is intentionally public at the Cloudflare edge and the app's own auth covers every exposed route.
- **Don't** try to bypass every API route individually — CF Access has a **4-destination-per-app limit**, so large APIs may need the inverse model.
- **Do** flip the logic when the API is already app-authenticated: create Access apps that gate *only* the UI paths (e.g., `/ui`, `/sso`, `/login`, `/onboarding`, `/fallback/login`) and let non-gated API paths pass through to the origin.

**Example (LiteLLM):** Two Access apps gate only `/ui`, `/sso`, `/login`, `/onboarding` and `/fallback/login`. All other routes (100+) pass through ungated only because LiteLLM requires its own API key auth on those routes. This replaced an earlier approach that tried to create bypass apps for every API path.

## Pitfalls

1. **Railway IPv6 + bindv6only=1**: Railway private networking uses IPv6 exclusively (`fd12:...` addresses). Cloudflared resolves `*.railway.internal` to IPv6. However, Railway containers have `net.ipv6.bindv6only=1`, meaning binding to `::` does NOT enable dual-stack — it only listens on IPv6, and Railway's internal healthcheck (IPv4) fails with "service unavailable". **Solution**: Run the app on `0.0.0.0:PORT` (IPv4, passes healthcheck) + a Python IPv6→IPv4 TCP proxy on `[::]:PORT+1` in the background. Then set the tunnel ingress to use `PORT+1`. Example startCommand:
```
sh -c 'python3 -c "
import socket,threading,select
s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
s.setsockopt(socket.IPPROTO_IPV6,socket.IPV6_V6ONLY,1)
s.bind((\"::\",$((PORT+1))))
s.listen(128)
def proxy(c):
 d=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
 try: d.connect((\"127.0.0.1\",$PORT))
 except: c.close();return
 while True:
  r,_,_=select.select([c,d],[],[],30)
  if not r: break
  for x in r:
   data=x.recv(65536)
   if not data: c.close();d.close();return
   (d if x is c else c).sendall(data)
 c.close();d.close()
while True:
 c,_=s.accept()
 threading.Thread(target=proxy,args=(c,),daemon=True).start()
" & sleep 1 && exec <original-start-command>'
```
**Exceptions**: MinIO and some Go binaries properly support dual-stack with `::` — test each service individually. Elixir/Phoenix apps that use `parse_host("::")` via `:inet.parse_address` also work correctly. Node.js Express with `app.listen(PORT, "::")` and Uvicorn with `--host ::` do NOT dual-stack on Railway.

2. **Tunnel config is a full replace**: The PUT to `configurations` replaces ALL ingress rules. Always GET the current config first and add to it — don't just send new routes or you'll delete existing ones.

3. **CNAME must be proxied**: Set `proxied: true` on DNS records. Non-proxied CNAMEs bypass Access entirely.

4. **Phoenix/Elixir apps**: Don't set `PORT` env var — they typically hardcode port 4000 in config and ignore `PORT`. Railway auto-detects the listening port. Setting PORT can break healthchecks.

5. **Multi-environment domain IDs**: When querying `serviceInstances { domains { serviceDomains } }`, Railway returns domains for ALL environments (production + PR envs). A monorepo service may have 10+ domain entries. Identify the production domain by matching the `RAILWAY_PUBLIC_DOMAIN` variable value, not by array position. PR environment domains (e.g., `admin-alliance-network-pr-1219.up.railway.app`) should be left alone.

6. **URL env vars go stale**: When removing public domains, any env var referencing `RAILWAY_PUBLIC_DOMAIN` (e.g., `WEBHOOK_URL`, `*_BASE_URL`, `*_EDITOR_BASE_URL`) becomes `https://` (empty string). Search all service variables for URL/HOST/DOMAIN patterns and update them to the new CF Access domain.

7. **skipDeploys is optional**: `variableCollectionUpsert` triggers a redeploy by default. If you want to batch multiple variable changes with a single redeploy, pass `skipDeploys: true` and call `serviceInstanceRedeploy` at the end. But some teams prefer each change to deploy immediately — ask before assuming batch mode.

8. **Check deployment status first**: Before migrating, verify services are actually running (`deployments` query, check `status: SUCCESS`). Services with `FAILED` status may still need migration — set up the CF Access/DNS/tunnel side first (it's idempotent), then fix the service. Services with `REMOVED` status are inactive and can be skipped until re-enabled.

9. **Fixing broken services during migration**: If a service has a stuck DB migration or corrupt state on a volume, use Railway's GraphQL API `serviceInstanceUpdate` `startCommand` field where it is supported to inject a fix command before the normal entrypoint. Diagnose first by deploying a debug shell with healthcheck disabled, then fix, then clean up the startCommand.

10. **Railway IPv6 binding — THE #1 migration blocker**: Railway private networking resolves `.railway.internal` hostnames to **IPv6 (AAAA) only**. Cloudflared connects via IPv6. The app MUST listen on `::` to be reachable. **However**, Railway containers have `IPV6_V6ONLY=1`, so binding to `::` does NOT accept IPv4 — which breaks Railway's IPv4 healthcheck proxy (`100.64.0.x`). Solutions:
    - **Best**: App listens on `0.0.0.0:PORT` (passes healthcheck) + `socat` bridges IPv6→IPv4 on `[::]:PORT+1`, tunnel points to `PORT+1`. Requires `socat` in the image (add to `nixPkgs` for Nixpacks builds).
    - **Alternative**: If the app framework supports dual-stack natively (e.g., Node.js `server.listen(port)` without explicit host binds to `::` dual-stack by default on most distros), just don't set `--host` at all.
    - **Avoid**: Don't try `UVICORN_HOST`, `NIXPACKS_START_CMD`, or Railway's `serviceInstanceUpdate.startCommand` to override binding for Nixpacks builds — they DON'T work when the repo has a `railway.json`, `Procfile`, or `nixpacks.toml` that defines the start command. Those in-repo configs always take precedence. You must change the repo files directly.

11. **Railway `serviceInstanceUpdate.startCommand` does NOT override Nixpacks builds**: For source-deployed services using Nixpacks, the start command is baked into the Docker image during build from `railway.json > deploy.startCommand`, `nixpacks.toml > [start].cmd`, or Procfile. The `serviceInstanceUpdate` mutation's `startCommand` field is only effective for Docker image-based services (not Nixpacks from source). To change the start command for a Nixpacks build, you MUST modify the repo files and push a new commit.

12. **socat IPv6→IPv4 bridge pattern for Railway**: When an app hardcodes `--host 0.0.0.0` and can't be changed to `::`:
    - Add `socat` to `nixPkgs` in `nixpacks.toml`: `nixPkgs = ["python313", "socat"]`
    - Wrap the start command: `sh -c 'socat TCP6-LISTEN:3101,fork,reuseaddr,bind=[::] TCP4:127.0.0.1:3100 & uvicorn api:app --host 0.0.0.0 --port 3100'`
    - Point the tunnel ingress to `PORT+1` (the socat listener): `http://svc.railway.internal:3101`
    - **Pitfall**: Railway's start command parser doesn't support shell arithmetic `$((PORT+1))`. Hardcode the port numbers.
    - **Pitfall**: The `sh -c '...'` wrapper is required; without it, Railway's parser may reject the `&` background operator.

13. **Reusable policies**: Check if the reference app's policy has `"reusable": true`. If so, reference it by ID in new apps. If not, you'll need to create individual policies per app.

### CORS Failures with Separate Frontend + API Behind Access

When a frontend (`app.example.com`) makes cross-origin API calls to a backend (`api.example.com`)
and BOTH are behind Cloudflare Access, the browser's `OPTIONS` preflight request will be
**blocked by Access** because preflight requests don't carry cookies. This causes:
```
Access to fetch at 'https://api.example.com/...' from origin 'https://app.example.com'
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present
```

**Fix**: Do **not** assume the frontend Access gate protects the API. If the API app is
changed to `bypass`, Cloudflare stops enforcing identity at the edge for that API, so
every exposed route must already enforce app-level auth (API keys, session cookies,
OAuth bearer tokens, signed webhooks, etc.). Prefer path-scoped bypasses for only the
routes that need unauthenticated preflight/callback traffic; use a whole API hostname
only after auditing that all routes are safe to expose directly to the origin:

```javascript
cloudflare.request({
  method: "PUT",
  path: `/accounts/${accountId}/access/apps/${apiAppId}`,
  body: {
    type: "self_hosted",
    name: "App API (Bypass)",
    domain: "api.example.com",
    policies: [{
      name: "Bypass - App handles own auth",
      decision: "bypass",
      precedence: 1,
      include: [{ everyone: {} }],
    }]
  }
});
```

### CSP Conflicts with Cloudflare Beacon Injection

Cloudflare injects `static.cloudflareinsights.com/beacon.min.js` into HTML responses.
If the app sets a strict `Content-Security-Policy` header (common with SSR frameworks
like Nitro/Nuxt/Next.js), the beacon gets blocked and spams the console.

**Preferred fixes**:
- Disable Cloudflare Web Analytics / beacon injection for this hostname if the beacon is not required.
- If the beacon is required and you control the app, keep the CSP and add `https://static.cloudflareinsights.com` to the appropriate `script-src` directive (and any nonce/hash requirements the app uses).

**Last resort**: remove the CSP header at the edge only when you have explicitly accepted the security tradeoff or have another CSP enforced elsewhere. Removing the response header means the browser no longer receives that CSP for the matched hostname; the app's CSP is not "still sufficient" if this rule removes the only CSP header.

```javascript
cloudflare.request({
  method: "POST",
  path: `/zones/${zoneId}/rulesets`,
  body: {
    name: "App CSP Last-Resort Header Removal",
    kind: "zone",
    phase: "http_response_headers_transform",
    rules: [{
      action: "rewrite",
      action_parameters: {
        headers: { "Content-Security-Policy": { operation: "remove" } }
      },
      expression: '(http.host eq "app.example.com")',
      description: "Last resort: remove CSP only after accepting the security tradeoff",
      enabled: true
    }]
  }
});
```

14. **originRequest**: Always include `originRequest: {}` in ingress rules even if empty — some tunnel versions require it.

## App Launcher & Login Branding

Two separate surfaces need branding: the **login page** and the **app launcher** (post-login grid + landing page).

### Login Page Branding

Controlled via the organization's `login_design` field:

```javascript
cloudflare.request({
  method: "PUT",
  path: `/accounts/${accountId}/access/organizations`,
  body: {
    auth_domain: "yourorg.cloudflareaccess.com",
    name: "Your Org",
    login_design: {
      background_color: "#000000",
      text_color: "#FFFFFF",
      logo_path: "https://example.com/logo.png",
      header_text: "Your Org",
      footer_text: "© Your Org"
    }
  }
});
```

### App Launcher Branding

The app launcher is a special Access app (type `app_launcher`). **Not in the public API docs** — find it via:

```javascript
// GET the app launcher config (undocumented shorthand)
cloudflare.request({ method: "GET", path: `/accounts/${accountId}/access/app_launcher` })
// Returns the app ID, current config, policies, landing_page_design, etc.
```

Then update via the standard apps endpoint using the app ID:

```javascript
cloudflare.request({
  method: "PUT",
  path: `/accounts/${accountId}/access/apps/${appLauncherId}`,
  body: {
    type: "app_launcher",
    session_duration: "24h",
    allowed_idps: [],
    auto_redirect_to_identity: false,
    // Header & page colors (apply to post-login app grid)
    app_launcher_logo_url: "https://example.com/logo-white.png",
    header_bg_color: "#000000",
    bg_color: "#0C0C0C",
    // Footer links
    footer_links: [
      { name: "Your Org", url: "https://example.com" },
      { name: "Privacy Policy", url: "https://example.com/privacy" }
    ],
    // Landing page (pre-login splash screen)
    landing_page_design: {
      title: "Welcome to Your Org",
      message: "Sign in to access your applications.",
      image_url: "https://example.com/logo.png",
      button_color: "#4BE515",       // Login button bg
      button_text_color: "#000000"   // Login button text
    },
    skip_app_launcher_login_page: false
  }
});
```

**App launcher schema fields** (found in OpenAPI spec under `anyOf[4]` of POST `/access/apps`):
- `app_launcher_logo_url` — logo in the header
- `header_bg_color` — header background color
- `bg_color` — page background color
- `footer_links` — array of `{name, url}` objects
- `landing_page_design.title` — heading on splash page
- `landing_page_design.message` — subtitle text
- `landing_page_design.image_url` — image on splash page
- `landing_page_design.button_color` — login button background
- `landing_page_design.button_text_color` — login button text color
- `skip_app_launcher_login_page` — skip the splash page entirely

**Pitfall**: The landing page (pre-login) renders with a light background regardless of `bg_color`; the dark colors apply to the post-login app grid. Cloudflare recommends lighter background colors since the landing page font defaults to black.

## App Launcher: Per-App Customization (Visibility, Tags, Logos)

Each Access app has fields that control how it appears in the app launcher grid:

- `app_launcher_visible` (boolean) — show/hide in launcher
- `logo_url` (string) — custom icon URL for the app tile
- `tags` (string[]) — tag groups used to filter/categorize apps in the launcher

### Creating Tags (MUST be done before assignment)

Tags must exist before you can assign them to apps. The API returns error `12130` if you reference a non-existent tag.

```javascript
// Create tags first
for (const tagName of ["Tools", "Eng Tools", "Eng Dashboards"]) {
  await cloudflare.request({
    method: "POST",
    path: `/accounts/${accountId}/access/tags`,
    body: { name: tagName }
  });
}

// List existing tags
cloudflare.request({ method: "GET", path: `/accounts/${accountId}/access/tags` })
```

### Updating Apps (self_hosted type)

Use PUT on `/access/apps/{id}` with at minimum `type`, `name`, `domain`, and `session_duration`:

```javascript
cloudflare.request({
  method: "PUT",
  path: `/accounts/${accountId}/access/apps/${appId}`,
  body: {
    type: "self_hosted",
    name: "My App",
    domain: "myapp.domain.com",
    session_duration: "24h",
    app_launcher_visible: true,       // or false to hide
    tags: ["Tools"],                   // tag names (must exist)
    logo_url: "https://example.com/logo.svg"  // public URL
  }
});
```

### Updating dash_sso Apps

`dash_sso` type apps (like Cloudflare SSO) require `saas_app` fields to be preserved on PUT or the API returns `internal_server_error`. Always GET the app first to capture its `saas_app` block:

```javascript
const app = await cloudflare.request({ method: "GET", path: `/accounts/${accountId}/access/apps/${appId}` });
await cloudflare.request({
  method: "PUT",
  path: `/accounts/${accountId}/access/apps/${appId}`,
  body: {
    type: "dash_sso",
    name: app.result.name,
    session_duration: "24h",
    app_launcher_visible: false,
    saas_app: {
      auth_type: app.result.saas_app.auth_type,
      consumer_service_url: app.result.saas_app.consumer_service_url,
      sp_entity_id: app.result.saas_app.sp_entity_id,
      idp_entity_id: app.result.saas_app.idp_entity_id,
      name_id_format: app.result.saas_app.name_id_format
    }
  }
});
```

### Pitfalls

- **PATCH `/access/apps/{id}/settings`** exists but requires different auth scopes (error `10405: Method not allowed for this authentication scheme`). Use PUT on the full app resource instead.
- **Tags must pre-exist**: Creating and assigning in one step doesn't work. Always POST to `/access/tags` first.
- **PUT replaces fields**: Omitting `tags` or `logo_url` on PUT will clear them. Include all desired fields.
- **Logo URLs**: Must be publicly accessible. Good sources: GitHub raw URLs, official branding pages, GitHub org avatars (`https://avatars.githubusercontent.com/u/<org_id>`).

## Useful Queries

```javascript
// Find zone ID for a domain
cloudflare.request({ method: "GET", path: "/zones", query: { name: "domain.com" } })

// List all Access apps with their policies
cloudflare.request({ method: "GET", path: `/accounts/${accountId}/access/apps` })

// Get specific app policy details
cloudflare.request({ method: "GET", path: `/accounts/${accountId}/access/apps/${appId}/policies` })

// Check tunnel health
cloudflare.request({ method: "GET", path: `/accounts/${accountId}/cfd_tunnel/${tunnelId}` })
```
