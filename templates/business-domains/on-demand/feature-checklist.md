# On-demand — feature checklist

The 80%-of-projects-need-this list. On-demand v1s commonly underbuild trust + safety, dispatch fairness, payout transparency — then face regulatory / PR / lawsuit fires within months.

Use this in `business-auditor` reviews + as a P1/P2/P3 planning anchor.

## Customer-facing

### Onboarding + identity
- [ ] Phone signup with OTP verification (primary identifier — regulators want phone-traceable users).
- [ ] Email signup as backup / for receipts.
- [ ] SSO (Apple required on iOS app store; Google for web).
- [ ] Profile photo (helps worker identify pickup; optional).
- [ ] Saved addresses (home, work, custom labels).
- [ ] Payment method add/remove with 3DS where applicable.
- [ ] Multiple payment methods + default selection.
- [ ] Account deletion with grace period (per privacy law).

### Request a service
- [ ] Auto-detect pickup location with manual override.
- [ ] Address autocomplete with map confirm.
- [ ] Drop-off / destination selection with options.
- [ ] Service tier selector (economy / comfort / XL / premium / pet-friendly / wheelchair).
- [ ] Quote display with: ETA, base fare, distance/time fare, surge multiplier (clearly disclosed), service fee, taxes, total.
- [ ] Surge disclosure with reason ("High demand in this area").
- [ ] Schedule for later option.
- [ ] Promo code field.
- [ ] Special instructions field (gate code, leave at door, etc.).

### During trip
- [ ] Live worker location on map.
- [ ] Worker name + photo + vehicle (license plate, make/model, color) before pickup.
- [ ] Live ETA updates.
- [ ] Trip route on map.
- [ ] In-app messaging (masked phone for SMS/call).
- [ ] Share trip status with friend / family (read-only link).
- [ ] SOS / emergency button (mandatory in many jurisdictions).
- [ ] Cancel button with fee disclosure (if applicable).
- [ ] Trip details accessible mid-trip.

### Post-trip
- [ ] Receipt with line-item breakdown (base, distance, time, surge, fees, taxes, tip, total).
- [ ] Email + in-app receipt.
- [ ] Rate worker (1-5 + tags + optional comment).
- [ ] Tip prompt with presets + custom (clear "no tip" option).
- [ ] Report issue (with category picker → routes to support).
- [ ] Lost item flow (contact worker via masked communication).
- [ ] Trip history with re-rate / refund-request paths.

### Account + privacy
- [ ] Trip history with date / cost / route filter.
- [ ] Saved payment methods with remove.
- [ ] Notification preferences per channel.
- [ ] Privacy controls: location sharing, data export, deletion.
- [ ] Emergency contacts list (called on SOS).
- [ ] Two-factor authentication.

## Worker-facing (the driver / courier app)

### Onboarding
- [ ] Identity verification (gov ID + selfie liveness).
- [ ] Driver's license / professional license upload with extraction + expiry tracking.
- [ ] Vehicle registration + insurance + photos + inspection.
- [ ] Background check consent + status tracking (in-progress → approved/denied).
- [ ] Banking / payout method linking.
- [ ] Tax form (W-9 / equivalent).
- [ ] Classification disclosure + signature (independent contractor or employee).
- [ ] Onboarding training modules.
- [ ] First-trip tutorial.

### Going online + receiving requests
- [ ] Online / offline toggle.
- [ ] Heat map of demand zones with surge multipliers.
- [ ] Filter by trip type accepted (rides only / delivery only / both).
- [ ] Incoming offer screen with: pickup location, ETA-to-pickup, dropoff distance, estimated fare (jurisdictional requirement increasing).
- [ ] Accept / reject buttons with clear timeout countdown.
- [ ] Auto-cancel offer if worker doesn't respond.

### During trip
- [ ] Turn-by-turn navigation (in-app or hand-off to Google/Waze/Apple Maps).
- [ ] "Arrived at pickup" button → triggers customer notification.
- [ ] Customer info visible (name, photo, special instructions).
- [ ] In-app messaging (masked).
- [ ] "Start trip" + "Complete trip" controls.
- [ ] Mid-trip cancellation with reason picker.
- [ ] SOS button.
- [ ] Live earnings counter.

