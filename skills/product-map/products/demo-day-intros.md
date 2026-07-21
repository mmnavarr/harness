---
id: demo-day-intros
pillar: Fundraising
lastCheckedCommit: f5d8d4d79
lastCheckedDate: 2026-04-14
---

# Demo Day Intros

## Summary

Turns investor interest captured on a demo day page into warm intro emails to founders. An interest submission either auto-approves (email already on the HubSpot "Demo Day Approved" list) or routes to a Slack approval flow with approve/reject buttons. On approval, each selected listing triggers an intro email to the founder. Used by demo-day-eligible investors submitting on `/dd/<uid>` and by Alliance admins triaging in Slack.

## Pillar

Fundraising.

## Entry points

- **Website page**: `apps/website/app/dd/[uid]/page.tsx` (public demo day page).
- **Server action**: `submitDemoDayInterest` in `apps/website/app/dd/[uid]/actions.ts`.
- **Slack webhook**: `POST /webhook/slack-shortcut` in `apps/bullqueue/src/server/routes/slackShortcut.ts` — receives the approve/reject button clicks.

## Flow

```
┌──────────────────────────────────────────────────────────────────┐
│ WEBSITE  apps/website/app/dd/[uid]/page.tsx                      │
│ DemoDayInterestForm (email, fullName, companyName, listings)     │
└───────────────────────────────┬──────────────────────────────────┘
                                │ submit
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│ SERVER ACTION  apps/website/app/dd/[uid]/actions.ts              │
│ • Zod validate                                                   │
│ • prisma tx: create DemoDayInterest (state=PENDING) per listing  │
│ • enqueue demoDayInterest job                                    │
└───────────────────────────────┬──────────────────────────────────┘
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│ JOB  apps/bullqueue/src/jobs/demo-day-interest/                  │
│      processDemoDayInterest.ts                                   │
│                                                                  │
│  HubSpot "Demo Day Approved" list?                               │
│   YES ──────────────────────────┐                                │
│   NO  → send Slack approval msg │                                │
└───────────────────────────────┬─┼────────────────────────────────┘
                                │ │
                                ▼ │
┌──────────────────────────────────┼───────────────────────────────┐
│ SLACK MESSAGE (template          │                               │
│  apps/bullqueue/src/notifications/templates/                     │
│  demoDayInterestApproval.ts)     │                               │
│  [Approve Intro]  [Reject Intro] │                               │
└───────────────────────────────┬──┼───────────────────────────────┘
                                │  │
                                ▼  │
┌──────────────────────────────────┼───────────────────────────────┐
│ WEBHOOK  /webhook/slack-shortcut │                               │
│  parse value → enqueue           │                               │
│  demoDayInterestApproval job     │                               │
│  update Slack msg ✅/❌          │                               │
└───────────────────────────────┬──┼───────────────────────────────┘
                                ▼  │
┌──────────────────────────────────┼───────────────────────────────┐
│ JOB  processDemoDayInterestApproval.ts                           │
│  isApproval=true  → HubSpot upsert + add to Approved list        │
│                   → enqueue demoDayIntroEmail ────┐              │
│  isApproval=false → updateMany state=REJECTED     │              │
└────────────────────────────────────────────────────┼─────────────┘
                                                    │
                                                    ▼
┌──────────────────────────────────────────────────────────────────┐
│ JOB  sendDemoDayIntroEmail.ts                                    │
│  fetch PENDING DemoDayInterest rows for email                    │
│  ─ ban gate ─                                                    │
│  isContactInDemoDayBanList(email)? (HubSpot list 912)            │
│    throws on HubSpot error → worker retries (fail-closed)        │
│    true  → updateMany state=REJECTED, Slack 🚫 notice, return    │
│    false → continue                                              │
│  for each listing: send intro to listing.founderEmail            │
│    success → state=SENT ; error → state=FAILED                   │
│  record HubSpot contact activity                                 │
│  Slack ✅ demoDayEmailSent notice                                │
└──────────────────────────────────────────────────────────────────┘
```

## Queues and jobs

| Queue | Processor |
|---|---|
| `demoDayInterest` (`packages/queues/src/demoDayInterest.ts`) | `apps/bullqueue/src/jobs/demo-day-interest/processDemoDayInterest.ts` |
| `demoDayInterestApproval` (`packages/queues/src/demoDayInterestApproval.ts`) | `apps/bullqueue/src/jobs/demo-day-interest-approval/processDemoDayInterestApproval.ts` |
| `demoDayIntroEmail` | `apps/bullqueue/src/jobs/demo-day-intro-email/sendDemoDayIntroEmail.ts` (includes ban-list gate via `isContactInDemoDayBanList`) |

## Database models and fields

- **`DemoDay`** — `id`, `isActive`, `createdAt`, `updatedAt`.
- **`DemoDayListing`** — `id`, `demoDayId`, `companyId`, `companyName`, `companyLogo`, `companyOneliner`, `companyWebsite`, `founderEmail` (intro recipient), `founderNames[]`, `founderLinkedins[]`, `memo`, `youtubeLink`, `order`.
- **`DemoDayInterest`** (state table) — `id` (cuid), `email`, `fullName`, `companyName`, `listingId`, `state`, `createdAt`, `updatedAt`.
  - `state` enum: `PENDING` → `SENT` / `REJECTED` / `FAILED`.

## External integrations

- **Slack** — approval message via `sendSlackNotification({ name: 'demoDayInterestApproval' })`. Ban-list notice via `sendSlackNotification({ name: 'demoDayInterestBanned' })` (channel `slackDemoDayInterest`). Webhook handler: `slackShortcut.ts`. Button payloads are JSON-encoded `{queue, payload}` blobs, with `isApproval: boolean`.
- **HubSpot**:
  - "Demo Day Approved" list (`1295`) gates the auto-approval path at `processDemoDayInterest`.
  - "Demo Day Ban" list (`912`) gates the final intro send at `sendDemoDayIntroEmail` — banned investors get Slack notice + rows flipped to `REJECTED`; HubSpot read errors throw so the worker retries (fail-closed).
  - Contact upsert on approval; contact activity log after intro email.
- **Postmark** (or current transactional sender) — delivers the intro email.

## Key files

| Layer | Path |
|---|---|
| Page | `apps/website/app/dd/[uid]/page.tsx` |
| Form | `apps/website/app/dd/[uid]/DemoDayInterestForm.tsx` |
| Server action | `apps/website/app/dd/[uid]/actions.ts` |
| Interest queue | `packages/queues/src/demoDayInterest.ts` |
| Interest job | `apps/bullqueue/src/jobs/demo-day-interest/processDemoDayInterest.ts` |
| Slack template | `apps/bullqueue/src/notifications/templates/demoDayInterestApproval.ts` |
| Slack webhook | `apps/bullqueue/src/server/routes/slackShortcut.ts` |
| Approval queue | `packages/queues/src/demoDayInterestApproval.ts` |
| Approval job | `apps/bullqueue/src/jobs/demo-day-interest-approval/processDemoDayInterestApproval.ts` |
| Intro email job | `apps/bullqueue/src/jobs/demo-day-intro-email/sendDemoDayIntroEmail.ts` |
| Ban-list notice template | `apps/bullqueue/src/notifications/templates/demoDayInterestBanned.ts` |
| HubSpot list helpers | `apps/bullqueue/src/utils/hubspot.ts` — `isContactInList`, `isContactInDemoDayBanList`, `isContactInDemoDayInterestList` |
| Prisma model | `packages/database/prisma/schema/schema.prisma` (`DemoDayInterest`) |
