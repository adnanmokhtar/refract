# On-demand — core flows

The flows every on-demand marketplace must support. P1 is "without these you have no marketplace." P2 is "without these unit economics break." P3 is "competitive + scale + trust at scale."

## P1 — must-have for v1

### 1. Request → quote → match → trip → completion → rating

The end-to-end loop. Every part must work or the marketplace dies.

```
Customer opens app → location detected (GPS + permission)
  → enters destination (or selects "delivery to me / from X to Y / job at Y")
  → app requests Quote: POST /quotes { pickup, dropoff, type, scheduled? }
  → backend computes: distance + ETA + base + surge + service fee + tax → returns Quote
  → app displays quote with surge disclosure
  → customer taps "Confirm" → POST /requests with quote_id
  → matcher selects worker(s) by proximity + acceptance rate + service type compatibility
  → offer sent to chosen worker (push + in-app)
  → worker has N seconds to accept (typically 8-15s)
  → worker accepts → Match.accepted; worker.status = on_request
  → Trip created in en_route_pickup; ETA streamed to customer
  → worker arrives → arrived_pickup; customer notified
  → customer enters / hands off package → in_progress
  → trip executes; live location streamed to customer
  → arrived_dropoff (or delivery dropped at door)
  → worker taps "complete" → status=completed
  → fare captured (or already auth'd)
  → both rate each other
  → tip prompt shown to customer (post-trip OR during cooldown)
  → earnings credited to worker
```

Key invariants:
- Quote is BINDING for the duration of its TTL (typically 60-90 sec). After expiry, recompute (price may shift due to surge).
- Match offer is FAIR between workers — algorithm must not unfairly disadvantage protected classes (race / gender / neighborhood). Audit periodically.
- Worker accept timeout default-rejects, no penalty (unless acceptance-rate gaming detected).
- Customer cancellation BEFORE worker_arrives = free (within window); AFTER = fee (with policy disclosure).
- Trip live location is REAL-TIME (websocket or push, ≤2-5 sec freshness); polling is unacceptable user experience.
- Rating is two-way + mandatory (can be 1-tap stars + skip-comment); below threshold triggers review.

### 2. Worker onboarding + verification

Critical for trust. Failure here = liability + safety incident.

```
Applicant downloads worker app → enters basic info (email, phone, name)
  → identity verification: gov ID upload + selfie (provider: Onfido/Persona/Veriff) → liveness check + ID match
  → if vehicle: license + registration + insurance upload + vehicle photo + inspection (in-person or photo-based)
  → background check: criminal + driving record (provider: Checkr/Sterling) → multi-day async
  → bank / payout method linked (provider: Stripe Connect / Branch / Tipalti)
  → tax form (W-9 in US, equivalent local) → 1099 / IR35 / equivalent classification
  → terms + classification disclosure accepted (independent contractor agreement OR employee onboarding per jurisdiction)
  → training module (optional / mandatory varies by jurisdiction)
  → first activation; worker is online and matchable
```

Key invariants:
- Background check MUST complete before first matched trip — partial-onboarded workers cannot be dispatched.
- Re-verification on schedule: license expiry, insurance expiry, periodic background check (annual in many jurisdictions).
- Insurance lapse = automatic offline + re-verification required to resume.
- Identity document retention follows local privacy law (delete after verification per GDPR data minimization).
- Worker classification disclosed in writing + signed (employee vs contractor); misclassification = lawsuit.

### 3. Live location + ETA

The ongoing "where are they" experience.

```
Worker app: every 3-5 sec → POST /location { lat, lng, heading, speed, accuracy, trip_id }
  → backend stores latest in Redis + bulk-writes to durable store every N seconds
  → fanout to subscribed customers (during matched trip) + dispatch system + ops console
  → customer app subscribes via websocket / pub-sub
  → ETA recomputed every 10-30 sec: distance-along-route / current-speed-segments + live traffic
  → display on map with smoothing (don't jump pin every update; interpolate)
  → on arrival within 50m radius → trigger "Arriving now" notification
```

Key invariants:
- Location updates ONLY during active trip (Period 2 + 3 in US insurance terms). Period-1 location (worker idle, app open) used for dispatch only, not customer-visible.
- After trip completes: worker location data MUST be deleted or anonymized within retention window (privacy law: typically days-to-weeks max).
- ETA must include realistic buffer (traffic + pickup wait + handoff time); over-promising drives complaints.
- Location updates protected — leaking real-time worker location to customer outside trip = stalking risk.

### 4. Cancellation flow

```
Customer cancels:
  before worker accepts → free, no fee, request closed
  after worker accepts but worker not arrived → fee may apply per policy + window (typically 2-min grace)
  after worker arrived → cancellation fee (covers worker time)
  during trip → trip ended at current location, partial fare + cancellation fee

Worker cancels:
  before arrived → counts against acceptance/completion rate; customer rematched
  after arrived → counts harder; possible no-show (with evidence) vs cancellation
  emergency / safety → not counted

System cancels:
  no driver matched in N minutes → cancellation; refund any pre-auth
  worker non-responsive → re-match
```

