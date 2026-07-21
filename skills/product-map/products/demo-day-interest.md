---
id: demo-day-interest
pillar: Fundraising
lastCheckedCommit: f5d8d4d79
lastCheckedDate: 2026-04-14
---

# Demo Day Interest

## Summary

The capture surface for investor/partner interest in demo day listings. `demo-day-interest` is the **form + persistence** side of the flow: the public `/dd/<uid>` page renders active `DemoDayListing`s, the submitter checks the companies they want introductions to, and the server action persists one `DemoDayInterest` row per selected listing in `PENDING` state. Handoff to Slack/email belongs to the [demo-day-intros](demo-day-intros.md) product.

This product exists as a distinct boundary because the admin-facing curation of listings, the public page, and the persistence contract evolve independently of the intro delivery pipeline.

## Pillar

Fundraising.

## Entry points

- **Public page**: `apps/website/app/dd/[uid]/page.tsx` — renders listings for an active demo day.
- **Server action**: `submitDemoDayInterest` in `apps/website/app/dd/[uid]/actions.ts`.
- **Admin curation**: `apps/webapp/src/admin/demo-days/` (listing editor UI) and backing mutations.
- **Success page**: `apps/website/app/dd/success/`.

## Flow

```
Admin creates DemoDay + DemoDayListings (apps/webapp admin panel)
                ↓
Investor visits /dd/<uid>  →  page renders active DemoDay and its listings
                ↓
Fills email / fullName / companyName + checks listings
                ↓
submitDemoDayInterest server action
  • Zod validate
  • prisma tx: for each selected listingId →
       create DemoDayInterest { email, fullName, companyName,
                                listingId, state: PENDING }
  • POST to bullqueue → demoDayInterest job (handoff to demo-day-intros)
                ↓
redirect /dd/success
```

## Queues and jobs

Only one queue is owned by this product boundary — downstream processing is [demo-day-intros](demo-day-intros.md).

| Queue | Processor | Purpose |
|---|---|---|
| `demoDayInterest` | `apps/bullqueue/src/jobs/demo-day-interest/processDemoDayInterest.ts` | Hands off PENDING rows to the approval/intro pipeline. |

## Database models and fields

- **`DemoDay`** — `id`, `isActive`, `createdAt`, `updatedAt`. Finds the active demo day associated with `[uid]`.
- **`DemoDayListing`** — per-company card shown on `/dd/<uid>`. Fields: `id`, `demoDayId`, `companyId`, `companyName`, `companyLogo`, `companyOneliner`, `companyWebsite`, `founderEmail`, `founderNames[]`, `founderLinkedins[]`, `memo`, `youtubeLink`, `order`.
- **`DemoDayInterest`** (owned by this product) — `id` (cuid), `email`, `fullName`, `companyName`, `listingId`, `state`, `createdAt`, `updatedAt`. State enum: `PENDING` (created here) → `SENT` / `REJECTED` / `FAILED` (set by demo-day-intros).

## External integrations

- None directly. The form is plain Next.js. Downstream handoff to HubSpot/Slack lives in [demo-day-intros](demo-day-intros.md).

## Key files

| Layer | Path |
|---|---|
| Public page | `apps/website/app/dd/[uid]/page.tsx` |
| Form | `apps/website/app/dd/[uid]/DemoDayInterestForm.tsx` |
| Server action | `apps/website/app/dd/[uid]/actions.ts` |
| Success page | `apps/website/app/dd/success/` |
| Admin curation UI | `apps/webapp/src/admin/demo-days/` |
| Interest queue | `packages/queues/src/demoDayInterest.ts` |
| Prisma models | `packages/database/prisma/schema/schema.prisma` (`DemoDay`, `DemoDayListing`, `DemoDayInterest`) |
