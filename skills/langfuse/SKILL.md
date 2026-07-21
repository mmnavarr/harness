---
name: langfuse
description: Query the self-hosted Langfuse instance used by Alliance Network. Use to list prompts, fetch a prompt's content, inspect traces/generations, or run a prompt end-to-end against OpenAI during feature testing. Bypasses Cloudflare Access via the Railway Tailscale gateway.
---

# Langfuse (Alliance Network self-hosted)

## Overview

Langfuse is self-hosted in the Railway **Internal Tools** project. Production apps (bullqueue, webapp) reach it through Railway's internal Tailscale gateway at `http://tailscale-gateway.railway.internal:13676`. The public domain `https://langfuse.alliancetools.xyz` is gated by **Cloudflare Access** — browser sessions work, but programmatic API calls get 302'd to the CF login page and the Langfuse SDK errors with `SyntaxError: Failed to parse JSON`.

Use this skill when you need to:

- List prompts in a project (latest version, labels)
- Fetch a specific prompt's content for inspection or local reuse
- Fetch a specific trace / generation by id
- Run a prompt end-to-end against OpenAI using real prod creds during feature testing
- Reason about what LLM calls bullqueue is actually making

Do NOT use this skill for prompt creation/editing. Prompts are shared infrastructure — create or edit them via the Langfuse UI at `https://langfuse.alliancetools.xyz` after explicit user confirmation.

## Connection

### Why the Tailscale gateway

The Cloudflare Access gate on `langfuse.alliancetools.xyz` breaks programmatic clients. The Tailscale gateway IP exposes the same Langfuse-web service (port 13676) without the CF layer, which is how bullqueue and webapp talk to it in prod.

### Discover the current gateway IP + port

The user's Tailscale peer for `tailscale-gateway.railway.internal` is usually `100.110.158.108` (April 2026), but verify before trusting it:

```bash
# Langfuse base URL as bullqueue sees it in prod:
railway link --project "Alliance Monorepo" --environment production  # if not already linked
railway variables --service BullMQ --json \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('LANGFUSE_BASE_URL'))"
# → http://tailscale-gateway.railway.internal:13676
```

Replace `tailscale-gateway.railway.internal` with the laptop's Tailscale peer IP (visible via `tailscale status` or the macOS app). Health check:

```bash
curl -sSI http://<tailscale-ip>:13676/api/public/health   # expect HTTP/1.1 200 OK
```

### Credentials

Langfuse uses HTTP Basic with `PUBLIC_KEY:SECRET_KEY`. Pull them from the BullMQ service (matches prompts project = `Space`):

```bash
railway variables --service BullMQ --json \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
with open('/tmp/lf_env.json', 'w') as f:
    json.dump({k: d[k] for k in ['LANGFUSE_PUBLIC_KEY','LANGFUSE_SECRET_KEY','OPENAI_API_KEY'] if k in d}, f)
print('ok')
"

python3 -c "
import json, base64
d = json.load(open('/tmp/lf_env.json'))
print('Basic ' + base64.b64encode(f\"{d['LANGFUSE_PUBLIC_KEY']}:{d['LANGFUSE_SECRET_KEY']}\".encode()).decode())
" > /tmp/lf_basic.txt
```

**Important**: never echo the contents of `/tmp/lf_env.json` or `/tmp/lf_basic.txt` — they are secrets. Delete them at the end of the session:

```bash
rm -f /tmp/lf_env.json /tmp/lf_basic.txt
```

## Projects

The Langfuse instance hosts a handful of projects under the `alliance` org. Project IDs (stable):

| Project | ID |
|---|---|
| Space (bullqueue + webapp prompts) | `cm8evkz060006m902t6gl0hkr` |
| Scout | check Langfuse UI |
| LiteLLM | check Langfuse UI |
| Symphony | check Langfuse UI |
| Hubspot AI | check Langfuse UI |
| claude-cowork | check Langfuse UI |

The API keys pulled from BullMQ scope to **Space** — that's where bullqueue investor-update, telegram classifiers, grammar correction, post-spam classifier etc. live. For other projects, pull keys from the matching service (scout, webapp, hubspot-ai, etc.).

## Common operations

Set `LF=http://<tailscale-ip>:13676` and `AUTH=$(cat /tmp/lf_basic.txt)` before running these.

