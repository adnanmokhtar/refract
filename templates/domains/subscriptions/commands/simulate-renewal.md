---
description: Replay a subscription renewal cycle (and a failed-renewal / dunning cycle) against the local dev server to verify idempotent renewal, dunning/grace, and that entitlements track state.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /simulate-renewal

Exercise renewal + dunning handling without pinging the real billing provider. Replays a recorded (sanitised) renewal webhook cycle against the LOCAL dev server and asserts the subscription state machine, the renewal charge idempotency, the grace/dunning path, and the resulting entitlements all behave. Sibling to `/replay-charge` — that one verifies a single charge/webhook; this one verifies a full billing CYCLE.

## Premise

Real signals only. Cite the actual fixture filename, the computed provider signature header, the HTTP status from the local endpoint, the DB-state delta (subscription `status` / `current_period_end` / `period_seq`, the renewal charge row, the invoice/credit-note row, the revenue event), AND the resulting entitlement state (`entitlementsFor(sub)` output) — never narrate a cycle you didn't run. Read before writing: confirm the fixture exists at `test/fixtures/subscriptions/<name>.json` and is sanitized (no live keys, no real PANs, no real customer identifiers) BEFORE POSTing.

## Mechanical halt

Cite-or-halt: every reported result MUST include, per posted event —
1. the **fixture path**,
2. the **response status**,
3. at least one **DB-state line** (the subscription/charge/invoice/revenue delta, or "no change" with a query showing it), AND
4. the **resulting entitlement state** (what `entitlementsFor` returns for the subscription after the event).

LOCAL ONLY — refuse to run if the target URL resolves outside `localhost` / `127.0.0.1` / an explicit `--target` non-prod dev host. Negative paths (duplicate event, tampered signature, double renewal for the same period) MUST show the ACTUAL response code / DB result, not an assumed one.

## Setup

Fixtures at `test/fixtures/subscriptions/` — recorded real (sanitized!) billing webhook payloads from the provider's test mode:
- `invoice.payment_succeeded.json` — successful renewal for a period.
- `invoice.payment_failed.json` — failed renewal (declined card) → enters dunning.
- `invoice.payment_succeeded.retry.json` — dunning retry that recovers (same period as the failure).
- `customer.subscription.trial_will_end.json` — trial-end signal (conversion attempt).
- `customer.subscription.updated.json` — plan change / scheduled-downgrade applied at period boundary.
- `customer.subscription.deleted.json` — cancellation (churn).
- `invoice.payment_succeeded.duplicate.json` — same `event.id` as the renewal fixture (tests idempotency).

NEVER include real card numbers, live keys, or real customer identifiers in fixtures. The `subscription_id` / `customer_id` must resolve to a SEEDED local subscription; if not, halt with the seeding hint.

## Flow

### Happy renewal (`/simulate-renewal`)
1. Load `invoice.payment_succeeded.json` for a seeded subscription.
2. Compute the provider's signature header (`Stripe-Signature`, etc.) using the dev webhook secret.
3. POST to the local billing webhook endpoint.
4. Report, per the mechanical-halt contract:
   - status + response time
   - subscription delta: `status` (→ `active`), `current_period_end` advanced, `period_seq` incremented
   - renewal charge row (one charge, idempotency key = `sub:<id>:period:<n>`)
   - invoice row issued (immutable; tax frozen)
   - revenue event emitted ONCE (`renewal`)
   - entitlement state: `entitlementsFor(sub)` grants the plan's features
5. **Idempotency negative test**: POST `invoice.payment_succeeded.duplicate.json` (same `event.id`) → expect 200 "already processed", NO second charge, NO second revenue event, NO double period advance. Cite the unchanged charge/revenue/period rows.

### Failed renewal + dunning (`/simulate-renewal --fail`)
1. POST `invoice.payment_failed.json`.
2. Report:
   - status
   - subscription delta: `status` → `past_due`, `grace_until` set, `period_seq` UNCHANGED
   - dunning retries scheduled (cite the schedule rows / job), customer notified
   - entitlement state: `entitlementsFor(sub)` STILL grants features (within grace) — assert NOT revoked
3. POST `invoice.payment_succeeded.retry.json` (recovery, SAME period):
   - subscription delta: `status` → `active`, `grace_until` cleared, period advances
   - renewal charge: SAME idempotency key as the failed attempt's period (`sub:<id>:period:<n>`) — assert the recovery did NOT mint a second charge for the period
   - entitlement state: retained
4. **Grace-exhaustion path** (optional `--exhaust`): simulate dunning exhausted → `unpaid` → assert entitlements revoke ONLY after `now > grace_until AND dunning_exhausted`.

### Plan change / cancel (optional)
- `customer.subscription.updated.json` → assert a SCHEDULED downgrade applies at the period boundary (not immediately) and that an upgrade applies immediately with prorated `Money` (integer minor units).
- `customer.subscription.deleted.json` → assert `canceled`, entitlements revoked at period end, a `churn` revenue event emitted ONCE.

## Negative tests (must show actual results)

- **Duplicate event id** → second POST returns 200 "already processed"; no new charge / invoice / revenue / transition.
- **Tampered signature** → 401; no state change.
- **Double renewal for the same period** → the second charge attempt with key `sub:<id>:period:<n>` returns the cached charge, NOT a new one (assert one charge row for the period).
- **Instant-lockout regression guard** → after `--fail`, assert entitlements are STILL granted within grace (a failed renewal must not revoke immediately).

## Usage

```bash
.claude/skills/simulate-renewal.sh                                   # happy renewal, localhost
.claude/skills/simulate-renewal.sh --fail                            # failed renewal → dunning → recovery
.claude/skills/simulate-renewal.sh --fail --exhaust                  # dunning exhausted → unpaid → revoke
.claude/skills/simulate-renewal.sh invoice.payment_succeeded.json    # specific fixture
.claude/skills/simulate-renewal.sh -u http://localhost:3000          # explicit dev target
```

Or slash: `/simulate-renewal` and `/simulate-renewal --fail`.

## Rules

- LOCAL ONLY. Never point at prod. Refuse any non-`localhost` / non-explicit-dev target.
- Dev webhook secret separate from prod.
- Fixtures sanitized — no real card numbers, live keys, or real customer identifiers.
- Every reported event prints fixture path + response status + DB-state delta + resulting entitlement state (the cite-or-halt contract). No narration without those four.
- Renewal charges in fixtures + assertions use the `sub:<id>:period:<n>` idempotency key — a replay must never produce a second charge for a period.

## Cross-references

- `<commands-path>/replay-charge.md` — single charge/webhook replay (this command's payment-layer sibling).
- `<commands-path>/simulate-webhook.md` — generic webhook fixture replay + tampered-signature test.
- `<rules-path>/subscription-billing-discipline.md` — the rules this command verifies (idempotent renewal, dunning/grace, derived entitlements, MRR-once).
- `<patterns-path>/subscription-lifecycle.md` — the state machine + renewal + dunning + entitlement code shapes under test.
- `<agents-path>/subscription-reviewer.md` — review gate that requires this command's evidence on renewal/dunning PRs.
