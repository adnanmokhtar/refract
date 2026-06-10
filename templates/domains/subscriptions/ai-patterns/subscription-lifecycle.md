---
name: subscription-lifecycle
description: "Pattern: Subscription lifecycle (provider-driven state machine + derived entitlements)"
kind: ai-pattern
---

# Pattern: Subscription lifecycle (provider-driven state machine + derived entitlements)

> **Hard rule** — The subscription is a provider-owned state machine mirrored locally; local state reconciles with the provider and never diverges. Entitlements are DERIVED server-side from `(status, plan, grace_until)` — the client never asserts access. Renewal charges are idempotent with key `sub:<id>:period:<n>` (never random). Proration is integer minor units via payment's `Money` (never floats). A failed renewal enters dunning + grace — never an instant lockout. Every transition is driven by a verified, deduped webhook.

**When to apply**
- Any product with recurring billing: SaaS plans, seats, metered/usage, trials, paid tiers via an external billing provider (Stripe Billing, Paddle, Chargebee, Recurly, Paymob recurring).
- Plan changes (upgrade/downgrade), trials with or without a card, dunning on failed renewals.
- MRR/ARR reporting derived from lifecycle events.

**When NOT to apply**
- One-off payments / checkout with no recurrence — use `<patterns-path>/payment-integration.md` directly; the lifecycle/state-machine machinery is overhead.
- Internal-only entitlements with no money movement (feature flags by role) — use the feature-flag signal, not billing.
- Crypto / on-chain recurring settlement — different renewal + idempotency model (chain confirmations, not provider event ids).

**Halt conditions / mandatory cites**
- Cite the subscription state machine (status enum + transition table) at `<path:line>`. Ad-hoc `status = <string>` writes outside it = halt.
- Cite the server-side entitlement derivation `entitlementsFor(subscription)` at `<path:line>`. Client-asserted plan/access = halt.
- Cite the renewal idempotency-key derivation at `<path:line>` — must be `sub:<id>:period:<n>`-shaped, NOT `uuid()`.
- Cite the proration computation using `Money` at `<path:line>`. Float math on proration/credit = halt.
- Cite the dunning schedule + grace-period gate at `<path:line>`. Instant revoke on first decline = halt.
- Cite the webhook-driven transition handler (verified + deduped) at `<path:line>`. Local-only transitions = halt.
- Grep ban: "the provider handles renewals" without file:line for the gateway, the entitlement derivation, the renewal idempotency key, the dunning gate, and the reconciliation cron.

## Why

