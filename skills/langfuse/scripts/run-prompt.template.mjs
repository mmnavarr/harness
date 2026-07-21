#!/usr/bin/env node
//
// Langfuse end-to-end prompt runner template.
//
// Copy this file, fill in PROMPT_NAME, VARS, SCHEMA, and the tailscale IP,
// then run with `node /tmp/run-prompt.mjs`.
//
// Prereqs (see ../SKILL.md for full setup):
//   /tmp/lf_env.json    — {LANGFUSE_PUBLIC_KEY, LANGFUSE_SECRET_KEY, OPENAI_API_KEY}
//   /tmp/lf_basic.txt   — `Basic <base64(public:secret)>`
//   LF base URL         — http://<tailscale-ip>:13676 (NOT langfuse.alliancetools.xyz; Cloudflare Access blocks non-browser clients)
//
// Mirrors the real bullqueue flow: fetches prompt with label=latest, compiles
// Mustache-style {{vars}}, calls OpenAI chat.completions with strict
// json_schema response format, returns parsed output.

import { readFileSync } from 'node:fs'

// ----- CONFIG -----
// Set LF_BASE_URL=http://<your-tailscale-peer-ip>:13676 before running.
// The Tailscale-internal Langfuse endpoint intentionally uses http (no TLS on the
// internal network); point semgrep's react-insecure-request rule at documentation
// if it complains.
const LF = process.env.LF_BASE_URL ?? 'http://TAILSCALE_PEER_IP:13676'
const PROMPT_NAME = 'investor-update-analyze'

const VARS = {
  subject: 'Accrue: Investor Update',
  from: 'Clinton Mbah <clinton@useaccrue.com>',
  content: "Hello, here's our Q1 2026 investor update link: https://docsend.com/view/abc123",
}

// Must match the Zod schema used in the consumer code. Strict mode requires
// `additionalProperties: false` and every property listed in `required`.
const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['reasoning', 'isInvestorUpdate', 'confidence', 'summary'],
  properties: {
    reasoning: { type: 'string' },
    isInvestorUpdate: { type: 'boolean' },
    confidence: { type: 'number' },
    summary: { type: ['string', 'null'] },
  },
}
// ------------------

const env = JSON.parse(readFileSync('/tmp/lf_env.json', 'utf8'))
const auth = readFileSync('/tmp/lf_basic.txt', 'utf8').trim()

const promptUrl = `${LF}/api/public/v2/prompts/${PROMPT_NAME}?label=latest`
const pr = await fetch(promptUrl, { headers: { Authorization: auth } })
if (!pr.ok) {
  console.error(`fetch prompt failed: HTTP ${pr.status} — ${await pr.text()}`)
  process.exit(1)
}
const prompt = await pr.json()
const model = prompt.config?.model ?? 'gpt-5.4-mini'
const compile = (s) => s.replace(/\{\{\s*(\w+)\s*\}\}/g, (_, k) => VARS[k] ?? '')
const messages = prompt.prompt.map((m) => ({ role: m.role, content: compile(m.content) }))

const t0 = Date.now()
const r = await fetch('https://api.openai.com/v1/chat/completions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${env.OPENAI_API_KEY}` },
  body: JSON.stringify({
    model,
    messages,
    response_format: {
      type: 'json_schema',
      json_schema: { name: 'output', strict: true, schema: SCHEMA },
    },
  }),
})
const body = await r.json()
const ms = Date.now() - t0
let parsed = null
try {
  parsed = JSON.parse(body?.choices?.[0]?.message?.content ?? '')
} catch {}

console.log(
  JSON.stringify(
    { status: r.status, ms, model: body?.model, usage: body?.usage, error: body?.error, parsed },
    null,
    2,
  ),
)
