---
name: error-handling
description: Cross-cutting rules for the unhappy path — whether a failure is surfaced, contained, and recoverable
kind: rule
concern: C4
---

# Error Handling

## Hard rule

Every failure MUST be **surfaced to someone who can act** and MUST leave the system in a state a
retry can recover from. Code that works on the happy path and hangs, corrupts, or silently
swallows on the first failure is the canonical AI-generated-code defect, and it is not a style
issue — a silent catch converts an incident into a mystery.

**Executor.** The code-quality pack's `error-handling-scan` skill is the runnable detector behind
this concern: § 1 the error is dropped, § 2 a failure turned into a success-shaped value, § 3 a
failure signal never read, § 4 an async failure nobody observes, § 5 catch-everything around
business logic, § 6 the cause or the outcome rewritten, § 7 paired state the error path skips —
each proved by a port fault injection, and `/quality-fix` closes them failing-first. `/align`'s
`unhandled-io` and `silent-catch` classes and `/audit`'s Unhandled-I/O pass dispatch it. This
concern stays the method: the four outcomes below are what every error verdict reads, and the
per-surface fingerprints are where to look first. Outbound timeouts, retries and breakers belong
to `@resilience-reviewer` when the distributed-systems pack is installed.

## Per-surface fingerprints

| Surface | The failure that is swallowed | Typical finding |
|---|---|---|
| `audit-log` | a write to the trail fails | the audited action succeeds and its audit record does not — the trail is silently incomplete, which is worse than having no trail, because it is trusted |
| `compliance` | a data-subject request partially fails | export or delete completes for 6 of 8 stores and reports success; the regime is breached and the report says otherwise |
| `multi-tenant` | provisioning fails midway | tenant half-created — some tables scoped, some not — and the retry path assumes a clean slate |
| `settings` | validation fails on one layer of a merge | the merge falls back to defaults silently, so a misconfigured tenant looks correctly configured |
| `streaming-delivery` | a key or segment request fails mid-playback | the player retries forever with no backoff and no user-visible state; a licence failure is indistinguishable from a network blip |

## The four outcomes a failure may have

Exactly one of these, chosen deliberately:

| Outcome | When it is right | When it is the finding |
|---|---|---|
| **Propagate** | the caller can decide | swallowed instead, so nobody decides |
| **Retry** | the failure is transient | retried without backoff or bound, turning a blip into a storm |
| **Compensate** | a partial effect must be undone | partial effect left in place with no compensating action |
| **Degrade** | a reduced result beats none | degraded silently, so a permanent outage looks like normal operation |

`fail-open` and `fail-closed` are both correct answers to different questions — but only when the
choice is written down. An undeclared choice is the finding.

## Per-`project_kind` rendering

| Concern shape | `server` | `browser` | `mobile` | `cli` |
|---|---|---|---|---|
| **Who must learn** | the caller, and the on-call | the user, in the component that failed | the user, plus crash reporting | the exit code, then stderr |
| **The classic miss** | `catch {}` with a log and a `return null` | a spinner that never resolves | a screen stuck loading after a failed refresh | exit `0` after a failed step, so CI goes green |

## Closure verbs

`surface-to-caller` · `bound-the-retry` · `compensate-partial` · `declare-degrade-mode` ·
`fail-the-exit-code` · `render-error-state`
