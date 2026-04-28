---
name: missing-counterparts
description: Pattern — every Create needs Delete; every Send needs Resend; every Enable needs Disable. The forward+inverse rule for business cycles.
kind: ai-pattern
pack: business
---

# Pattern: Missing counterparts

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Business cycles`.
>
> - **Cycles audited so far**: `<list>`
> - **Half-cycles flagged**: `<list>`
> - **Resolution path**: `<usually a small UX add — Settings → "Cancel subscription" / Cancel button on invite page>`

## Why this pattern matters

Half-cycles ship constantly because:
- Forward action is the user-facing feature; inverse is "edge case."
- Demos focus on the forward flow.
- Tickets get filed against forward; inverse drops below the line.
- Marketing emphasizes forward; inverse is "minor settings."

Half-cycles HURT because:
- Users feel trapped (signup, no delete).
- Regulators consider half-cycles dark patterns.
- Support load spikes (ticket per missing inverse).
- App store rejections increase (Apple specifically requires account-delete since iOS 16).
- Trust erodes silently — users never come back.

## Forward / inverse table

| Forward | Inverse |
|---|---|
| Sign up | Delete account |
| Subscribe | Unsubscribe / cancel |
| Connect integration | Disconnect |
| Enable feature | Disable feature |
| Add member | Remove member |
| Send invite | Revoke invite |
| Send notification | Mute notification |
| Share | Revoke share |
| Grant permission | Revoke permission |
| Save draft | Discard draft |
| Submit form | Edit before commit / cancel before commit |
| Start subscription trial | End trial early |
| Set reminder | Cancel reminder |
| Bookmark | Unbookmark |
| Follow | Unfollow |
| Block user | Unblock user |
| Hide content | Restore content |
| Schedule | Cancel scheduled |
| Pin | Unpin |
| Pay | Refund (or "request refund") |
| Lock device | Unlock |
| Encrypt | Decrypt |
| Sign | Revoke signature |

## Forward + completion table (where there's no "inverse" but the cycle has a completion)

| Forward | Completion |
|---|---|
| Send email | Delivery confirmation / bounce notification |
| Submit form | Confirmation page + email receipt |
| Trigger background job | Status visible to requester |
| Long-running export | Notification when ready / download link |
| Async approval request | Resolution surfaced to requester |

## Forward + recovery table

| Forward | Recovery from failure |
|---|---|
| Card payment | Try another card / contact bank |
| Form submit | Retry with saved values |
| File upload | Resume from where it failed |
| OTP entry | Resend / call instead |
| Sync to cloud | Retry / save locally / inform user |
| Search | Adjust filters / show "no results" with suggestion |

## Project-specific anchors

(Phase 4.6 fills this with the project's actual list of forward / inverse pairs from `business-flows.md`. Format example below.)

```
| Forward | Inverse | Status | Path |
|---|---|---|---|
| signup.completed | account.deleted | ✓ | Settings → Delete account → confirm |
| subscription.started | subscription.cancelled | ✗ MISSING — file ticket | TBD |
| webhook.connected | webhook.disconnected | ✓ | Integrations → trash icon |
```

## Anti-patterns

- **Inverse exists but hidden behind 5 menus** — measure clicks-to-find. > 3 clicks = effectively not there.
- **Inverse requires support ticket** — shipped, but failed.
- **Inverse only via API** — power-user-only; not real for 99% of users.
- **Inverse confirmed but not actually executed** — "Cancel subscription" shows confirmation but the database row remains active.
- **Inverse without notification to other actors** — admin removes member; member doesn't know they were removed.
- **Inverse without audit log** — compliance gap when someone disputes "who removed my access?"

## Detection

Use `@business-auditor` agent or `check-business-coverage.md` skill to walk every forward action and verify the inverse exists.

Quick heuristic: search the codebase for verbs implying forward actions (create / send / enable / add / submit / start) and confirm a corresponding inverse exists.

## Cross-references

- `business-completeness.md` rule — the principle.
- `@business-auditor` — agent that finds these.
- `check-business-coverage.md` skill — cross-feature audit.
- `audit-funnel-completion.md` skill — per-flow audit.