Invariants:
- Fee disclosure BEFORE customer confirms request.
- Fee deducted from customer's payment method automatically.
- Worker compensated for cancellation when worker is not at fault (showed up + customer no-show).
- Excessive cancellation tracked (customer + worker) with rate-based interventions.

### 5. Payment + payout

```
Customer payment:
  At request: validate payment method (auth a small amount or store token validation)
  At trip completion: capture fare (or pre-auth at acceptance, capture at end with adjustments)
  Tip captured separately or included in final capture (depends on flow)
  Receipt emailed + visible in app history

Worker payout:
  Each completed trip: Earnings record created (gross fare + tip - platform fee - deductions)
  Per cycle (instant / weekly / on-demand): batch into Payout
  Initiate transfer via Stripe Connect / Wise / local bank rails
  Worker app shows pending earnings → ready → in-transit → completed
  Failed payout (closed bank account): retry + manual contact
```

Invariants:
- Customer charged exactly the fare displayed at trip end (no surprise add-ons; disputes spike when this drifts).
- Platform fee ALWAYS calculated transparently — worker can see breakdown.
- Tip flows 100% to worker (most platforms; legal in many jurisdictions).
- Payout cycle disclosed to worker; instant payout has fee disclosed up front.
- Tax withholding + reporting per classification (1099-NEC for US contractors > $600/yr).

### 6. Two-way rating

```
Trip ends → app prompts both:
  Customer: "Rate your driver" 1-5 stars + optional tags (clean car / friendly / late / etc.) + optional comment
  Worker: "Rate your rider" 1-5 stars + optional tags (rude / no-show / late / etc.) + optional comment

Aggregated: rolling average (typically last 100-500 trips)
Below threshold (e.g. < 4.6 driver) → coaching, then deactivation review
```

