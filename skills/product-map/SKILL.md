---
name: product-map
description: Catalog of Alliance Network products grouped by pillar (Deal Flow, Admission, Acceleration, Fundraising, Community). Use when the user asks about a product, feature area, where code for X lives, or when mapping cross-app behaviors. Each product page lists file paths, queues, DB models, and a last-checked master commit — the agent MUST verify currency before trusting details and self-heal drift.
---

# Product Map

This skill is a progressive-disclosure catalog of **products** in the Alliance Network monorepo. The index below is the only thing loaded by default. Open a specific `products/<id>.md` page only when the user's question touches that product.

## What is a product?

A **product** is a coherent set of behaviors that spans multiple apps/packages and produces a user-visible outcome. It is not a file, not an app, not a queue — those are implementation pieces. A product usually owns:

- one or more entry points (a page, route, CLI, webhook)
- a flow of work across the stack (UI → server action/RPC → queue → worker → external system)
- its own DB table(s) or a distinct lifecycle on shared tables
- one or more external integrations (Slack, HubSpot, Postmark, Telegram, …)

Example: `demo-day-intros` spans `apps/website` (form), `packages/queues` (job schema), `apps/bullqueue` (worker + Slack approval), `packages/database` (`DemoDayInterest` table), HubSpot (approved list), and Slack (approval message).

## Criteria to identify a product

Look for **all** of these before treating something as its own product:

1. **Cross-cutting** — touches at least two of: an app, a queue, a DB table, an external integration.
2. **User-visible outcome** — a founder, investor, or admin can describe what changed.
3. **Distinct lifecycle** — its own state machine, enum states, or scheduled cadence.
4. **Stable boundary** — has a name people use in planning (Linear issues, PRs, Slack).

A single endpoint that mutates one row is *not* a product. A feature flag is *not* a product. A shared utility is *not* a product.

## Pillars

| Pillar | Purpose |
|---|---|
| **Deal Flow** | Sourcing and qualifying inbound/outbound leads before admission |
| **Admission** | Application review, approvals, and onboarding into the network |
| **Acceleration** | Programs, matching, reviews, and reporting for active portfolio |
| **Fundraising** | Connecting founders to investors (demo day, intros, updates) |
| **Community** | Network communication, engagement, and content surfaces |

## Product Index