### List prompts in the current project

```bash
curl -sS -H "Authorization: $AUTH" "$LF/api/public/v2/prompts?limit=100" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f'Total: {d.get(\"meta\", {}).get(\"totalItems\")}')
for p in d.get('data', []):
    vs = p.get('versions') or []
    labels = ','.join(p.get('labels') or [])
    print(f\"- {p['name']}  v{max(vs) if vs else '?'}  [{labels}]\")
"
```

### Fetch a specific prompt

```bash
curl -sS -H "Authorization: $AUTH" \
  "$LF/api/public/v2/prompts/<PROMPT_NAME>?label=latest" | jq .
```

Save for local reuse:

```bash
curl -sS -H "Authorization: $AUTH" \
  "$LF/api/public/v2/prompts/investor-update-analyze?label=latest" \
  > /tmp/lf-prompt.json
```

### Fetch a trace by id

```bash
curl -sS -H "Authorization: $AUTH" "$LF/api/public/traces/<TRACE_ID>" | jq .
```

Trace IDs are persisted on DB rows whenever bullqueue runs an LLM call (e.g. `CompanyNote.data.classificationTraceId`). Use this to audit what the model actually received and produced for a given row.

### Run a prompt locally against OpenAI (feature testing)

Use this when you want to test a prompt change end-to-end without deploying. The Langfuse SDK in the monorepo fetches the prompt with `label: 'latest'`, substitutes `{{var}}` placeholders, and calls OpenAI with a Zod-derived `response_format`. You can replicate that with a ~30-line `.mjs` script in `/tmp`:

1. Save prompt → `/tmp/lf-prompt.json` (see above).
2. Prepare the vars the prompt expects (subject/from/content for investor-update-analyze).
3. Use the OpenAI key from `/tmp/lf_env.json` to call `https://api.openai.com/v1/chat/completions` with the compiled messages and a strict `json_schema` response format matching the consumer's Zod schema.

Example script is in `scripts/run-prompt.template.mjs` next to this SKILL file. Copy, edit the `PROMPT_NAME`, `SCHEMA`, and `VARS` constants, then run with the Tailscale peer URL in env:

```bash
LF_BASE_URL=http://<your-tailscale-peer-ip>:13676 node /tmp/run-prompt.mjs
```

## Safety rules

1. **Read-only by default.** List, fetch, and run-against-OpenAI are safe. Any mutation (creating prompts, editing labels, deleting traces) goes through the UI with explicit user confirmation — treat prompts as shared prod infrastructure.
2. **Never dump secrets.** `/tmp/lf_env.json` and `/tmp/lf_basic.txt` contain prod API keys. Don't cat them to the transcript, don't commit them, and delete them at the end of the session.
3. **Override `LANGFUSE_BASE_URL` explicitly when running monorepo code locally.** The value in BullMQ's env is the internal DNS name that won't resolve from the laptop. `railway run --service BullMQ -- <cmd>` injects the bad value — set `LANGFUSE_BASE_URL=http://<tailscale-ip>:13676` before the `railway run` invocation, or dump the other vars to a file and export them yourself.
4. **Be careful with trace queries.** Traces can contain PII from email bodies, user messages, and LLM outputs. Don't paste full trace bodies to external channels.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Failed to parse JSON` from Langfuse SDK | Hit the public CF-Access gated URL from a non-browser client | Point `LANGFUSE_BASE_URL` at `http://<tailscale-ip>:13676` |
| `ConnectionRefused` against `tailscale-gateway.railway.internal` | Running from a laptop with the internal DNS — only resolves inside Railway | Use the Tailscale peer IP instead |
| `401 UnauthorizedError` with "No authorization header" | Missing `Authorization: Basic ...` header | Rebuild `/tmp/lf_basic.txt` from current BullMQ vars |
| Prompt exists in UI but API returns 404 | Wrong label (default is `production`), or name typo | Add `?label=latest` to the URL, or check the actual name in the UI |
| Tailscale IP doesn't respond | IP changed, or Tailscale isn't running | Check `tailscale status`; re-derive the peer IP for `tailscale-gateway.railway.internal` |

## Maintenance

If something in this skill broke or felt out of date during a real session (changed port, new project, auth flow change), follow the `skill-improve` protocol to propose updates instead of patching inline.