Invariants:
- Ratings are anonymous to the rated party (worker doesn't see who gave 1 star, prevents retaliation).
- Time delay before rated party can see new average (smooths individual scores).
- Customer may not retaliate-rate after worker reports them — moderation flag.
- Ratings collected even if trip went poorly (incentive to skip is high; default to optional skip with nudge).

## P2 — keep the marketplace healthy

### 7. Surge / dynamic pricing + disclosure

```
Demand-supply imbalance detected per zone (H3 cells aggregated)
  → surge multiplier applied (1.2x → 3x typical range; cap at 5x most platforms)
  → quote shows "Prices are higher than usual" with multiplier or final amount
  → customer accepts or waits
  → worker app shows surge zones on map with multiplier overlay (incentive to drive there)
  → as supply catches up, surge tapers (5-15 min smoothing)
```

Invariants:
- Surge MUST be disclosed before customer commits (no hidden multiplier).
- Anti-gouging caps during emergencies (declared state of emergency = cap surge or disable, depending on jurisdiction). Failing this = PR + legal disaster (Hurricane Sandy, COVID lockdown era examples).
- Surge calculation auditable per zone per minute (regulators ask).

### 8. Worker offer + acceptance

```
Match decision: candidate worker(s) ranked by score (proximity + acceptance rate + recent activity + cohort policies)
  → offer sent to top candidate
  → worker has timeout window (8-15 sec) to accept
  → on accept: dispatched
  → on reject / timeout: next candidate
  → all candidates exhausted: re-pool with relaxed criteria (longer ETA acceptable)
  → still no match in N min: cancel + refund pre-auth
```

Invariants:
- Acceptance metrics tracked but workers cannot be PENALIZED solely for low acceptance in many jurisdictions (CA Prop 22, NYC TLC, etc.) — algorithmic fairness audit required.
- Pre-trip information shown to worker: pickup location + trip ETA + estimated fare (some jurisdictions require dropoff distance disclosure; e.g., NYC Local Law 144 requires upfront pay disclosure).
- "Acceptance gaming" detection (worker accepts then doesn't move = appears available but unproductive) — flag for review.

### 9. Proof of delivery (POD) — for delivery use cases

```
Worker arrives at dropoff
  → if contactless drop: photo of package at door + GPS confirmation
  → if signature required: customer signs on driver's phone screen
  → if PIN required: customer provides 4-digit code, worker enters
  → if controlled-substance / age-restricted: ID verification + age confirmation + scan
  → POD uploaded → trip completion captured → fare finalized
```

Invariants:
- POD type configurable per delivery type (food default contactless; alcohol mandates ID; pharma mandates signature).
- Failed POD (customer not home, address wrong) triggers retry / return-to-sender flow.
- POD images retained per policy (customer disputes use them as evidence).

### 10. Customer support + dispute

```
Customer reports issue post-trip ("driver took wrong route", "rude driver", "lost item")
  → ticket opened + categorized (auto-categorize from text)
  → if refund category: auto-evaluate criteria (route distance vs estimate) → auto-refund if meets thresholds
  → otherwise: human review queue
  → resolution: refund (full/partial) / driver coaching / no action / driver suspension
  → customer notified of outcome (with reasoning at policy level)
  → worker informed if action taken against them, with appeal path
```

### 11. Lost item recovery

```
Customer reports "left phone in car" via app
  → worker pinged with description + customer contact (with consent)
  → worker confirms found / not found
  → if found: arrange return (drop-off at office / customer pickup / driver delivers next session)
  → if not found: customer informed, advise contacting trip's drop-off location
  → no platform fee for lost-item return (or modest "convenience fee" disclosed)
```

### 12. SOS / emergency button

In-trip safety feature, mandatory in many jurisdictions.

```
Customer or worker taps SOS in-app
  → location + identity + trip details captured
  → notification to platform safety ops + auto-call to local emergency services if configured
  → optional silent alert (don't audibly notify in-vehicle escalation)
  → emergency contacts (pre-configured) notified with location + trip details
```

## P3 — competitive + scale

### 13. Demand prediction + pre-positioning

- Predict demand per H3 cell per hour using historical + signals (weather, events).
- Suggest workers move to high-demand zones (incentive bonus).
- Pre-arrange supply for known events (concert, airport peak).

### 14. Multi-stop / batched delivery

- Restaurant orders: one driver picks up multiple orders, delivers in route-optimized sequence.
- Customer ETAs adjusted with handoff time.
- Earnings split across orders fairly.

### 15. Scheduled / pre-booked

- Customer schedules ride for tomorrow 8am.
- Match made shortly before scheduled time; surge applied at match time, not booking time (or capped per policy — disclose).

### 16. In-app communication (worker ↔ customer)

- Masked phone (Twilio Programmable Voice / SMS) — neither sees real number.
- In-app chat with templated messages (multilingual + faster than typing).
- Retention: chat logs kept for dispute window then purged.

### 17. Worker rewards + tier programs

- Tier based on completion rate + acceptance rate + rating.
- Higher tiers get: priority dispatch, better surge zones first, better cancellation pay.
- Used as retention tool but legal risk if tied tightly to acceptance rate (regulatory).

### 18. Background check refresh + ongoing monitoring

- Continuous monitoring service (Checkr Verified, Sterling SafeGuard) flags new incidents.
- Annual re-checks required in many jurisdictions.

### 19. Vehicle inspection + recurring

- Vehicle inspections every 6-12 months.
- Calendar reminder + grace period; lapse = offline.

### 20. Multi-modal / multi-service

- Same platform serves rides + delivery + jobs.
- Worker can opt into multiple modes; routing chooses best fit per request.

## Idempotency-critical endpoints

- `POST /requests` — duplicate request from re-tap during slow network = dispatching to two workers. Idempotency-Key required.
- `POST /requests/:id/cancel` — re-cancel must be safe.
- `POST /trips/:id/complete` — worker double-tap "Complete" must finalize once.
- `POST /matches/:id/accept` — worker double-tap "Accept" must register once.
- `POST /payments/capture` — repeat must return same captured payment, not double-charge.
- `POST /payouts` — repeat batch must not double-pay worker.
- `POST /tips` — re-tap tip selector must overwrite, not stack.

## Concurrency-critical paths

- Two simultaneous matches for same worker: dispatcher must atomically claim worker. Distributed lock (Redis SET NX with TTL) or transactional DB update.
- Surge zone update: workers + customers see different multipliers if update propagation lags. Versioned zones; quote uses version captured at quote time.
- Customer cancels at the millisecond worker accepts: race. Define order-of-operations (cancel wins if before accept commit; accept wins if before cancel commit).
- Worker offline mid-trip: trip continues but no location updates; alert + emergency check.

## Webhooks to produce

- `request.created`, `request.cancelled`, `request.matched`.
- `trip.started`, `trip.completed`, `trip.cancelled`.
- `payment.captured`, `payment.refunded`.
- `payout.completed`, `payout.failed`.
- `worker.activated`, `worker.deactivated`.
- `dispute.opened`, `dispute.resolved`.
- `sos.triggered`.

## Webhooks to consume

- Identity provider: verification result, expiry warning.
- Background check provider: complete, status change, ongoing-monitoring alert.
- Payment processor: charge succeeded / failed / disputed.
- Payout processor: transfer status, failed transfer.
- Map / routing provider: route data, traffic incidents (if used).
- Insurance provider: policy issued / lapsed / claim filed.

## Real-time delivery infrastructure

- Worker location pings: high frequency (3-5 sec during trip), Redis Streams + downsampling for storage.
- Customer location subscription: websocket fanout via PubSub backbone (Redis Pub/Sub at small scale, NATS/Kafka at scale).
- Push notifications: trip status changes via FCM/APNS (always-deliver category for "driver arriving").
- SMS fallback: for users with notifications off, "Driver arriving" via SMS (Twilio).
- Geofence events: trigger on entering pickup/dropoff radius.
