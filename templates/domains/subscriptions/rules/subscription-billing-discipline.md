---
name: subscription-billing-discipline
description: Subscription billing discipline
kind: rule
---

# Subscription billing discipline

## Hard rule

> The subscription is a STATE MACHINE owned by the provider and mirrored locally — local state MUST reconcile with the provider and MUST NEVER diverge. Entitlements MUST be DERIVED server-side from the current subscription state; the client MUST NEVER be trusted to assert what it can access. Renewal charges MUST be idempotent with a key derived from `sub:<id>:period:<n>` — NEVER random, NEVER `uuid()` per attempt. A single failed renewal MUST trigger dunning + a grace period — NEVER an instant lockout. Proration MUST be computed in integer minor units via payment's `Money` — NEVER floats. Every state transition MUST be driven by a verified, deduped provider webhook. Revenue events (MRR/ARR) MUST be derived from state transitions exactly once — NEVER double-counted.

A subscription bug is a recurring bug: it bills the same customer wrong every cycle, locks paying users out on a transient decline, or silently leaks access to churned ones. The blast radius is the whole book of business, compounding monthly. This rule builds ON `<rules-path>/payment-idempotency.md` (Money, idempotency keys, server-computed amounts) and `<rules-path>/webhook-signature-verification.md` (verified, deduped transitions) — read those first.

## Must

- **Subscription as a state machine.** Model the lifecycle explicitly: `trialing → active → past_due → canceled`, plus `unpaid` (dunning exhausted) and `paused`. Transitions are a closed set; an `UPDATE subscriptions SET status = ?` to an arbitrary string is FORBIDDEN. Persist the current `status`, `current_period_start`, `current_period_end`, `cancel_at_period_end`, and the provider's `subscription_id`.
- **Provider is the source of truth; local state mirrors it.** The provider (Stripe / Paddle / Chargebee / etc.) owns the canonical lifecycle. Local state is a projection updated from `customer.subscription.*` / `invoice.*` webhooks. A reconciliation cron pulls the provider's subscription list daily and repairs drift (status mismatch / period mismatch / missing-locally / missing-at-provider). Local-only mutation of `status` without a corresponding provider transition is FORBIDDEN.
- **Entitlements derived server-side from state.** Feature gates read the CURRENT entitlement, computed server-side from `(status, plan, grace_until)`. `trialing` and `active` (and `past_due` while within grace) grant entitlements; `unpaid` / `canceled` (past period end) / `paused` revoke them. The client receives a computed entitlement snapshot — it NEVER asserts its own plan or access.
- **Grace period after payment failure.** A failed renewal moves the subscription to `past_due` and starts a grace window (`grace_until`); entitlements REMAIN until grace expires or dunning is exhausted. Revocation is gated on `now > grace_until AND dunning_exhausted`, never on the first decline.
- **Idempotent renewal charges.** The renewal charge for a period carries an idempotency key derived from `sub:<id>:period:<n>` (period sequence number, not a timestamp, not random). A retried renewal for the same period returns the cached charge — NEVER a second charge. (See `<rules-path>/payment-idempotency.md`.)
- **Proration in integer minor units.** Upgrade/downgrade proration is computed with payment's `Money` (integer minor units + currency tag). Credit for unused time + charge for new plan time are integer math; the residual rounding policy is documented (round the credit DOWN or the charge to the customer's favour, consistently). Float arithmetic on proration is FORBIDDEN.
- **Upgrade vs downgrade timing.** Upgrades apply IMMEDIATELY with a prorated charge for the remainder of the period. Downgrades apply at PERIOD END (a scheduled change), so the customer keeps what they paid for. The scheduled change is persisted and applied on the period-boundary webhook — never silently dropped.
- **Trial integrity.** Trial length, card-required-or-not, and conversion behaviour are explicit per plan. Trial-to-paid conversion fires on the trial-end webhook (`customer.subscription.trial_will_end` → conversion attempt). Trial abuse is bounded per customer AND per payment-method/device fingerprint — not per email (emails are free).
- **Dunning, not instant cancellation.** A failed renewal enters a retry schedule (smart retries: e.g. day 1, 3, 5, 7 with backoff), sends customer notifications at each step, and only after the schedule is exhausted transitions to `unpaid`/`canceled`. The grace period spans the dunning window.
- **Invoice immutability + tax server-side.** An invoice is generated per cycle, is IMMUTABLE once issued, and computes tax/VAT server-side at issue time (stored on the invoice, never recomputed). Corrections (refunds, proration credits) are issued as CREDIT NOTES referencing the original invoice — the original is never edited.
- **Cancellation policy explicit.** Immediate vs end-of-period cancellation is a deliberate choice (default end-of-period via `cancel_at_period_end`). Reactivation before period end clears the flag. Refund-on-cancel policy (none / prorated / full) is documented and enforced server-side. Data retention after churn honours the dispute + regulatory window (see `<rules-path>/payment-idempotency.md § dispute window`).
- **Metered usage idempotent.** Usage records are idempotent per `(subscription_item, idempotency_key)` so a retried report doesn't double-count. Aggregation windows align to the billing period; overage is billed on the period invoice.
- **MRR/ARR derived from transitions, once.** Revenue events (new / expansion / contraction / churn / reactivation) are emitted from state transitions, each transition emitting AT MOST ONE revenue event, deduped by `(subscription_id, period, transition_type)`. Reports read these events; they never re-derive revenue from mutable current state.

