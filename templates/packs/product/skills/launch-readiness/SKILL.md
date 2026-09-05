---
name: launch-readiness
description: Gate a launch on whether it can be LEARNED FROM — success and counter-metric live and returning data, the rollback path exercised, the decision rule pre-committed with an owner and a date, fatal assumptions tested or accepted, and the reversal path for anything the launch creates. Run before enabling a change for real users. Owns "can we judge this" — deploy mechanics belong to the devops pack and progressive delivery to `progressive-delivery`.
allowed-tools: [Read, Grep, Glob, Bash]
---

# Skill: launch-readiness

## Premise

A launch that cannot be judged is a launch that will be declared a success. The metrics were not instrumented, the counter-metric was not watched, the rollback was never exercised, and six weeks later the change is permanent because nobody can argue against it with anything.

This gate checks exactly one thing: after this ships, will we be able to tell what happened and act on it? It does not check whether the deployment will work — that is the devops pack's job and it is a different question.

## Halt conditions

- **No success definition exists** — run `/define-success` first. There is nothing to gate on.
- **The decision owner is unnamed** — a decision rule with no owner is never executed.
- **The rollback path is unknown** — not "we would revert the deploy", but specifically: what happens to data written under the new behaviour, to notifications already sent, to state already transitioned.
- **The change is irreversible by nature** (a migration, a communication, a deletion) and this has not been acknowledged — the gate changes shape entirely; say so and check the pre-conditions instead of the rollback.

## When to run

- Before enabling a change for real users, whether by deploy, flag, or rollout percentage.
- Before a staged rollout increases its percentage past the point where a rollback stops being cheap.
- After a launch that could not be judged, as a retrospective checklist against the next one.

## Procedure

### 1. Metrics are live, not merely defined

For each of the success metric, the counter-metric, and the guardrails: **run the query now** and confirm it returns data at the expected granularity for the population in scope.

"Defined in the spec" is not live. "The event was added" is not live — the event must be arriving, in the right shape, attributable to the right population. Most launch-day metric failures are events that were implemented and never verified end-to-end.

Record the current value. That baseline is the comparison and it must be captured before, not reconstructed after.

### 2. The counter-metric can move independently

A counter-metric mathematically coupled to the success metric can never contradict it. Check against a historical period where the two diverged; if none exists, say the independence is unverified rather than assuming it.

### 3. The rollback is exercised, not documented

Actually perform the rollback in a non-production environment (or via the flag, in production, for a small percentage) and confirm:
- The behaviour reverts.
- Data written under the new behaviour is still valid, or the migration back is defined.
- Anything emitted under the new behaviour — notifications, webhooks, exports — is accounted for. These are the ones that cannot be rolled back and must be listed explicitly.

A documented rollback that has never been executed is a hypothesis.

### 4. The decision rule is pre-committed

Written, with a threshold, a date, and a named owner, **before** the result is known. Confirm the review is scheduled in a real calendar and not merely intended.

### 5. Fatal assumptions are tested or explicitly accepted

Pull the `fatal × high` rows from `assumption-ledger`. Each is either tested (with the result) or explicitly accepted (with who accepted it). An untested fatal assumption is not automatically a blocker — accepting it can be a legitimate decision — but it must be a *decision*, made by a named person, not an oversight.

### 6. The reversal path exists for what the launch creates

If the change lets users create, share, subscribe, or connect something, the corresponding reversal must exist or be an explicitly communicated gap. This is the business pack's `missing-counterparts` cycle, checked one last time at the point where it is most expensive to have missed.

### 7. Support and communication are ready

Not a formality: if the change alters something users rely on, the people who will receive the questions need to know before the questions arrive. Check that whoever handles support knows what changed, and that any required user-facing notice has gone out.

### 8. Report

```
## launch-readiness — <change> — <date>

| Gate | Status | Evidence |
|------|--------|----------|
| success metric live | pass/fail | query run at <time>, returned <value> |
| counter-metric live | pass/fail | query run at <time>, returned <value> |
| counter-metric independent | pass/fail/unverified | historical divergence at <period> |
| guardrails live | pass/fail | <n>/<n> queried |
| baseline captured | pass/fail | stored at <path> |
| rollback exercised | pass/fail | executed in <env> at <time>, behaviour reverted |
| irreversible emissions listed | pass/fail | <notifications, webhooks, exports> |
| decision rule pre-committed | pass/fail | <rule>, owner <name>, review <date> in calendar |
| fatal assumptions | pass/fail | tested <n> · accepted by <name> <n> · UNADDRESSED <n> |
| reversal path exists | pass/fail/n-a | <what it is, or the communicated gap> |
| support informed | pass/fail | <who, when> |

Verdict: READY | READY WITH ACCEPTED RISK (<named, by whom>) | NOT READY (<gates failing>)
```

## Inputs

- `ai/product/success/<slug>.md` — the success definition ledger.
- `ai/product/assumptions.md` — the fatal rows.
- The rollback procedure, and a non-production environment or a flag to exercise it in.
- Live access to the metric queries.

## Outputs

- The gate table above.
- A `NOT READY` verdict names the failing gates and what would clear each — it is a to-do list, not a veto.
- The captured baseline, stored where the post-launch review will look for it.

## False positives / gotchas

- **Accepting "the event was added" as live.** Verify arrival and attribution end-to-end; this is where most launch-day metric failures originate.
- **A rollback that reverts code but not data.** The interesting part is always the data written in between.
- **Forgetting irreversible emissions.** Notifications and webhooks sent under the new behaviour cannot be recalled; list them so the decision accounts for them.
- **A decision rule with a review date nobody scheduled.** Intention is not a calendar entry.
- **Treating an untested fatal assumption as an automatic blocker.** Accepting risk is legitimate; doing so without a named accepter is not.
- **Gating on deployment readiness.** That is the devops pack. Overlap here dilutes both checks.
- **Running this after the rollout has already started**, when a `NOT READY` verdict is unactionable.

## Related

### Skills
- `assumption-ledger` — supplies the fatal rows.
- `acceptance-criteria-check` — the criteria this launch is expected to satisfy.
- `progressive-delivery` (devops pack) — owns the rollout mechanics this gate presumes exist.

### Agents
- `@product-strategist` — owns the decision rule and the kill criteria.
- `@scope-arbiter` — the reversal check originates in its scope ledger.

### Commands
- `/define-success` — produces the ledger this gate verifies is live.
- `/audit-requirements` — the requirement quality this gate assumes was already reviewed.

### Patterns
- `ai/patterns/problem-framing.md`, `ai/patterns/acceptance-criteria.md`
- `missing-counterparts` (business pack) — the reversal cycle checked here one last time.
