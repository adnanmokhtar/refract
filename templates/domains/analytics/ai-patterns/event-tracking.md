---
name: event-tracking
description: "Pattern: Event tracking (typed tracking plan, consent-gated, idempotent, PII-minimized)"
kind: ai-pattern
---

# Pattern: Event tracking (typed tracking plan, consent-gated, idempotent, PII-minimized)

> **Hard rule** — Every product-analytics event is a TYPED event from a declared tracking plan, never `track(anyString, anyObject)`; dispatch is CONSENT-GATED (dropped or queued until consent, DNT/opt-out honored); properties pass a PII-minimization ALLOWLIST so no email/token/address/secret leaves the platform; identity + sensitive traits come from the verified SERVER session, never the client payload; trust-critical (revenue/conversion) events carry an IDEMPOTENCY key so retries don't double-count; and dispatch is NON-BLOCKING — fire-and-forget into a buffered async sink, never `await`-ed on the request critical path. Analytics is product instrumentation, NOT the audit log.

**When to apply**
- Any product-analytics / telemetry / behavioral instrumentation: funnels, conversion, feature adoption, retention, revenue events feeding dashboards or experiments.
- Multi-tenant or consumer products under GDPR/ePrivacy/CCPA where consent and PII-minimization are legal requirements, not nice-to-haves.
- Any event whose count drives a decision (revenue, signups, activation) — where double-counting or silent drops corrupt the numbers people act on.

**When NOT to apply**
- Security / compliance events (logins, permission changes, money movement, admin actions) — those go to the tamper-evident AUDIT LOG (`<rules-path>/audit-log.md`), not the analytics vendor. The audit trail must be lossless, immutable, and consent-independent; analytics is none of those.
- Ops observability — request rate, latency, error rate, saturation. That's metrics/tracing (Prometheus/OTel), a different concern from product instrumentation.
- A pure server-to-server data export into your own warehouse with no third-party vendor and no end-user identity — that's an ETL/reporting concern.

**Halt conditions / mandatory cites**
- Cite the typed tracking-plan definition + the emit facade at `<path:line>`. A `track()` with a non-literal/ad-hoc name or an open property bag = halt.
- Cite the consent gate in front of the sink at `<path:line>`. Any emit path that reaches the vendor without passing the gate = halt (privacy breach).
- Cite the PII-minimization allowlist applied to properties at `<path:line>`. Properties forwarded without allowlisting = halt.
- Cite where identity (`user_id`/`role`/`plan`) is sourced from the server session at `<path:line>`. Identity read from the client payload = halt (spoofable).
- Cite the idempotency/dedup key on revenue/conversion events at `<path:line>`. A trust-critical event with no dedup key = halt (double-count).
- Cite the buffered, non-blocking dispatch at `<path:line>`. An `await analytics.track(...)` on the critical path = halt.
- Grep ban: "tracking is consent-gated / PII-safe / idempotent / non-blocking" without file:line for the gate, the allowlist, the dedup key, and the buffer.

## Why

Product analytics is simultaneously a privacy surface (it ships user data off-platform to a third party), a trust surface (the counts become "truth" in a dashboard and drive decisions), and a reliability surface (it sits in the middle of hot paths like checkout). The recurring failures:

1. **It leaks** — an email or token in an event property is now in a third-party vendor, off-platform, forever; or it fired before consent. Allowlist + consent gate.
2. **It double-counts** — at-least-once delivery + client retries emit the same conversion twice; revenue is reported inflated; the team mis-forecasts. Idempotency key per domain entity.
3. **It can't be analyzed** — ad-hoc stringly events drift; a property gets renamed; the funnel silently goes flat and no one notices. Typed events from a plan.
4. **It breaks the request** — `await track()` on the hot path means a slow/down vendor slows or fails checkout. Fire-and-forget into a buffer.

The pattern: declare a typed plan, emit through a facade that gates on consent, minimizes properties, stamps server identity + an idempotency key, and hands the event to a buffered async sink that never touches the request thread.

## Typed tracking plan (the contract)

