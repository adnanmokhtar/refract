---
name: missing-counterparts
description: Pattern — every Create needs Delete; every Send needs Resend; every Enable needs Disable. The forward+inverse rule for business cycles.
kind: ai-pattern
pack: business
---

# Pattern: Missing counterparts

> **Hard rule** — Every forward action ships with its inverse (or completion / recovery counterpart) reachable in ≤ 3 clicks, executed by the system not a support ticket, with audit log + notification to other affected actors. Half-cycles are forbidden.

**When to apply**
- Auditing a feature for completeness before launch (signup → delete, subscribe → cancel).
- App-store submission gates — App Store Review Guideline 5.1.1(v): "If your app supports account creation, you must also offer account deletion within the app" (developer.apple.com/app-store/review/guidelines/ — an unconditional requirement, not keyed to an iOS version).
- Compliance review (GDPR right-to-erasure, dark-pattern audits).

**When NOT to apply**
- Read-only / observational features with no state to invert.
- Legal-hold flows where deletion is intentionally blocked — document the exception, don't add a fake delete.
- One-shot transactions with explicit "no undo" UX (signed contracts, irrevocable transfers).

**Halt conditions / mandatory cites**
- Cite the forward action's handler as `<path:line>` AND the inverse handler as `<path:line>`; missing inverse handler is a halt, not a doc note.
- Cite the UI entry point for the inverse as `<path:line>` (route, settings page, button); inverse-via-API-only is a halt for user-facing features.
- Cite the audit-log emission for the inverse as `<path:line>`; silent inverse is a halt.
- Cite the notification/event emitter for affected actors as `<path:line>` (e.g. member-removed → notify member); silent removal is a halt.
- Hand-wave grep ban — never claim "every forward has an inverse" without citing the cross-feature audit output (`@business-auditor` run path or coverage report).

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Business cycles`.
>
> - **Cycles audited so far**: `<list>`
> - **Half-cycles flagged**: `<list>`
> - **Resolution path**: `<usually a small UX add — Settings → "Cancel subscription" / Cancel button on invite page>`

## What half-cycles actually cost

They ship constantly for a structural reason: the forward action is the feature, the inverse is "the edge case". Demos walk forward. Tickets are filed against forward. The inverse drops below the line every sprint, and each time the reason is locally reasonable.

Six that shipped, and what each one cost — the argument to reach for when someone proposes deferring an inverse:

| Half-cycle that shipped | What it actually cost |
|---|---|
| Subscribe with no unsubscribe | Ratchet-only signup. Rejected by EU users as a dark pattern; pulled from app stores. |
| Order placed, no confirmation email | Funnel conversion looked healthy on the dashboard while support volume climbed — the metric could not see the damage. |
| Admin approval queue with no completion notification | Admins forgot the queue existed; requesters waited hours for a decision already made. |
| Password-reset email whose link expired immediately | Users locked out of their own accounts; every one became a support escalation. |
| CSV export stuck "running" forever | Users cancelled and retried, duplicating background jobs — the missing status surface manufactured the load. |
| Empty-query search → blank screen | Read as "the product is broken"; users bounced rather than reporting it. |

The pattern in all six: the forward action worked, the metric looked fine, and the cost landed somewhere the team was not measuring — support, trust, the store review, the job queue. That is why a half-cycle is a defect at ship time and not a backlog item.

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
- `@workflow-integrity` — the state-graph counterpart to this pattern. This pattern audits **cycle-pair existence** (does the paired inverse/completion/recovery verb exist); workflow-integrity audits the **state graph between an entity's states** (are the transitions legal, guarded, terminal, reachable). They meet but do not overlap — run both.
- `@domain-model-auditor` — the aggregate-structure counterpart. This pattern audits whether the paired verb *exists* (create↔delete); domain-model-auditor audits whether the entity behind it is a real aggregate that *owns its invariants* (or an anemic bag whose rules leaked to a service, with invariants enforced nowhere). Cycle-pair existence is orthogonal to invariant enforcement — run both on a rich-domain feature.
