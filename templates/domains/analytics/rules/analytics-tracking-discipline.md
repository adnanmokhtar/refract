---
name: analytics-tracking-discipline
description: Product analytics & event-tracking discipline
kind: rule
---

# Product analytics & event-tracking discipline

## Hard rule

Every product-analytics event MUST be a TYPED event drawn from a declared tracking plan — `track(anyString, anyObject)` with an ad-hoc name and an open property bag is FORBIDDEN. Tracking MUST be CONSENT-GATED: no analytics event fires to a third party (Segment/Amplitude/Mixpanel/GA/PostHog) before the user's consent is established, and Do-Not-Track / opt-out is honored — events are dropped or queued until consent, never sent-then-regretted. Event properties MUST pass a PII-minimization ALLOWLIST — emails, tokens, full addresses, raw form inputs, and secrets NEVER leave the platform. Identity (`user_id`, `role`, `plan`, account traits) MUST be sourced from the verified SERVER session, never a client-settable field. Conversion / revenue / funnel events MUST carry an idempotency key so client retries + at-least-once delivery do NOT double-count. Dispatch MUST be NON-BLOCKING — an analytics call is fire-and-forget into a buffered sink, never `await`-ed on the request critical path.

Analytics is product instrumentation, NOT the audit log. Security-relevant events (logins, permission changes, money movement, admin actions) go to the tamper-evident audit trail — never to Mixpanel as the system of record. An analytics bug is silently double-counted revenue, a privacy/compliance breach, or an un-analyzable funnel — all of which corrupt the decisions made on top of the numbers.

## Must

- **Typed events from a tracking plan**: every event is a named, versioned entry in a central tracking plan (`OrderPlaced`, `CheckoutStarted`) with a typed property schema. The emit API is `analytics.track('OrderPlaced', { orderId, valueMinor, currency })` validated against the plan — never `track(arbitraryString, arbitraryObject)`.
- **Consent gate on every dispatch**: a consent gate sits in front of the sink. Before consent is resolved, events are dropped or buffered per policy; analytics/marketing categories fire only on opt-in (GDPR/ePrivacy). Do-Not-Track and explicit opt-out are honored as a hard drop. See `<rules-path>/compliance.md`.
- **PII-minimization allowlist on properties**: each event's properties pass through an allowlist derived from its plan schema. Unknown keys are dropped; declared sensitive keys are hashed/omitted. Emails, phone numbers, full addresses, tokens, passwords, raw request bodies, and free-text inputs NEVER reach a third party.
- **Server-sourced identity + traits**: `user_id`, `role`, `plan`, `tenant_id`, and sensitive traits come from the verified auth/session context. A client-supplied `userId` or `role` in the event payload is IGNORED. Sensitive `identify()` traits are set server-side only.
- **Idempotency / dedup on trust-critical events**: conversion, revenue, signup, and funnel-step events carry a stable `messageId` / dedup key (derived from the domain entity, e.g. `order:<id>:placed`) so a client retry or at-least-once redelivery is de-duplicated downstream — not counted twice.
- **Non-blocking, buffered dispatch**: `track()` enqueues into an in-process buffer / outbox and returns immediately; a background flusher batches to the vendor with retry + backpressure. The request thread NEVER waits on the analytics vendor, and a vendor outage NEVER fails the user's action.
- **Server-side for sensitive flows**: high-value (conversion, revenue) and sensitive-category contexts are tracked server-side (or via an outbox), not from an ad-blockable, spoofable client SDK. Client-side is for UI interactions that don't carry trust or special-category data.
- **Special-category data stays off-platform**: events that would reveal health, finance detail, sexual orientation, religion, or other special-category data are NOT sent to a general analytics vendor — server-side, minimized, or forbidden entirely. See `<rules-path>/compliance.md`.
- **Stable, non-enumerable ids**: identifiers sent to the vendor are opaque/stable (a hashed or surrogate id), not raw internal sequential ids or other enumerable identifiers that let the vendor — or a breach of it — cross-link or enumerate users.
- **Sampling + rate strategy on high-volume events**: high-cardinality / high-frequency events (scroll, mousemove, poll ticks) carry an explicit sampling rate and a per-source rate cap so the vendor doesn't silently drop at its own rate limit and bias the data. See `<rules-path>/rate-limit.md`.
- **One emit surface**: all tracking goes through a project-internal `<Analytics>` facade (plan validation + consent + allowlist + identity + idempotency + buffering in one place). Feature code calls the facade, never the vendor SDK directly.