Only **mapped** products have a page. Candidate IDs without a page are listed as "not yet mapped" — this catalog is built incrementally as we touch features. When the user asks about one of them, create the page then (see [Adding a product on demand](#adding-a-product-on-demand)).

### Deal Flow
| ID | Description |
|---|---|
| scout-sourcing *(not yet mapped)* | Lead qualification, normalization, and investor matching in Scout |
| referral-pipeline *(not yet mapped)* | Founder referral tracking, status sync, and deal staging |
| hubspot-sync *(not yet mapped)* | CRM integration for form submissions and deal pipelines |

### Admission
| ID | Description |
|---|---|
| founder-application *(not yet mapped)* | Application intake, review, and onboarding flow |
| onboarding-emails *(not yet mapped)* | Scheduled welcome and orientation email campaigns |
| [slack-approvals](products/slack-approvals.md) | Async approval workflows via Slack buttons routed back to queues |

### Acceleration
| ID | Description |
|---|---|
| investor-reviews *(not yet mapped)* | Investor evaluations and scoring of founders |
| company-matching *(not yet mapped)* | Mentor/portfolio matching algorithms |
| portfolio-reports *(not yet mapped)* | Automated portfolio performance analytics and exports |

### Fundraising
| ID | Description |
|---|---|
| [demo-day-intros](products/demo-day-intros.md) | Demo day investor matching and intro email delivery |
| [demo-day-interest](products/demo-day-interest.md) | Founder/investor interest capture on `/dd/<uid>` pages |
| investor-updates *(not yet mapped)* | Portfolio company updates pushed to investors |

### Community
| ID | Description |
|---|---|
| telegram-network *(not yet mapped)* | Telegram group messaging, user management, moderation |
| forum-community *(not yet mapped)* | Discussion threads, post approval, moderation |
| leaderboard *(not yet mapped)* | Activity tracking and gamified member ranking |
| notes-sync *(not yet mapped)* | Shared notes with Slack sync and mentions |
| job-board *(not yet mapped)* | Web3 jobs listings and application approvals |
| email-digest *(not yet mapped)* | Scheduled digest of forum activity and network updates |

## Adding a product on demand

Do not pre-create stubs. Add a product page only when working on that product and you have enough first-hand signal to fill it in accurately.

Steps:
1. Copy the template at the bottom of this file to `products/<id>.md`.
2. Fill it in from the work you just did — never guess.
3. Stamp frontmatter with `bash .agents/skills/product-map/scripts/stamp-commit.sh` (from inside the repo).
4. Replace the *(not yet mapped)* row above with a link to the new page.
5. If the product isn't in the candidate list, add a new row under the correct pillar.

When you finish mapping a product, mention it briefly to the user so they know the map grew.

## Staleness and self-healing protocol

Every product page carries `lastCheckedCommit` and `lastCheckedDate` in its frontmatter. Treat those as a **claim about a point in time**, not a fact.

**Before answering a user question that depends on specifics** (file paths, queue names, field names, state enums):

1. Compare `lastCheckedCommit` against the current `origin/master` (run from inside the repo):
   ```
   git rev-parse --short origin/master
   ```
2. If the stamp is behind, **spot-check** the key files listed on the page via `Grep`/`Read`. You do not need to re-verify the entire page — just the parts your answer will rely on.
3. If anything has drifted (renamed file, renamed queue, removed field, new state enum, moved integration):
   - **Update the product page in the same turn.**
   - Run `bash .agents/skills/product-map/scripts/stamp-commit.sh` from inside the repo and paste the new `lastCheckedCommit` / `lastCheckedDate` into the frontmatter.
   - Briefly note to the user what changed ("Fixed the product map: `xQueue` was renamed to `yQueue`.").
4. If a path listed on the page no longer exists and you cannot find the replacement with confidence, mark that line `⚠️ stale` rather than deleting it, and flag it to the user.

**If you discover a product that isn't catalogued:**

- Add a new `products/<kebab-id>.md` using the template below.
- Add a row to the index in this file under the correct pillar.
- Stamp the new page with today's commit.

**Never fabricate.** If you're unsure whether something is a product or where the boundary lies, ask the user before adding it to the map.

## Per-product page template

```markdown
---
id: <kebab-case-id>
pillar: <Deal Flow | Admission | Acceleration | Fundraising | Community>
lastCheckedCommit: <short-sha>
lastCheckedDate: <YYYY-MM-DD>
---

# <Human Title>

## Summary
One paragraph: what the product does and who uses it.

## Entry points
- UI routes / pages
- API endpoints / server actions
- CLI / scheduled triggers

## Flow
ASCII flowchart of the happy path (and major branches).

## Queues and jobs
- queue name → processor path

## Database models and fields
- Model name → relevant fields → state enum values

## External integrations
- Slack / HubSpot / Postmark / Telegram / etc.

## Key files
| Layer | Path |
```

### Behavior-only rule

Product pages describe **what the system does**, not how to test or verify it. Do not add:

- verification/grep/smoke-test checklists
- test file paths, mock setup, or CI commands
- build, lint, or typecheck instructions
- implementation how-to ("to add X, do Y") — that belongs in code comments or contributor docs

Do include: flow diagrams, queue names, processor paths, Prisma models + state enums, external integrations, and the "Key files" table. If a detail would belong in a PR description or a `bun test` README, it doesn't belong here.

## How to use this skill

- Read this `SKILL.md`.
- Pick the single product page(s) relevant to the user's question and `Read` them.
- Do **not** open unrelated product pages — they stay on disk until needed.
- Before relying on details, run the staleness check described above.
- When you find drift, fix the page **in this turn** and tell the user what you fixed.
- When you discover a new product, add it.

## Commit stamping helper

```bash
bash .agents/skills/product-map/scripts/stamp-commit.sh
```

Run from inside the alliance-network repo (or set `REPO=/path/to/repo`). Prints a two-line block ready to paste into a product page's frontmatter.