### Post-trip
- [ ] Earnings display: base + time + distance + surge + tip + bonus = net (after platform fee).
- [ ] Rate customer (1-5 + tags + comment).
- [ ] Mark issue / no-show / damage with evidence upload.
- [ ] Auto-prompt next request OR remain online for offers.

### Earnings + payout
- [ ] Live earnings dashboard (today / this week).
- [ ] Per-trip breakdown (base, time, distance, tip, bonus, fees, deductions, net).
- [ ] Payout schedule visible (next payout date + method).
- [ ] Instant payout option (with fee transparency).
- [ ] Tax document download (1099 / annual summary).
- [ ] Earnings history.
- [ ] Bonus / promo tracking (e.g., "Complete 25 trips by Sunday for $50").

### Account + safety
- [ ] Document expiry tracking + reminders (license, insurance, vehicle inspection).
- [ ] Re-verification flow when documents lapse (auto-offline until updated).
- [ ] SOS with one-tap.
- [ ] Trust + safety hotline access.
- [ ] Block specific customers (after a bad ride).
- [ ] Deactivation appeal flow.
- [ ] Data export (per privacy law).

## Operator-facing (admin / dispatch / ops)

### Live ops dashboard
- [ ] Map of active trips + idle workers + pending requests.
- [ ] Heatmap of demand vs supply.
- [ ] Surge zones live with multiplier.
- [ ] Active SOS triggers (top priority alert).
- [ ] Active disputes / reports.
- [ ] System health (API latency, push delivery rate, location update freshness).

### Worker management
- [ ] Worker list with filter (status, rating, tier, region).
- [ ] Worker detail: trips, earnings, ratings, complaints, current status.
- [ ] Document review queue (manual ID/license review for edge cases).
- [ ] Background check status integration.
- [ ] Suspend / deactivate worker with reason + appeal toggle.
- [ ] Coaching note / training recommendation flag.
- [ ] Bulk actions for fraud waves.

### Customer management
- [ ] Customer list with search.
- [ ] Customer detail: trips, payment history, complaints, ratings given/received.
- [ ] Block / suspend customer (fraud, abusive behavior).
- [ ] Refund + credit issuance with audit log.

### Dispute + support queue
- [ ] Ticket list with filter (severity, age, category).
- [ ] Auto-categorization with manual override.
- [ ] Route fairness check tool (compare actual vs estimated route).
- [ ] One-click refund (with reason).
- [ ] Trip details + map + chat history visible to support.
- [ ] Escalation paths (legal, T&S, executive).

### Surge + pricing config
- [ ] Per-zone base pricing.
- [ ] Surge algorithm tuning (sensitivity, cap, smoothing).
- [ ] Anti-gouging cap during emergencies (manual override).
- [ ] Promo / coupon CRUD.
- [ ] Pricing experiment (A/B) framework.

### Reports + analytics
- [ ] Daily / weekly / monthly: trips, GMV, take rate, refund rate.
- [ ] Worker churn + new activations.
- [ ] Customer cohort retention.
- [ ] Fairness audit reports (matching distribution by demographic, with care).
- [ ] Compliance reports: tip transparency, NYC TLC pay disclosure, CA Prop 22 quarterly.
- [ ] SLA reports (time-to-match, ETA accuracy, support response time).

### Safety ops
- [ ] SOS handler queue with location + identity + trip context.
- [ ] Incident report intake (assault, theft, accident).
- [ ] Law enforcement portal (subpoena handling).
- [ ] Insurance claim coordination.
- [ ] Wellness check on missed-arrival cases.

## Trust + compliance

