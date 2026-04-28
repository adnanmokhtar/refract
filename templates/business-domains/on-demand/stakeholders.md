# On-demand — stakeholders

A three-sided market: customers requesting service, workers providing it, platform operating between. Each has different KPIs and different ways to break the system.

## Customer (rider / diner / homeowner)

The demand side.

**Workflows:**
- Open app, request service (with destination / order / job description).
- See ETA + price quote.
- Accept; wait for dispatch.
- Track worker en route.
- Receive service / delivery / arrival.
- Pay (auto-charged) + tip (optional).
- Rate worker.
- Re-request as needed.

**Pain points:**
- "How long until they get here?" — ETA accuracy matters more than absolute speed.
- Surge pricing without explanation feels predatory.
- Driver/worker cancels mid-dispatch — back to square one.
- Lost item / wrong order — recovery is opaque.
- Payment dispute — customer service is bot-driven; escalation hidden.
- Safety incident — wants real human help fast.

**KPIs:**
- Request → match time.
- Match → arrival time accuracy.
- Cancellation rate (customer + platform-initiated).
- CSAT / NPS post-trip.
- Repeat rate (weekly / monthly).
- LTV.

## Worker (driver / courier / handyman / cleaner)

The supply side. Often treated as data points; the platforms that build long-term win.

**Workflows:**
- Onboarding: ID + license + insurance verification + background check + vehicle inspection.
- Toggle online when ready to work.
- Receive request offer (with limited info — pickup location, est. payout).
- Accept or decline within seconds.
- Drive/walk to pickup.
- Mark arrival; pickup customer/item.
- Deliver to dropoff; mark complete.
- Rate customer.
- View earnings; cash out (instant or weekly).
- Manage support issues (lost items, customer disputes, vehicle damage).

**Pain points:**
- Acceptance-rate metrics that punish declining low-pay trips → forced to accept money-losing jobs.
- Deactivation without cause + no appeal → loss of income overnight.
- Earnings opacity — can't reconcile what was promised vs what was paid.
- Slow customer support when they're the ones in trouble.
- Insurance gap during the "wait for next ride" period.
- Surge ending mid-trip → much lower payout than expected.
- Customer rating retaliation (one-star for following the route GPS suggested).
- Pay rate opacity — same trip type pays differently with no explanation.
- Hours of work disclosed in app != hours worked (driving to position, waiting in queue).

**KPIs:**
- Effective hourly earnings (after expenses).
- Acceptance rate.
- Cancellation rate.
- Rating average.
- Trips/week.
- Tenure (90-day retention).
- Re-activation rate after pause.

## Operations + dispatch

The platform's eyes-on-the-ground team. Day-to-day operations heroes.

**Workflows:**
- Monitor real-time supply/demand by zone.
- Trigger incentives (boost areas with high demand).
- Handle high-priority customer/worker incidents (accidents, safety, complaints).
- Investigate fraud (collusion between worker + customer, fake trips).
- Resolve disputes (lost items, wrong orders, payment chargebacks).
- Onboard new workers (verify documents, escalate edge cases).
- Coordinate with city authorities during events / weather / emergencies.

**Pain points:**
- Tools fragmented across 5 dashboards.
- Real-time demand spike with no alert → opportunity missed.
- Worker complaints flood during incident, can't triage.
- Documents fail OCR + manual review queue grows.
- City permit changes by emergency declaration → must update geofences immediately.

## Trust + safety

A specialized ops sub-team. Often overworked.

**Workflows:**
- Triage SOS button activations.
- Review safety incident reports (post-trip).
- Investigate pattern complaints (same worker, multiple riders).
- Coordinate with law enforcement on subpoenas + active investigations.
- Manage deactivation decisions for safety reasons.
- Review background check refreshes.

**Pain points:**
- SOS button activates accidentally → false alarms drown signal.
- Worker incident reporting from customers is anonymous — hard to verify.
- Law-enforcement requests come with deadline pressure.
- Deactivation appeals require evidence preservation; tooling is poor.
- Cross-region patterns invisible without unified data.

## Customer support

High volume, high frustration, low pay.