## Must not

- Mutate `subscriptions.status` locally without a corresponding provider transition (drift; reconciliation will fight you).
- Trust the client for entitlement (`if (user.plan === 'pro')` from a client-supplied field) — recompute server-side from subscription state.
- Revoke access on the FIRST failed renewal (no grace, no dunning) — paying customers locked out by a transient decline churn.
- Derive the renewal idempotency key from `uuid()` / `Date.now()` / the attempt number — defeats dedupe, double-bills on retry.
- Compute proration / credit in floats. Fractional-cent drift recurs every cycle for the life of the subscription.
- Apply a downgrade immediately (customer paid for the higher tier through period end) or an upgrade silently at period end (they paid for it now).
- Edit an issued invoice. Issue a credit note instead — invoices are immutable financial records.
- Rate-limit trial abuse by email only — disposable emails are free; bound by payment method / device fingerprint.
- Emit a revenue event per webhook delivery without dedupe — provider retries double-count MRR.
- Run any state transition off an UNVERIFIED or UNDEDUPED webhook (see `<rules-path>/webhook-signature-verification.md`).
- Let a refund or proration credit skip the invoice/credit-note ledger — reports then disagree with the provider.

## Should

- Wrap the provider's billing SDK behind a project-internal `<BillingGateway>` interface (create/update/cancel subscription, preview proration, report usage) so a provider swap is a single-file refactor — mirrors payment's `<PaymentGateway>`.
- Model the lifecycle as an explicit transition table (`from_status × event → to_status`) and reject transitions outside it; log `subscription_invalid_transition` on violation.
- Compute proration via the provider's PREVIEW endpoint (`upcoming invoice` / `preview`) and assert it equals your local `Money` computation — a mismatch is a bug in one of them.
- Notify the customer at each dunning step (failure, retry scheduled, final warning, cancellation) and on trial-end, upcoming-renewal, and price-change.
- Persist the `webhook_events` row (verified, deduped) BEFORE applying the transition — the row IS the transition's audit trail and replay primitive.
- Run a daily reconciliation cron diffing local subscriptions against the provider (status, period bounds, plan, cancel flag) and alert on any drift.
- Log structured `{ subscriptionId, fromStatus, toStatus, period, eventId, plan, mrrDeltaMinor }` on every transition.
- Store the entitlement snapshot the gate reads in a single derivation function (`entitlementsFor(subscription)`) so every surface computes access identically.

## Review checklist (PRs touching subscription state / billing / entitlements / renewals)

- [ ] Status changes go through the closed transition table, driven by a verified+deduped webhook — no ad-hoc `status = ?`.
- [ ] Entitlements are computed server-side from `(status, plan, grace_until)`; no client-asserted plan/access.
- [ ] A failed renewal enters dunning + grace; revocation gated on `now > grace_until AND dunning_exhausted`, not the first decline.
- [ ] Renewal charge idempotency key = `sub:<id>:period:<n>` (or equivalent stable derivation) — not random, not timestamp.
- [ ] Proration uses `Money` (integer minor units); residual rounding policy is documented and consistent.
- [ ] Upgrade = immediate + prorate; downgrade = scheduled at period end and persisted.
- [ ] Trials: length + card-required + conversion explicit; abuse bounded by payment-method/fingerprint, not email.
- [ ] Invoices immutable; refunds/proration emit credit notes referencing the original; tax computed + stored server-side at issue.
- [ ] Metered usage records idempotent per `(item, key)`; aggregation aligned to the billing period.
- [ ] Revenue events emitted once per transition, deduped by `(subscriptionId, period, type)`; reports read events, not mutable state.
- [ ] Reconciliation cron diffs local vs provider and alerts on drift.