Billing providers (Stripe ≠ Paddle ≠ Chargebee) own the canonical subscription lifecycle and differ deeply in detail: proration semantics, trial-end signalling, dunning/smart-retry behaviour, invoice + tax handling, webhook event vocabulary. The right pattern is a SMALL `BillingGateway` adapter (mirroring payment's `PaymentGateway`) plus a LOCAL state machine that mirrors the provider and a SINGLE server-side entitlement derivation every gate reads.

This isolates: provider event-name differences, proration math, trial signalling, the dunning schedule, invoice/tax conventions — and keeps the rest of the app reading one clean `(status, plan, grace_until) → entitlements` function.

## The state machine

```text
                 trial_will_end / payment_succeeded
   ┌──────────┐  ──────────────────────────────────►  ┌──────────┐
   │ trialing │                                        │  active  │
   └────┬─────┘  ◄──────── reactivate ───────────────  └────┬─────┘
        │ trial ends, no card / fails                       │ renewal payment_failed
        ▼                                                   ▼
   ┌──────────┐                                        ┌──────────┐
   │ canceled │  ◄──── dunning exhausted ────────────  │ past_due │ ── payment_succeeded ─► active
   └──────────┘            (→ unpaid → canceled)        └──────────┘
        ▲                                                   │
        │ cancel (immediate)        pause                   │ within grace → entitlements RETAINED
        │                            ▼                       │
        └────────────────────── ┌────────┐ ◄── resume ──────┘
                                 │ paused │
                                 └────────┘
```

States: `trialing`, `active`, `past_due`, `unpaid`, `canceled`, `paused`. Transitions are a CLOSED set driven by provider webhooks. `cancel_at_period_end` is a flag on `active` (not a state) — the subscription stays `active` until the period boundary, then transitions to `canceled`.

## Billing gateway interface

```ts
// src/modules/subscriptions/core/interfaces/billing-gateway.interface.ts

export interface BillingGateway {
  /** Create a subscription (with optional trial). Idempotent — caller's key MUST pass through. */
  createSubscription(input: CreateSubInput): Promise<SubResult>;

  /** Change plan. proration policy decides immediate vs scheduled. Idempotent. */
  changePlan(subId: string, newPlan: PlanId, when: 'now' | 'period_end', idempotencyKey: string): Promise<SubResult>;

  /** Preview proration for a plan change WITHOUT applying it (provider 'upcoming invoice'). */
  previewProration(subId: string, newPlan: PlanId): Promise<ProrationPreview>;

  /** Cancel — immediate or at period end. */
  cancel(subId: string, when: 'now' | 'period_end', idempotencyKey: string): Promise<SubResult>;

  /** Report metered usage. Idempotent per (item, key). */
  reportUsage(itemId: string, quantity: number, idempotencyKey: string): Promise<void>;

  /** Verify a webhook signature against raw body (delegates to PaymentGateway scheme). */
  verifyWebhook(rawBody: Buffer, signatureHeader: string): { ok: boolean; event?: WebhookEvent };
}

export type SubStatus = 'trialing' | 'active' | 'past_due' | 'unpaid' | 'canceled' | 'paused';

export type SubResult = {
  status: SubStatus;
  subscriptionId: string;
  currentPeriodStart: Date;
  currentPeriodEnd: Date;
  cancelAtPeriodEnd: boolean;
  plan: PlanId;
};

export type ProrationPreview = {
  creditUnusedTime: Money;   // integer minor units
  chargeNewPlan: Money;      // integer minor units
  netDue: Money;             // chargeNewPlan - creditUnusedTime, never negative below a documented floor
};
```

Application code returns these shapes; no `Stripe.Subscription` types leak out. `Money` is payment's value object — reused, not re-invented (see `<patterns-path>/payment-integration.md § Money`).

## The transition table (closed set)

```ts
// src/modules/subscriptions/core/state-machine.ts

type Event =
  | 'payment_succeeded' | 'payment_failed' | 'dunning_exhausted'
  | 'trial_will_end' | 'cancel_now' | 'period_end_cancel' | 'pause' | 'resume' | 'reactivate';

const TRANSITIONS: Record<SubStatus, Partial<Record<Event, SubStatus>>> = {
  trialing:  { payment_succeeded: 'active', trial_will_end: 'active', payment_failed: 'past_due', cancel_now: 'canceled' },
  active:    { payment_failed: 'past_due', cancel_now: 'canceled', period_end_cancel: 'canceled', pause: 'paused' },
  past_due:  { payment_succeeded: 'active', dunning_exhausted: 'unpaid', cancel_now: 'canceled' },
  unpaid:    { payment_succeeded: 'active', cancel_now: 'canceled' },
  canceled:  { reactivate: 'active' },
  paused:    { resume: 'active', cancel_now: 'canceled' },
};

export function next(from: SubStatus, event: Event): SubStatus {
  const to = TRANSITIONS[from]?.[event];
  if (!to) throw new InvalidSubscriptionTransitionError(from, event);   // log + reject; never silently mutate
  return to;
}
```

Any code path that wants to change `status` MUST go through `next()`. An `UPDATE subscriptions SET status = 'active'` anywhere else is the bug the reviewer hunts.

## Entitlements derived server-side

> The TypeScript example below uses NestJS-style decorators for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the framework decorators (Express / FastAPI / Spring / Rails / etc.), the guard/middleware mechanism, and the plan→features map your project defines. The SHAPE — derive entitlements from `(status, plan, grace_until)` server-side, gate on the derived snapshot — is what's universal.

```ts
// src/modules/subscriptions/core/entitlements.ts

/** The ONLY place entitlements are computed. Every gate reads this. */
export function entitlementsFor(sub: Subscription, now: Date): Entitlements {
  const active =
    sub.status === 'trialing' ||
    sub.status === 'active' ||
    (sub.status === 'past_due' && sub.graceUntil != null && now <= sub.graceUntil); // grace window

  if (!active) return Entitlements.none();          // unpaid / canceled / paused / grace-expired → revoked
  return PLAN_FEATURES[sub.plan];                   // plan → feature set, server-defined
}
```

```ts
// src/modules/subscriptions/guards/feature.guard.ts

@Injectable()
export class FeatureGuard implements CanActivate {
  constructor(@Inject(SUBSCRIPTION_REPO) private subs: SubscriptionRepository) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    const required = this.reflector.get<Feature>('feature', ctx.getHandler());

    // Load CURRENT subscription server-side — never trust a plan claim from the token/body.
    const sub = await this.subs.findActiveForTenant(req.tenantId);
    const entitlements = entitlementsFor(sub, new Date());

    if (!entitlements.has(required)) throw new ForbiddenException('feature_not_in_plan');
    return true;
  }
}
```

The client receives a computed entitlement snapshot for UX (hide/show), but the SERVER gate is authoritative. A downgraded user with a stale `plan: 'pro'` token is still denied — the gate re-derives from current state.

## Renewal charge (idempotent per period)

```ts
// src/modules/subscriptions/core/services/renewal.service.ts

@Injectable()
export class RenewalService {
  constructor(
    @Inject(PAYMENT_GATEWAY) private payments: PaymentGateway,   // reuse payment's gateway
    @Inject(SUBSCRIPTION_REPO) private subs: SubscriptionRepository,
    @Inject(DUNNING) private dunning: DunningService,
    private logger: Logger,
  ) {}

  async chargeRenewal(subId: string): Promise<ChargeResult> {
    const sub = await this.subs.findOrThrow(subId);

    // Period sequence number → STABLE idempotency key. Retried renewal returns cached charge.
    const idempotencyKey = `sub:${sub.id}:period:${sub.periodSeq}`;

    const result = await this.payments.charge({
      amount: sub.renewalAmount,            // Money — integer minor units, server-computed from the plan
      paymentMethodId: sub.defaultPaymentMethodId,
      customerId: sub.providerCustomerId,
      capture: 'auto',
      offSession: true,                     // unattended renewal — declares SCA off-session intent
      idempotencyKey,
      metadata: { subscriptionId: sub.id, period: String(sub.periodSeq), tenantId: sub.tenantId, correlationId: this.ctx.correlationId },
    });

    switch (result.status) {
      case 'succeeded':
        await this.subs.applyTransition(sub.id, 'payment_succeeded', { advancePeriod: true });
        return result;
      case 'failed':
        // NOT an instant lockout — enter dunning + start grace.
        await this.subs.applyTransition(sub.id, 'payment_failed', { graceUntil: this.dunning.graceUntil(sub) });
        await this.dunning.scheduleRetries(sub, result.declineCode);
        this.logger.warn({ subId, declineCode: result.declineCode, period: sub.periodSeq }, 'renewal_declined');
        return result;
      case 'requires_action':
        // off-session SCA — provider/customer must authenticate; keep past_due within grace
        await this.subs.applyTransition(sub.id, 'payment_failed', { graceUntil: this.dunning.graceUntil(sub) });
        await this.dunning.requestAuthentication(sub, result.clientSecret);
        return result;
      case 'pending':
        return result;   // async settlement; webhook resolves the transition
    }
  }
}
```

Idempotency key derives from the period sequence, not random and not the wall clock — a retried renewal for period N returns the same charge. (See `<rules-path>/payment-idempotency.md`.)

## Proration (integer minor units)

```ts
// src/modules/subscriptions/core/proration.ts

/** Upgrade: credit unused time on the old plan, charge prorated new plan for the remainder. Integer math only. */
export function prorate(
  oldPlanPrice: Money, newPlanPrice: Money,
  periodStart: Date, periodEnd: Date, changeAt: Date,
): ProrationPreview {
  const totalSecs    = Math.round((+periodEnd - +periodStart) / 1000);
  const remainingSecs = Math.max(0, Math.round((+periodEnd - +changeAt) / 1000));

  // credit = oldPrice * remaining/total ; charge = newPrice * remaining/total — minor units, integer.
  const credit = oldPlanPrice.mulFraction(remainingSecs, totalSecs, 'down');   // round DOWN → customer's favour
  const charge = newPlanPrice.mulFraction(remainingSecs, totalSecs, 'down');

  const net = charge.subtract(credit);
  return { creditUnusedTime: credit, chargeNewPlan: charge, netDue: net.isNegative() ? Money.zero(charge.currency) : net };
}
```

`Money.mulFraction(numerator, denominator, rounding)` does `floor((amountMinor * num) / den)` (or the documented rounding side) — never float. Cross-check against `gateway.previewProration()`; a mismatch is a bug in one of the two. (`Money` is payment's value object — extend it there, don't fork it.)

## Plan change (upgrade now, downgrade at period end)

```ts
async changePlan(subId: string, newPlan: PlanId): Promise<SubResult> {
  const sub = await this.subs.findOrThrow(subId);
  const isUpgrade = PLAN_RANK[newPlan] > PLAN_RANK[sub.plan];

  const idempotencyKey = `sub:${sub.id}:planchange:${sub.planChangeCount + 1}`;

  if (isUpgrade) {
    // Immediate + prorated charge for the remainder of the period.
    const result = await this.gateway.changePlan(subId, newPlan, 'now', idempotencyKey);
    await this.subs.recordPlanChange(sub.id, newPlan, 'applied');
    return result;   // entitlements widen immediately (entitlementsFor re-derives from new plan)
  }

  // Downgrade: schedule at period end — customer keeps what they paid for.
  const result = await this.gateway.changePlan(subId, newPlan, 'period_end', idempotencyKey);
  await this.subs.recordScheduledChange(sub.id, newPlan, sub.currentPeriodEnd);
  return result;     // entitlements stay on the old (higher) plan until the period-end webhook applies the change
}
```

The scheduled downgrade is persisted; the period-boundary webhook (`customer.subscription.updated` with the new plan effective) applies it. An orphaned scheduled change that never applies is the bug.

## Webhook-driven transitions (verified + deduped)

```ts
// src/modules/webhooks/billing.controller.ts  — follows <patterns-path>/webhook-flow.md exactly

@Post('/webhooks/billing')
async receive(@RawBody() raw: Buffer, @Headers('stripe-signature') sig: string) {
  const v = this.gateway.verifyWebhook(raw, sig);
  if (!v.ok) throw new UnauthorizedException();            // 401 on mismatch

  const event = v.event!;
  const fresh = await this.events.recordOnce('billing', event.id, event);  // (provider, event_id) UNIQUE
  if (!fresh) return { received: true };                   // duplicate — already transitioned

  await this.queue.add('billing-event', { eventId: fresh.id });
  return { received: true };                               // ack fast
}
```

```ts
// worker — maps provider events to state-machine events, applies the transition, emits revenue once
async function handleBillingEvent(event: WebhookEvent) {
  switch (event.type) {
    case 'invoice.payment_succeeded':
      await subs.applyTransition(event.subId, 'payment_succeeded', { advancePeriod: true });
      await revenue.emitOnce(event.subId, event.period, 'renewal');     // deduped by (sub, period, type)
      break;
    case 'invoice.payment_failed':
      await subs.applyTransition(event.subId, 'payment_failed', { graceUntil: dunning.graceUntil(event) });
      await dunning.scheduleRetries(event.subId, event.declineCode);
      break;
    case 'customer.subscription.trial_will_end':
      await notifications.trialEnding(event.subId);
      break;
    case 'customer.subscription.updated':
      await subs.applyScheduledChangeIfDue(event.subId, event);          // applies a scheduled downgrade
      await revenue.emitOnce(event.subId, event.period, event.mrrDelta > 0 ? 'expansion' : 'contraction');
      break;
    case 'customer.subscription.deleted':
      await subs.applyTransition(event.subId, 'cancel_now');
      await revenue.emitOnce(event.subId, event.period, 'churn');
      break;
    default:
      logger.info({ type: event.type }, 'unsupported_billing_event');    // 200, persist, skip
  }
}
```

Side-effect endpoints (`applyTransition`, `revenue.emitOnce`) are idempotent — re-running the persisted row never double-transitions or double-counts revenue.

## Dunning + grace

```ts
// src/modules/subscriptions/core/dunning.service.ts

const RETRY_SCHEDULE_DAYS = [1, 3, 5, 7];   // smart retries with backoff; provider may also drive these

class DunningService {
  graceUntil(sub: Subscription): Date {
    // Grace spans the dunning window — entitlements retained until then.
    return addDays(new Date(), RETRY_SCHEDULE_DAYS[RETRY_SCHEDULE_DAYS.length - 1]);
  }

  async scheduleRetries(sub: Subscription, declineCode: string): Promise<void> {
    await this.notify(sub, 'payment_failed', { declineCode });
    // schedule the next retry; on each: re-attempt chargeRenewal (same period key → idempotent)
    // when schedule exhausted → applyTransition('dunning_exhausted') → unpaid → revoke after grace
  }
}
```

A failed renewal does NOT revoke access immediately. Entitlements are retained through `grace_until`; only `dunning_exhausted` (→ `unpaid`) past grace revokes.

## Invoices, tax, credit notes

```ts
// Invoice is IMMUTABLE once issued. Tax computed + frozen server-side at issue.
type Invoice = {
  id: string; subscriptionId: string; period: number;
  lines: InvoiceLine[];                 // plan, proration, overage
  subtotal: Money; taxAmount: Money; total: Money;   // all integer minor units, frozen at issue
  taxRateBasisPoints: number;           // the rate APPLIED at issue, stored — never recomputed at read
  issuedAt: Date;
};

// Refund / proration credit → CREDIT NOTE referencing the original invoice. The invoice is never edited.
type CreditNote = {
  id: string; invoiceId: string;        // references the immutable original
  amount: Money; reason: string; issuedAt: Date;
};
```

## Reconciliation (daily) + MRR integrity

```ts
@Cron('0 4 * * *')   // 4am daily — offset from payment reconciliation
async reconcileSubscriptions(): Promise<void> {
  const providerSubs = await this.gateway.listSubscriptions();
  const localSubs = await this.subs.listAll();

  const pMap = new Map(providerSubs.map(s => [s.subscriptionId, s]));
  const lMap = new Map(localSubs.map(s => [s.providerSubscriptionId, s]));

  const statusMismatch = [...pMap].filter(([id, p]) => lMap.get(id) && lMap.get(id)!.status !== p.status);
  const periodMismatch = [...pMap].filter(([id, p]) => lMap.get(id) && +lMap.get(id)!.currentPeriodEnd !== +p.currentPeriodEnd);
  const missingLocally  = [...pMap].filter(([id]) => !lMap.has(id));

  if (statusMismatch.length || periodMismatch.length || missingLocally.length) {
    await this.alerts.send('subscription-reconciliation-drift', { statusMismatch, periodMismatch, missingLocally });
  }
}
```

MRR/ARR is summed from the immutable `revenue_events` stream (new / expansion / contraction / churn / reactivation), each emitted once per transition. Reports NEVER re-derive revenue from mutable current state — that's how double-counts and phantom growth happen.

## Common mistakes

### Client-trusted entitlement
`if (req.user.plan === 'pro')` from a JWT claim. Stale after downgrade. Re-derive from current subscription state in the gate (`entitlementsFor`).

### Instant lockout on one decline
`invoice.payment_failed` → immediately `canceled`. A transient card hiccup locks out a paying customer mid-session. Dunning + grace first; revoke only after the schedule is exhausted past grace.

### Proration in floats
`credit = price * daysLeft / daysInPeriod` as a float. Fractional cents accrue on every plan change for every customer forever. Integer `Money.mulFraction` with a documented rounding side.

### Downgrade applied immediately
Customer downgrades mid-period and instantly loses features they paid for through period end. Schedule the change for period end; keep entitlements on the old plan until then.

### Non-idempotent renewal
Renewal retries with a fresh `uuid()` key → double charge for one period. Key = `sub:<id>:period:<n>`.

### Local state drift
Operator sets `status='active'` directly in the DB; provider still says `canceled`; the next webhook overwrites it; reconciliation flaps. Drive the change through the provider.

### Trial abuse by email
Abuse limit keyed on email → `a+1@`, `a+2@` … unlimited trials. Bound by payment-method fingerprint / device.

### Edited invoice
Refund applied by editing the original invoice total. The immutable financial record now lies; tax filings drift. Issue a credit note referencing the original.

### Revenue double-count
`customer.subscription.updated` retried by the provider → expansion MRR counted twice → board deck shows phantom growth. Dedupe revenue events by `(subscriptionId, period, type)`.

### Usage double-report
Metered usage reported again on job retry without an idempotency key → over-billed overage. Idempotent usage records per `(item, key)`.

### Tax recomputed at read time
Invoice shows a different VAT than at issue because the rate changed. Compute + freeze tax on the invoice at issue.

### Orphaned scheduled change
A scheduled downgrade is stored but no period-boundary handler applies it. The customer stays on the old plan forever. Apply scheduled changes on the period-end transition.

## Cross-references

- `<rules-path>/subscription-billing-discipline.md` — the hard-rule list (state machine, derived entitlements, idempotent renewals, proration, dunning, invoice immutability, MRR integrity).
- `<rules-path>/payment-idempotency.md` — Money, idempotency keys, server-computed amounts, dispute-window retention this pattern builds on.
- `<patterns-path>/payment-integration.md` — `PaymentGateway`, `Money`, charge/refund/webhook shapes the renewal charge reuses (§ Money, § Charge, § Webhook handler, § Reconciliation).
- `<patterns-path>/webhook-flow.md` — the verify → dedupe → process inbound shape every transition handler follows.
- `<rules-path>/webhook-signature-verification.md` — universal webhook signature rule.
- `<commands-path>/simulate-renewal.md` — local renewal + dunning fixture-replay tool.
- `<agents-path>/subscription-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-subscription-provider-choice.md` — ADR pinning the chosen billing provider + proration/dunning policy.