**Workflows:**
- Handle in-app tickets (lost item, wrong order, payment dispute).
- Triage complaints by severity (safety > payment > rating).
- Issue refunds / credits (within authority limits).
- Escalate to ops / trust+safety / engineering.
- Track resolution SLAs.

**Pain points:**
- Bot-first responses irritate customers + workers; humans backlog.
- Authority limits frustrate ("must escalate for >$X refund").
- Repeat-issue customers — abuse vs legitimate?
- Worker tickets often deprioritized (smaller volume but they ARE the supply).

## Worker community / labor relations

Often informal until labor action forces formal engagement.

**Workflows:**
- Monitor worker forums + social media for sentiment.
- Engage with worker advocacy groups.
- Negotiate with collectives (where legal — Seattle, NYC sectoral bargaining).
- Communicate policy changes (notice periods).
- Handle media inquiries about worker conditions.

**Pain points:**
- Sudden policy changes (pay structure, deactivation rules) trigger walkouts.
- Worker organizing meets aggressive response → PR disaster.
- Local regulations move faster than corporate policy can adapt.

## Marketing + growth

Demand acquisition + retention.

**Workflows:**
- Customer acquisition campaigns (referral, paid ads, partnerships).
- Promo codes + first-trip discounts.
- Loyalty / repeat-rider incentives.
- Worker referral programs.
- Localization for new markets.

**Pain points:**
- Promo abuse (one customer → many free trips via fake accounts).
- Attribution to channel (which campaign delivered the LTV).
- Worker referral fraud (referral chains for nonexistent workers).
- Surge perception destroying brand (negative virality).

## Finance + accounting

The reconciliation function.

**Workflows:**
- Daily settlement (charges, payouts, fees).
- Worker payout cycle (instant + weekly).
- Tax reporting per worker (1099-K, 1099-NEC, DAC7).
- Insurance claim coordination.
- Refund accounting.
- VAT/GST/sales-tax remittance.
- Commission calculation + audit.
- Treasury management (instant payout cash flow).

**Pain points:**
- Worker tax forms missing / wrong → IRS penalties.
- Refund accounting drift between system + provider.
- VAT in EU markets — deemed-supplier rules complex.
- Insurance claim timing — pay worker now, recover later from insurer.

## City + regulatory affairs

Increasingly important; often the difference between operating + being banned.

**Workflows:**
- Monitor city council meetings + state legislation.
- Comment on proposed regulations.
- Maintain operating permits (per-city; often per-airport).
- Submit data to regulators (NYC TLC trip data, Seattle min-wage compliance, EU DAC7).
- Negotiate with airports / venues / event organizers.
- Manage city-imposed fees + caps.

**Pain points:**
- Regulations vary city-by-city; product team can't customize for every regulator.
- Data submissions to regulators have schema requirements that drift.
- Permit lapse = city bans operation.
- Antagonistic cities (some cities specifically target gig platforms).

## Insurance partner

External, but critical.

**Interactions:**
- Coverage definitions per period (1, 2, 3).
- Claim submission workflow.
- Premium reconciliation (often per-trip-mile).
- Adverse selection (high-risk drivers).
- Coverage gaps (driver's personal insurance, platform commercial, customer's auto).

## Stakeholder-driven priorities

When building or auditing:

| Friction signal from... | Fix priority |
|---|---|
| Workers churning at 60-day mark | Pay transparency + tenure incentives + better support |
| Customers complaining about ETAs | Improve dispatch ML + matching radius logic |
| Ops drowning in incidents | Self-service refund within thresholds + better triage tooling |
| Safety team overwhelmed | Better SOS triage + customer-side reporting flow |
| Workers organizing / striking | Policy change notice periods + meaningful worker council |
| City regulators threatening ban | Dedicated reg-affairs team + data-sharing pipelines |
| Insurance costs climbing | Better worker screening + accident-prevention features |

## Anti-pattern: treating workers as data points

The platforms that win long-term build worker trust. Sudden algorithm changes, opaque pay, hostile support, and aggressive deactivation cycles destroy supply faster than any growth campaign can replenish. Build worker tools with the same care as customer tools.