## Anti-patterns

- **Client-trusted entitlement** — `if (req.user.plan === 'pro') allow()` from a JWT claim the client refreshed once and never re-checked. The gate must read server-derived current entitlement; a downgraded user keeps `pro` in a stale token.
- **Instant lockout on one decline** — `invoice.payment_failed` → immediately `canceled` + revoke. A paying customer's card hiccups on renewal and they lose access mid-session. Always dunning + grace first.
- **Proration in floats** — `credit = price * daysLeft / daysInPeriod` as a float. Fractional cents accrue every plan change for every customer, forever. Integer `Money` math with a documented rounding side.
- **Downgrade applied immediately** — customer downgrades pro→basic mid-period, instantly loses pro features they already paid for through period end. Schedule the change for period end.
- **Non-idempotent renewal** — renewal job retries after a network blip with a fresh `uuid()` key → customer charged twice for one period → refund + churn. Key = `sub:<id>:period:<n>`.
- **Local state drift** — operator "comp"s a subscription by setting `status='active'` in the DB; the provider still shows `canceled`; reconciliation flaps; the next webhook overwrites it. Drive the change through the provider (or a documented provider-side comp).
- **Trial abuse by email** — abuse limit keyed on email. Attacker spins up `a+1@`, `a+2@` … unlimited trials. Bound by payment-method fingerprint / device.
- **Edited invoice** — refund issued by editing the original invoice's total. The immutable financial record now lies; tax filings drift. Issue a credit note.
- **Revenue double-count** — `customer.subscription.updated` retried by the provider → expansion MRR counted twice → board deck shows phantom growth. Dedupe revenue events by `(subscriptionId, period, type)`.
- **Usage double-report** — metered usage reported again on job retry without an idempotency key → customer over-billed for overage. Idempotent usage records.
- **Tax recomputed at read time** — invoice shows a different VAT than when issued because the rate changed. Compute + freeze tax on the invoice at issue.
- **Orphaned scheduled change** — a scheduled downgrade is stored but no period-boundary handler applies it; the customer stays on the old plan forever. Apply scheduled changes on the period-end transition.

## Enforcement

- `<commands-path>/simulate-renewal.md` (slash: `/simulate-renewal` and `/simulate-renewal --fail`) — replays a renewal cycle and a failed-renewal/dunning cycle against the LOCAL dev server from sanitised fixtures; cite-or-halt on fixture path + response status + DB-state delta + resulting entitlement state. Verifies idempotent renewal, dunning/grace, and that entitlements track state.
- `<agents-path>/subscription-reviewer.md` — review gate hard-failing on client-trusted entitlements, float proration, missing dunning/grace, non-idempotent renewals, local↔provider drift, trial abuse holes, refund/credit not reflected in invoices, and revenue double-count.
- CI lint MUST reject `subscriptions` status writes outside the transition module (AST: `UPDATE ... status` / `.status =` on the subscription entity outside the allowed state-machine file).
- CI lint MUST reject `subscriptions.*\.create(` / `invoiceItems.create(` / renewal-charge calls without a passed idempotency key (mirrors payment's lint).
- CI lint MUST reject float arithmetic (`* `, `/ `) on fields named like money/proration/credit/tax outside the `Money` module.
- Nightly reconciliation job MUST run; missing run for > 36h pages on-call.
- TODO: `scripts/validate-subscription-state-machine.sh` to AST-walk subscription services and assert every status mutation flows through the transition table AND every renewal charge passes a `sub:<id>:period:<n>`-shaped key.

## Cross-references

- `<rules-path>/payment-idempotency.md` — Money, idempotency keys, server-computed amounts, dispute-window retention. This rule builds directly on it.
- `<rules-path>/webhook-signature-verification.md` — verified + deduped webhooks; every subscription transition is webhook-driven.
- `<patterns-path>/subscription-lifecycle.md` — state-machine + entitlement derivation + proration + dunning code shapes.
- `<patterns-path>/payment-integration.md` — `PaymentGateway`, Money type, webhook handler shape the renewal charge reuses.
- `<patterns-path>/webhook-flow.md` — generic verify → dedupe → process inbound shape the transition handler follows.
- `<commands-path>/simulate-renewal.md` — local renewal + dunning fixture-replay tool.
- `<agents-path>/subscription-reviewer.md` — review gate.
- `<adr-path>/<NNN>-subscription-provider-choice.md` — ADR pinning the chosen billing provider + proration/dunning policy.