```ts
// src/analytics/tracking-plan.ts

/** Category drives the consent policy applied to each event. */
export type EventCategory = 'functional' | 'analytics' | 'marketing';

/** The ONLY events that may be emitted. Adding a property = editing this file. */
export interface TrackingPlan {
  CheckoutStarted: { cartId: string; itemCount: number; valueMinor: number; currency: string };
  OrderPlaced:     { orderId: string; valueMinor: number; currency: string; itemCount: number };
  TrialStarted:    { plan: string };
  PlanUpgraded:    { fromPlan: string; toPlan: string; valueMinor: number; currency: string };
  FeatureUsed:     { feature: string };
}

export type EventName = keyof TrackingPlan;

/** Per-event metadata: consent category, whether it must be deduped, and the dedup-key builder. */
export const EVENT_META: {
  [K in EventName]: {
    category: EventCategory;
    /** Trust-critical events MUST declare a dedup key so retries can't double-count. */
    dedupKey?: (p: TrackingPlan[K]) => string;
    /** Allowlisted property keys forwarded to the vendor. Anything else is dropped. */
    allow: ReadonlyArray<keyof TrackingPlan[K]>;
  };
} = {
  CheckoutStarted: { category: 'analytics', allow: ['cartId', 'itemCount', 'valueMinor', 'currency'] },
  OrderPlaced:     { category: 'analytics', allow: ['orderId', 'valueMinor', 'currency', 'itemCount'],
                     dedupKey: p => `order:${p.orderId}:placed` },
  TrialStarted:    { category: 'analytics', allow: ['plan'] },
  PlanUpgraded:    { category: 'analytics', allow: ['fromPlan', 'toPlan', 'valueMinor', 'currency'],
                     dedupKey: p => `upgrade:${p.fromPlan}->${p.toPlan}` },
  FeatureUsed:     { category: 'analytics', allow: ['feature'] },
};
```

`track<'OrderPlaced'>(...)` is checked at compile time: a wrong property type, a renamed key, or an undeclared event name fails the build. There is no path to `track(arbitraryString, arbitraryObject)`.

## Emit facade: the single, typed, gated surface

> The example uses a plain TypeScript class; substitute your project's DI / framework idiom from `.claude/_extracted-codebase.md`. The SHAPE — typed name -> validate against plan -> consent gate -> allowlist -> server identity + dedup key -> enqueue into a buffer (no await of the vendor) — is what's universal, not the helper names.

```ts
// src/analytics/analytics.ts

export class Analytics {
  constructor(
    private sink: BufferedSink,            // non-blocking, batched flusher (below)
    private consent: ConsentResolver,      // resolves the actor's consent state (below)
  ) {}

  /** The ONLY emit API. Generic K constrains props to the plan's schema for that event. */
  track<K extends EventName>(
    name: K,
    props: TrackingPlan[K],
    ctx: ServerContext,                    // identity comes from HERE, never from props
  ): void {                                // returns void — fire-and-forget, never a Promise to await
    const meta = EVENT_META[name];

    // 1. Consent gate — drop or queue per category; honor DNT / opt-out.
    const decision = this.consent.decide(ctx, meta.category);
    if (decision === 'drop') return;                       // e.g. DNT, or marketing without opt-in

    // 2. PII-minimization allowlist — only declared keys survive; unknown/sensitive keys dropped.
    const safeProps = pickAllowed(props, meta.allow);      // <path:line> — see allowlist below

    // 3. Server-sourced identity — distinct id is an OPAQUE surrogate, not a raw internal id.
    const identity = {
      distinctId: ctx.session.analyticsId,                 // opaque, stable, non-enumerable surrogate
      traits: { plan: ctx.session.plan, role: ctx.session.role },   // from the verified session
    };

    // 4. Idempotency — trust-critical events carry a stable messageId so retries dedup downstream.
    const messageId = meta.dedupKey
      ? `${name}:${meta.dedupKey(props)}`                  // e.g. OrderPlaced:order:42:placed
      : crypto.randomUUID();

    const event: QueuedEvent = {
      name, props: safeProps, identity, messageId,
      tenantId: ctx.session.tenantId, occurredAt: new Date().toISOString(),
      buffer: decision === 'queue',                        // queued events flush after consent flips
    };

    // 5. Non-blocking dispatch — enqueue and return. The vendor is NEVER on the request thread.
    this.sink.enqueue(event);                              // <path:line> — see BufferedSink below
  }
}
```

`track` returns `void`, so there is nothing to `await`. Identity is read from `ctx.session`; `props.userId` (if a careless caller passes one) is never trusted. The dedup key is derived from the domain entity, not the request.

## Consent gate (drop / queue / send)

