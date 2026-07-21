---
name: cloudflare-access-cors-fix
description: Use when a Cloudflare Access-gated frontend calls a separate API subdomain and browser requests fail with CORS, OPTIONS preflight redirects, blocked fetch/XHR calls, or Cloudflare-injected CSP/script issues.
tags: [cloudflare, cors, access, csp]
---

# Fix CORS with Cloudflare Access (Frontend + Separate API)

## Trigger
Browser CORS errors when a CF Access-gated frontend makes fetch/XHR requests to an API on a different subdomain that is also behind CF Access.

## Root Cause
CF Access intercepts the browser's OPTIONS preflight request and returns a redirect to the login page instead of CORS headers. The browser blocks the request.

## Fix Steps

1. **Bypass CF Access only where preflights must be unauthenticated** — Use a **Bypass** policy, not "Allow Everyone": only Bypass prevents Access from intercepting unauthenticated `OPTIONS` preflight requests. Prefer the narrowest path-scoped bypass practical instead of exposing a whole API hostname. Before bypassing any route, audit that every exposed API endpoint has app-level authentication and authorization independent of Access (session, OAuth/JWT, API key, etc.). If the API can remain behind Access, configure Access `cors_headers` as a stricter alternative instead of bypassing it.

2. **Fix Cloudflare beacon CSP conflicts without dropping CSP** — If Cloudflare Web Analytics / `beacon.min.js` is blocked, first disable Cloudflare beacon injection for that hostname or update the app's `script-src` policy to allow Cloudflare Insights. Removing the entire `Content-Security-Policy` response header is a last resort only, because it weakens browser-side security protections.

## Pitfalls
- "Allow Everyone" still runs the Access flow and can still break unauthenticated browser preflights; use Bypass for the preflight path when bypass is required.
- Whole-hostname API bypasses are broader than necessary. Use path-scoped bypasses where practical, and only after confirming every exposed route enforces app-level auth.
- Removing CSP may make the symptom disappear while reducing security. Prefer disabling Cloudflare injection or explicitly allowing Cloudflare Insights in CSP.
