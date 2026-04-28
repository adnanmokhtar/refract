# On-demand — domain-specific anti-patterns

Generic SRE advice doesn't catch these. They're traps you only learn by running an on-demand platform — or by watching a competitor get sued.

## Matching + dispatch

- **Cold-start dispatch**: matching the closest worker without ETA constraint sends a worker 25 minutes away. Constrain by ETA AND by worker rating, not just proximity.
- **Acceptance gaming**: workers accept then sit still to game acceptance-rate metrics. Detect via location + acceleration; flag stationary workers with active acceptances.
- **Surge zone boundaries**: workers cross zone boundary mid-trip to "earn" surge that ended elsewhere. Lock surge multiplier at request time, not at trip start.
- **Stale offer broadcast**: offer sent to worker, customer cancels, worker accepts a phantom job. Atomic check + invalidate via short TTL on offers.
- **No timeout on accept**: offer sits in worker's app for 60 seconds; customer's ETA is now wrong. Hard-timeout offers (~10s) and re-broadcast.
- **Re-dispatch loop**: worker A declines → broadcast to B → A re-receives same offer 2 seconds later. Maintain decline-history per worker per offer, exclude.
- **Match radius widening without notification**: customer was promised "5 min ETA" at 1km radius; matching expanded to 5km giving 12 min ETA. Update customer-facing ETA when radius widens.

## Pricing + surge

- **Surge applied after acceptance**: customer accepts a fare; surge calculation drift updates the fare 10% before completion. Surge multiplier is FROZEN at acceptance.
- **Surge during emergency**: hurricane declared, surge auto-multiplies because demand spike. Anti-gouging law violation. Always cap surge in emergency-declared geos (state APIs available).
- **No surge cap**: customer charged 5x base; backlash + chargebacks. Cap at 2-3x outside emergencies, 1x during.
- **Hidden minimum fare**: short trip costs $4 minimum, but display showed "$2 estimate". Display minimum prominently before confirmation.
- **Tip after surge**: surge ends, customer tips on inflated total — wrong. Tip on base, not surge.
- **Cancellation fee during platform-side cancel**: customer charged when worker cancels. Fee applies only to customer-initiated cancellation post-acceptance.
- **Currency rounding asymmetry**: rider charged in cents, worker paid in cents, but conversion at different rates. Workers underpaid by fractions × millions of trips = millions lost.

## Worker management

- **Deactivation without appeal**: worker fired with no human review, no evidence shown. NYC TLC, CA Prop 22 violations.
- **Acceptance rate as deactivation criterion**: forces workers to accept money-losing trips → worker classification risk (employee-like control).
- **Rating retaliation**: customer 1-stars worker for following GPS instead of "shortcut"; worker can't dispute. Build dispute mechanism + protect worker on first low rating.
- **Background check expired without trip-block**: worker drives with expired license. Auto-block trip acceptance on document expiry day.
- **Insurance lapse undetected**: personal insurance lapses, worker still picks up trips. Daily verification call to insurer's API.
- **Onboarding fraud**: stolen identity + fake documents + verified face match (deepfake). Layered detection: liveness + behavioral + cross-reference + manual review for edge.
- **Vehicle swap uncaught**: worker registers Honda Civic, drives '08 minivan. Period vehicle inspection + customer-reported plate vs. on-record plate cross-check.
- **Worker double-app**: working two platforms simultaneously, accepts on yours during another platform's trip → late arrival. Track time-since-last-completion; flag impossible acceptances.

## Trip lifecycle

- **Trip not started despite "accept"**: worker accepted then went home. Detect via location not moving + cancel automatically with worker penalty.
- **Trip "completed" while customer/item still in vehicle**: worker presses Complete to game payout. Customer must confirm completion (one-tap) OR location-fence triggers complete.
- **Wrong dropoff completion**: worker completes trip 500m from actual dropoff. Dropoff fence + photo proof required for delivery.
- **Trip duration manipulation**: worker takes long route to inflate per-mile pay. ETA + actual time delta logged; flag deviations >X%.
- **Lost item recovery**: customer reports loss; no driver-side prompt; item disappears. Auto-prompt driver + customer + mark trip "open" until resolved.
- **Refunds without trip review**: customer claims didn't receive item; auto-refund without checking driver's proof-of-delivery photo. Refund only after evidence review.

## Privacy + safety

- **Location stored at GPS precision indefinitely**: GDPR + CCPA fines. Coarsen to ~1km grid after trip + 30-day operational window.
- **Worker home location exposed**: customer sees worker's stationary GPS between trips → stalking risk. Hide worker location when no active trip.
- **Customer phone exposed to worker**: harassment risk. Use platform-mediated calls / SMS via masked numbers.
- **Driver name + photo persisted in customer history**: worker identifiable forever; safety risk for worker. Anonymize after N days.
- **Trip share with contacts insecure**: shared link unauthenticated → contact + their friends can track. Time-limited tokens.
- **SOS button stripped of context**: button pressed but no location / trip data sent to operator. Always include trip + worker + customer + GPS.
- **Worker location sold to advertisers**: massive enforcement risk. Don't.