```ts
// src/analytics/consent.ts

export type ConsentDecision = 'send' | 'queue' | 'drop';

export class ConsentResolver {
  decide(ctx: ServerContext, category: EventCategory): ConsentDecision {
    if (ctx.signals.doNotTrack) return 'drop';             // DNT is a hard drop, always
    if (category === 'functional') return 'send';          // strictly-necessary: allowed pre-consent

    const state = ctx.session.consent;                     // 'unknown' | 'granted' | 'denied'
    if (state === 'denied') return 'drop';                 // explicit opt-out — hard drop
    if (state === 'granted') return 'send';

    // Consent not yet resolved: BUFFER non-functional events; flush only if it later flips to granted,
    // discard if it flips to denied. NEVER send-then-regret.
    return 'queue';
  }
}
```

No analytics/marketing event reaches the vendor before consent resolves. Special-category contexts (health/finance/sexual/religion) are not modeled as a `category` here at all — they are not sent to a general vendor; keep them server-side or omit them (see `<rules-path>/compliance.md`).

## PII-minimization allowlist

```ts
// src/analytics/allowlist.ts

const PII_DENY = /(email|phone|ssn|password|secret|token|address|ip|dob|name)/i;

/** Only the event's declared allowlist keys survive; sensitive keys never forward. */
export function pickAllowed<P extends object>(
  props: P,
  allow: ReadonlyArray<keyof P>,
): Partial<P> {
  const out: Partial<P> = {};
  for (const key of allow) {
    if (PII_DENY.test(String(key))) continue;              // belt-and-braces: never forward a PII key
    if (props[key] !== undefined) out[key] = props[key];
  }
  return out;                                              // unknown keys are dropped, not passed through
}
```

The output carries exactly the declared, non-PII keys. A property the plan didn't allowlist cannot leak even if a caller stuffs it into the call.

## Server-side vs client-side: where to emit

```ts
// Decision: emit server-side when the event is trust-critical OR sensitive; client-side only for
// pure UI interactions that carry neither trust nor special-category data.

// SERVER-SIDE (authoritative): revenue, conversion, lifecycle — fired from the domain transaction's
// outbox so identity is verified, the count is idempotent, and an ad-blocker can't drop it.
async function onOrderPlaced(order: Order, ctx: ServerContext) {
  // ... persist order in the same transaction as the outbox row (see queue-producer-consumer) ...
  analytics.track('OrderPlaced',
    { orderId: order.id, valueMinor: order.totalMinor, currency: order.currency, itemCount: order.items.length },
    ctx);                                                  // dedupKey => order:<id>:placed
}

// CLIENT-SIDE (best-effort UI signal): a feature-adoption click. No money, no PII, no trust weight.
// Still goes through the SAME facade so consent + allowlist + plan typing apply.
function onExportClicked(ctx: ServerContext) {
  analytics.track('FeatureUsed', { feature: 'export' }, ctx);
}
```

Rule of thumb: if double-counting it or an ad-blocker dropping it would distort a decision, emit it server-side from the outbox. Client-side is for low-stakes interaction signals only.

## Idempotency: dedup-or-double-count

```ts
// The dedup key travels with the event as the vendor's messageId. Vendors (Segment/Amplitude)
// dedup on a stable messageId; your warehouse dedups on it too.
//
//   messageId = "OrderPlaced:order:42:placed"
//
// Two delivery attempts (client retry + at-least-once redelivery) of the SAME OrderPlaced carry the
// SAME messageId -> counted once. A random uuid per attempt would count it twice and inflate revenue.
//
// For events with no natural entity key (a generic page view), a random uuid is correct — they are
// not trust-critical and an occasional duplicate doesn't distort a decision. Only trust-critical
// events declare a dedupKey in EVENT_META.
```

This is the same wrong-numbers failure mode as reporting (`<rules-path>/reporting.md`): a number people trust, silently inflated. The fix is the same — a stable idempotency key derived from the domain entity.

## Non-blocking buffered sink

```ts
// src/analytics/buffered-sink.ts

export class BufferedSink {
  private buffer: QueuedEvent[] = [];
  private flushing = false;

  constructor(
    private vendor: VendorClient,
    private opts = { maxBuffer: 10_000, batchSize: 200, flushMs: 2_000 },
  ) {
    setInterval(() => void this.flush(), this.opts.flushMs).unref();   // background flusher
  }

  /** Synchronous, returns immediately. The request thread does no network I/O here. */
  enqueue(event: QueuedEvent): void {
    if (this.buffer.length >= this.opts.maxBuffer) {       // backpressure: drop newest, never block
      metrics.increment('analytics.buffer.dropped');       // observable, not silent
      return;
    }
    this.buffer.push(event);
  }

  /** Background-only. Batches to the vendor with retry; a vendor outage never reaches the caller. */
  private async flush(): Promise<void> {
    if (this.flushing || this.buffer.length === 0) return;
    this.flushing = true;
    const batch = this.buffer.splice(0, this.opts.batchSize);
    try {
      await this.vendor.sendBatch(batch);                  // the ONLY await — off the request path
    } catch (err) {
      this.buffer.unshift(...batch);                       // requeue for the next tick (bounded retry)
      metrics.increment('analytics.flush.failed');
    } finally {
      this.flushing = false;
    }
  }
}
```