- [ ] Privacy policy + terms + community guidelines.
- [ ] Worker contract + classification disclosure (signed at onboarding + when changed).
- [ ] Background check vendor SOC 2 + ongoing monitoring.
- [ ] Identity verification provider (Onfido / Persona) integrated.
- [ ] Insurance binder per trip period (Period 1/2/3 in US-style; equivalents elsewhere).
- [ ] DMCA / illegal content procedures (for in-app messages).
- [ ] Data export for both customers + workers (privacy law).
- [ ] Right-to-erasure handling.
- [ ] DSA / Online Safety Act compliance (UK + EU) including content moderation in chat.
- [ ] Algorithmic fairness audit (matching, deactivation appeals) — annual.
- [ ] Accessibility: wheelchair-accessible vehicle category + pet service category + service-animal policy.
- [ ] Emergency contact + SOS infrastructure (mandatory many jurisdictions).
- [ ] Pay disclosure (NYC Local Law 144, CA SB1162) — pre-trip estimated pay visible to worker.

## Operational

- [ ] Real-time location pipeline (low-latency ≤ 5 sec).
- [ ] Push notification stack (FCM + APNS + SMS fallback).
- [ ] Map provider with cost-managed tier.
- [ ] Routing engine (live traffic + reroute on incidents).
- [ ] Pre-auth + capture pipeline with idempotency.
- [ ] Payout pipeline with retry + dunning.
- [ ] Background check provider integration with continuous monitoring.
- [ ] Insurance provider API for trip-level policy events.
- [ ] On-call for safety incidents (24/7).
- [ ] Capacity planning for events (concerts, holidays, weather).
- [ ] Geofence detection (airports, stadiums, restricted zones).

## Things v1s commonly miss

- Pre-trip pay disclosure to worker (now legally required NYC + CA + EU Platform Work Directive).
- Surge cap during declared emergencies (illegal in many states; lawsuits pile up after every storm).
- Worker insurance period transitions (Period 1 → 2 → 3 not coded; gap in coverage = liability).
- Worker location data retention beyond trip + business need (privacy law violation; stalking cases have happened).
- Two-way rating with retaliation protection (workers shouldn't see who 1-starred them).
- Rating threshold deactivation without appeal path (DSA + general due process — lawsuits).
- Background check expiry monitoring (workers stay active past check expiry).
- Vehicle inspection lapse without trip-blocking (insurance + safety risk).
- Lost item recovery flow (every customer expects it; 3 weeks of support tickets without it).
- SOS / emergency button (mandatory in many jurisdictions; Texas HB 1264, NYC TLC).
- Trip share with contact (safety feature; competitors all have it).
- Cancellation fee disclosure BEFORE customer commits (state consumer protection law).
- Tip transparency to worker (where tip flows; what fee is deducted).
- Payout failure handling + dunning (worker bank closes; payout fails silently; worker quits).
- Algorithmic fairness audit (matching distribution by neighborhood — disparate impact = lawsuit).
- Worker classification document signed (employee vs contractor — basis for everything down line).
- Tax document delivery (1099-NEC > $600 US contractors; analogous abroad).
- Mid-trip route deviation alert (worker takes scenic route to inflate fare; auto-detect).
- Receipt detail itemization (regulatory in some places; reduces support tickets everywhere).
- "Why this driver" transparency on match algorithm (DSA + general user trust).
- Wheelchair / service-animal request flow (ADA + similar).
- Local language support (English + Spanish for US; Arabic for KSA / UAE; French for QC).
- Demand prediction + worker pre-positioning suggestions (without it, supply is reactive only).

## Things often over-built in v1 (defer until validated)

- Multi-modal (rides + delivery + jobs in one app) — pick one, dominate, expand.
- AI-driven dynamic pricing (rule-based surge works; ML adds opacity + fairness lawsuits).
- Driver-facing route optimization beyond turn-by-turn (Waze does this).
- In-app calling vs masked SMS (SMS is fine + cheaper).
- Subscription pass for customers (Uber One came late; not v1).
- Crypto payouts.
- Carbon-offset opt-in.
- Self-driving integration.
- Loyalty tiers for customers (basic discount works for v1).
- Voice-only ordering ("Alexa, get me an Uber").
- Augmented reality wayfinding to pickup point.
