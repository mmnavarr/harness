---
id: slack-approvals
pillar: Admission
lastCheckedCommit: ce7f4f0ec
lastCheckedDate: 2026-05-12
---

# Slack Approvals

## Summary

A shared platform capability that lets any BullMQ job send a Slack message with Approve/Reject buttons, then route the button click back into a registered approval queue. The pattern is used by Demo Day interest, Web3 job applications, and forum post moderation. Admins click in Slack; the webhook handler enqueues the decision job and updates the Slack message to show who acted.

## Entry points

- **Webhook**: `POST /webhook/slack-shortcut` in `apps/bullqueue/src/server/routes/slackShortcut.ts` — receives all interactive button payloads from Slack.
- **Producer side**: any job calls `sendSlackNotification({ name: '...' })` (queues to `slackNotify`) with a template that includes buttons whose `value` encodes `{ queue, payload }`.

## Flow

```
┌─────────────────────────────────────────────────────────────┐
│ ANY PRODUCER JOB                                            │
│  builds blocks with SlackNotificationBuilder                │
│  button value = JSON.stringify({                            │
│    queue: APPROVAL_QUEUE_NAME,                              │
│    payload: { ...jobData, isApproval: boolean }             │
│  })                                                         │
│  calls sendSlackNotification → enqueues to slackNotify      │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ SLACK MESSAGE (in approval channel)                         │
│  [Approve]  [Reject]                                        │
└──────────────────────────────┬──────────────────────────────┘
                               │ admin clicks
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ WEBHOOK  POST /webhook/slack-shortcut                       │
│  slackShortcut.ts                                           │
│  • verify Slack signature                                   │
│  • validate response_url (must be https://hooks.slack.com)  │
│  • parse button value JSON                                  │
│  • if { queue, payload } → handleQueueBasedApproval         │
│    • resolveQueue(queue) → registered BullMQ queue          │
│    • queue.add(queue, payload)                              │
│    • replyToSlackAction(response_url, updatedBlocks)        │
│      (best-effort: error is logged, not thrown)             │
│    • Slack message updated: "Approved/Rejected by <user>"   │
│  • else → legacy slackAction queue path                     │
│  • res.json({ ok: true })                                   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ APPROVAL JOB (product-specific)                             │
│  uses isApproval: boolean to branch                         │
│  runs business logic (DB writes, emails, HubSpot, etc.)     │
└─────────────────────────────────────────────────────────────┘
```

## Queues and jobs

### Platform infrastructure

| Queue | Processor |
|---|---|
| `slackNotify` (`packages/queues/src/slackNotify.ts`) | `apps/bullqueue/src/jobs/slack-notify/` — dispatches to channel via template |

### Registered approval queues

| Queue | Processor | Triggered by |
|---|---|---|
| `demoDayInterestApproval` | `apps/bullqueue/src/jobs/demo-day-interest-approval/processDemoDayInterestApproval.ts` | `demoDayInterestApproval` template |
| `jobApplicationApproval` | `apps/bullqueue/src/jobs/job-application-approval/index.ts` | `web3JobApplication` template |
| `postApproval` | `apps/bullqueue/src/jobs/post-approval/index.ts` | `postApproval` template |

New approval queues must be registered in the `getApprovalQueue` switch in `slackShortcut.ts`.

## Button value contract

Every approve/reject button must carry a `value` of this shape:

```json
{
  "queue": "<QUEUE_NAME_CONSTANT>",
  "payload": {
    "isApproval": true,
    "...": "other fields the processor needs"
  }
}
```

`isApproval` is required — it drives both the processor branch and the Slack message status text ("Approved by" / "Rejected by").

## Slack message update mechanism

The webhook uses Slack's `response_url` (a one-time authenticated URL in each action payload) to update the original message after enqueuing the job. This requires no bot token permissions for the target channel. If the update fails, the error is logged and the job enqueue is still considered successful — `{ ok: true }` is always returned to Slack to prevent retries.

Prior to PR #1310, `slackClient.chat.update()` was used instead, which required `chat:write` permission and caused `cant_update_message` failures (see ALL-1068).

## Notification templates

| Template | Channel | Used by |
|---|---|---|
| `demoDayInterestApproval.ts` | `slackDemoDayInterest` | Demo Day Intros product |
| `web3JobApplication.ts` | `slackWeb3jobs` | Job Board product |
| `postApproval.ts` | `slackPosts` | Forum/Community product |

## Key files

| Layer | Path |
|---|---|
| Webhook handler | `apps/bullqueue/src/server/routes/slackShortcut.ts` |
| Approval router | `handleQueueBasedApproval` + `getApprovalQueue` in the same file |
| Message builder | `apps/bullqueue/src/utils/notificationBuilder.ts` (`SlackNotificationBuilder`) |
| Notify queue | `packages/queues/src/slackNotify.ts` |
| DD approval queue | `packages/queues/src/demoDayInterestApproval.ts` |
| Job app approval queue | `packages/queues/src/jobApplicationApproval.ts` |
| Post approval queue | `packages/queues/src/postApproval.ts` |
| DD approval processor | `apps/bullqueue/src/jobs/demo-day-interest-approval/processDemoDayInterestApproval.ts` |
| Job app approval processor | `apps/bullqueue/src/jobs/job-application-approval/index.ts` |
| Post approval processor | `apps/bullqueue/src/jobs/post-approval/index.ts` |
| DD approval template | `apps/bullqueue/src/notifications/templates/demoDayInterestApproval.ts` |
| Job app approval template | `apps/bullqueue/src/notifications/templates/web3JobApplication.ts` |
| Post approval template | `apps/bullqueue/src/notifications/templates/postApproval.ts` |