`enqueue` never touches the network. The only `await` on the vendor lives in the background `flush`, so a slow or down vendor adds zero latency to — and can never fail — the user's request. The buffer is bounded; overflow is dropped and counted, not allowed to grow unbounded.

## Sampling on high-volume events

```ts
// High-frequency events get an explicit sample rate + per-source cap so the vendor doesn't silently
// rate-limit-drop and bias the data (and so the bill stays sane). See <rules-path>/rate-limit.md.
const SAMPLE: Partial<Record<EventName, number>> = { /* e.g. */ FeatureUsed: 1.0 /* keep all */ };
// A hypothetical 'Scrolled' would be { Scrolled: 0.01 } — keep 1%, and label the sample rate on the
// event so downstream can weight it. NEVER firehose an unsampled high-cardinality event.
```

## Common mistakes

### Ad-hoc stringly event
`track('clicked', { ...whatever })` -> names drift, a property rename silently flatlines the funnel, nothing is analyzable. Type the event from the plan; the build fails on drift.

### Track-before-consent
The SDK fires `page`/`identify` on first paint before the banner is answered -> ePrivacy violation every first visit. Gate the sink: drop or queue until consent resolves; honor DNT.

### PII in properties
`track('SignupCompleted', { email, fullName, ip })` -> email + name + IP now live in a third-party vendor off-platform. Allowlist; minimize; never forward a PII key.

### Client-trusted identity
`track('Upgraded', { userId: req.body.userId, plan: req.body.plan })` -> anyone attributes a conversion to anyone and poisons the `plan` trait. Identity from `ctx.session` only.

### Double-counted revenue
A retried checkout emits `OrderPlaced` twice with a random messageId each -> revenue reported 2x -> mis-forecast. Derive a stable dedup key from the order id.

### Awaited tracking on the hot path
`await analytics.track('OrderPlaced', ...)` inside the checkout transaction -> a slow vendor slows checkout, a down vendor 500s it. `track` returns void into a buffer; the vendor is background-only.

### Analytics as the audit log
"We'll check Mixpanel for who deleted the record" -> it was sampled away, the user opted out, the property was renamed, the vendor mutated retention. Security events go to the tamper-evident audit trail, never analytics.

### Special-category leak
Sending `{ condition: 'HIV' }` / financial detail / religion to a general analytics vendor -> special-category data off-platform, a serious breach. Don't send it; keep it server-side or omit it.

### Enumerable distinct id
`identify(user.id)` with a sequential `12345` -> the vendor (or a breach of it) can enumerate + cross-link users. Use an opaque surrogate analytics id.

### Unsampled firehose
`track('Scrolled', ...)` every frame -> the vendor rate-limit-drops unpredictably (biasing the data) and the bill explodes. Sample + cap; label the sample rate.

## Cross-references

- `<rules-path>/analytics-tracking-discipline.md` — the hard-rule list (typed plan, consent gate, PII allowlist, server identity, idempotency, non-blocking dispatch, analytics≠audit-log).
- `<rules-path>/compliance.md` — consent regime (GDPR/ePrivacy), Do-Not-Track, and special-category-data classification that gates what may be tracked at all.
- `<rules-path>/audit-log.md` — analytics is NOT the audit log; security/compliance events go to the tamper-evident trail, not the analytics vendor.
- `<rules-path>/reporting.md` — analytics numbers feed reports and are trust-critical; share the dedup/idempotency discipline so revenue/conversion ties out to the system of record.
- `<rules-path>/rate-limit.md` — per-source sampling + rate caps on high-volume events.
- `<patterns-path>/queue-producer-consumer.md` — outbox + at-least-once + dedup for delivering trust-critical events server-side.
- `<commands-path>/audit-tracking-plan.md` — inventory emit call-sites vs. the declared plan.
- `<agents-path>/analytics-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-analytics-pipeline.md` — ADR pinning the vendor(s), client-vs-server split, consent model, and tracking-plan source of truth.