## Payments + payout

- **Worker payout calculation displayed != actual**: displayed earnings doesn't match payout (bonus criteria not met, surge ended, deduction applied). Always show breakdown + reasoning.
- **Instant payout with insufficient float**: worker requests instant; platform's float is empty. Pre-fund + automate float top-ups.
- **Tip taken before card auth confirms**: customer tips $5; card auth fails post-trip; worker promised tip never delivered. Tip clears with trip charge, atomically.
- **Currency misalignment in cross-border**: trip in Mexico, worker paid in USD at stale FX rate. Use spot rate at trip-completion, recorded.
- **Refund without payout recall**: customer refunded; worker keeps payout. Reconciliation drift over millions = millions.
- **Chargeback months after trip**: worker already paid; clawback impossible. Hold % of earnings as chargeback reserve OR insure.

## Ratings + feedback

- **Average rating without volume floor**: new worker has one 1-star rating → 1.0 average → deactivation. Require N trips before rating affects status.
- **Rating tied to identity**: customer sees worker name, rates badly, worker retaliates next time. Two-way blind ratings.
- **Tip prompts that gray-shame**: showing 30% as default + small "no tip" link = FTC dark-pattern enforcement.
- **Rating without context**: worker rated 1-star for following GPS in heavy traffic. Allow worker to add context to disputed ratings; trust+safety reviews.

## Operations + ops tooling

- **Surge incentives without ROI tracking**: ops triggers $5 boost in zone, no measurement of incremental supply added vs cost.
- **Deactivation queue without appeal SLA**: deactivated workers wait weeks for review → income loss → bad PR + lawsuit.
- **Manual permit tracking**: city permit expires unnoticed → operation banned. Auto-expire alerts + dashboard.
- **No emergency mode**: hurricane / event / outage hits; no playbook to suspend / boost / reroute. Pre-built emergency mode toggle per city.
- **Customer support bot for safety incidents**: rape/assault report routes to chatbot. Human path for safety category, always.

## Algorithmic transparency

- **Algorithm decisions undocumented**: regulator subpoenas "why was this driver deactivated?" — no audit log. Log every algorithmic decision with inputs + version + reasoning.
- **Algorithm changes deployed without worker notice**: pay structure changes at midnight; workers wake to new economics. Notice period + change log.
- **Bias in matching / pricing**: customer demographic correlates with longer wait or higher surge. Test for disparate impact; fix.
- **Worker classifications algorithm-driven**: decisions on "preferred driver" status hidden in opaque score. EU Platform Work Directive requires explanation.

## Cross-platform / multi-app

- **Worker on multiple platforms simultaneously**: hard to detect; usually fine but problematic when both deliveries collide.
- **Cross-platform poaching**: another platform offers $X bonus to switch; worker leaves mid-shift. Retention via tenure incentives, not just per-trip.

## City + market expansion

- **Launching without permit**: operating in cities that explicitly require platform permits (NYC, Seattle, Toronto). Get the permit first.
- **Tax misreporting in new market**: 1099-K threshold, DAC7, VAT — each market has reporting rules. Default to over-collecting tax info; figure out reporting after.
- **Vehicle fleet incompatibility**: some markets require commercial plates, painted vehicles, taxi medallions. Research before recruiting drivers.
- **Worker classification differences**: launching in EU under "contractor" model = automatic Platform Work Directive scrutiny.

## Data integrity

- **Trip events out of order**: arrival-at-pickup logged AFTER trip-complete due to race. Use server-time ordering + idempotency keys.
- **GPS noise mistaken for movement**: stationary worker's GPS jitters; logged as "moving" → flagged as accepting and going. Filter low-confidence GPS.
- **Phantom trips from old offers**: stale offer accepted via cached app version → trip created for cancelled customer. Server-side validity check at accept time.

## UX traps

- **Confirmation screen with hidden total**: customer sees "approx $12" but final is $18 (surge + waiting time + clean fee). Show breakdown pre-confirmation.
- **Worker app burning battery**: GPS at 1Hz drains phone in 4 hours. Adaptive frequency based on motion.
- **Notifications storm**: "trip available" + "still waiting" + "boost zone" + "rating updated" + ... worker mutes the app + misses real notifications. Notification budget per hour.
- **Lost items UX dead-end**: customer reports lost item; sees only "we'll contact the driver" then silence. Status updates + resolution path.
- **Cancel button hidden after a few seconds**: app makes cancel intentionally hard → customer rage. Cancel must be one-tap, always.