## Must not

- Call `track(name, props)` with an undeclared/ad-hoc event name or an open property bag not validated against the tracking plan.
- Fire any analytics event before consent is resolved, or ignore Do-Not-Track / a recorded opt-out.
- Put an email, phone, full address, token, password, raw form input, or secret into an event property sent to a third party.
- Take `user_id` / `role` / `plan` / `tenant_id` from the client-supplied event payload instead of the server session.
- Emit a conversion/revenue event with no idempotency key — a retry then double-counts it.
- `await analytics.track(...)` on the request critical path, or let a vendor timeout/outage fail or slow the user's request.
- Send special-category data (health/finance/sexual/religion) to a general analytics vendor.
- Use the analytics pipeline as the audit log for security events (it's lossy, sampled, mutable, off-platform, and consent-gated).
- Send raw internal sequential ids or other enumerable identifiers as the analytics distinct id.
- Fire-hose a high-frequency event with no sampling — cost blowup + silent vendor-side rate-limit drops that bias the data.

## Should

- Express the tracking plan as a single source of truth (typed schema / codegen) so event names + property types are checked at compile time and renames are caught, not discovered when a funnel silently goes flat.
- Route trust-critical (revenue/conversion) events through the same outbox/idempotency machinery as domain events (see `<patterns-path>/queue-producer-consumer.md`) so they're delivered exactly-once-effectively and resumable.
- Version events (`OrderPlaced@2`) and migrate consumers, rather than mutating a live event's shape and breaking historical analysis.
- Label each event's destination + category (`analytics` / `marketing` / `functional`) so the consent gate can apply the right policy per category.
- Reconcile revenue/conversion numbers against the system of record (the ledger / reporting store) periodically — analytics numbers feed decisions and must tie out. See `<rules-path>/reporting.md`.
- Log structured `{ event, category, consent, sampled, dedupKey, queuedAt, flushedAt }` for the pipeline itself; alert on consent-gate bypass, allowlist drops spiking, and vendor flush failures.

## Review checklist (PRs touching tracking / instrumentation / event emits / identify calls)

- [ ] Every `track()`/`capture()` uses a declared, typed event from the tracking plan — no ad-hoc name, no open property bag. Cite `<path:line>`.
- [ ] Dispatch is consent-gated; events before consent are dropped/queued; DNT + opt-out honored. Cite the gate at `<path:line>`.
- [ ] Properties pass a PII-minimization allowlist; no email/token/address/secret/raw-input in any event sent off-platform.
- [ ] Identity (`user_id`/`role`/`plan`/`tenant_id`) + sensitive traits come from the server session, not the client payload. Cite `<path:line>`.
- [ ] Conversion/revenue/funnel events carry an idempotency/dedup key; retries don't double-count. Cite the key at `<path:line>`.
- [ ] Dispatch is non-blocking (buffered sink / outbox); no `await` on the critical path; vendor outage can't fail the request.
- [ ] Sensitive flows tracked server-side; no special-category data to a general vendor.
- [ ] No security event is routed to analytics as the audit trail (it belongs in `<rules-path>/audit-log.md`).
- [ ] Distinct id is opaque/stable, not a raw enumerable internal id.
- [ ] High-volume events carry an explicit sampling rate + per-source cap.

## Anti-patterns

- **Ad-hoc stringly event** — `track('clicked', { ...everything })` scattered across the UI -> every dev names it differently, a property gets renamed, the funnel silently goes flat, and no one can analyze it. Type the event from the plan.
- **Track-before-consent** — the analytics SDK loads and fires `page` + `identify` on first paint, before the cookie banner is answered -> ePrivacy violation on every first visit. Gate the sink on resolved consent.
- **PII in properties** — `track('SignupCompleted', { email, fullName, ip })` -> the email + name + IP are now in a third-party vendor, forever, off-platform. Allowlist; minimize; hash if an id is truly needed.
- **Client-trusted identity** — `track('Upgraded', { userId: req.body.userId, plan: req.body.plan })` -> anyone can attribute a conversion to anyone, or poison the `plan` trait. Identity from the verified session only.
- **Double-counted revenue** — a flaky network retries the checkout request; both attempts emit `OrderPlaced` with no dedup key -> revenue is reported 2x -> the team "celebrates" inflated numbers and mis-forecasts. Idempotency key per order.
- **Awaited tracking on the hot path** — `await analytics.track('OrderPlaced', ...)` inside the checkout transaction -> when Amplitude is slow, checkout is slow; when Amplitude is down, checkout 500s. Fire-and-forget into a buffer.
- **Analytics as the audit log** — "we'll just look in Mixpanel for who deleted the record" -> the event was sampled away, the user opted out, the property was renamed, and the vendor mutated retention. Security events go to the tamper-evident audit trail.
- **Special-category leak** — a health app sends `track('ConditionViewed', { condition: 'HIV' })` to a marketing analytics tool -> special-category data off-platform, a serious breach. Don't send it; minimize or keep it server-side.
- **Enumerable distinct id** — `identify(user.id)` where `user.id` is `12345` sequential -> the vendor (or a breach of it) can enumerate and cross-link users. Use an opaque surrogate id.
- **Unsampled firehose** — `track('Scrolled', ...)` on every scroll frame -> millions of events, vendor rate-limits and drops them unpredictably -> the data is biased AND the bill explodes. Sample + cap.

## Enforcement

- `<commands-path>/audit-tracking-plan.md` (slash: `/audit-tracking-plan`) — inventories every `track()`/`capture()` call-site at `<path:line>`, matches each against the declared tracking plan (untyped/ad-hoc/undeclared = drift), and flags PII in properties, missing consent-gating, client-sourced identity, missing idempotency, and blocking calls — cite-or-halt, never an assumed event set.
- `<agents-path>/analytics-reviewer.md` — review gate hard-failing on ad-hoc untyped events, track-before-consent, PII in properties, client-trusted identity, missing dedup on revenue events, blocking dispatch, special-category leaks, and analytics-as-audit-log.
- CI lint MUST reject a raw vendor-SDK import (`@segment/*`, `amplitude-js`, `mixpanel-browser`, `posthog-js`) outside the `<Analytics>` facade module — feature code calls the facade only.
- CI lint MUST reject a `track()` call whose event name is a non-literal or not present in the tracking-plan registry (AST heuristic; flag for review).
- CI lint MUST flag `await` directly on an `analytics.track(...)` / `.capture(...)` call (blocking dispatch on the critical path).
- CI lint MUST flag event property keys matching a PII denylist (`email`, `phone`, `ssn`, `password`, `token`, `address`, `ip`) on any tracked event.
- TODO: `scripts/validate-tracking-plan.sh` to AST-walk emit call-sites and assert every event is declared+typed, consent-gated, allowlisted, server-identified, and dispatched non-blocking.

## Cross-references

- `<patterns-path>/event-tracking.md` — typed tracking plan + consent gate + PII allowlist + server identity + idempotency + buffered non-blocking sink code shapes.
- `<rules-path>/compliance.md` — consent regime (GDPR/ePrivacy), Do-Not-Track, special-category data classification that gates what may be tracked.
- `<rules-path>/audit-log.md` — analytics is NOT the audit log; security/compliance events go to the tamper-evident audit trail, not the analytics vendor. Keep the two pipelines separate.
- `<rules-path>/reporting.md` — analytics numbers are trust-critical and often feed reports; share the idempotency/dedup discipline so revenue/conversion numbers tie out to the system of record.
- `<rules-path>/rate-limit.md` — per-source sampling + rate caps on high-volume events so the vendor doesn't silently drop and bias the data.
- `<patterns-path>/queue-producer-consumer.md` — outbox + at-least-once + dedup semantics for delivering trust-critical events server-side.
- `<adr-path>/<NNN>-analytics-pipeline.md` — ADR pinning the vendor(s), client-vs-server split, consent model, and the tracking-plan source of truth.
