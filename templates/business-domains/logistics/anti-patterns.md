# Logistics — domain-specific anti-patterns

Generic shipping bugs cause customer support tickets. Logistics anti-patterns cause regulatory action, lawsuits, and physical losses (lost cargo, accidents).

## Address handling

- **Single normalization for all carriers.** UPS-normalized address fed to USPS rejects (different rules); label fails. Track per-carrier normalized form OR re-normalize per carrier at label purchase.
- **Hard-rejecting addresses on validation.** Real addresses (rural, new construction, military) often fail validators. Soft-warn + allow override; log overrides.
- **Address fields shoved into one string.** "123 Main St Apt 5 Springfield IL 62704" parsed downstream → suite goes missing → carrier delivers to street, not apartment.
- **State/province field free text.** "Calif" vs "CA" vs "California" — carriers reject some forms. Constrain to ISO codes.
- **Country defaults to US silently.** International recipient gets domestic label; package returned. Country-first form; required.
- **Apartment "Unit 5" stored without number prefix.** Carrier label prints "5" — driver searches building 5. Standardize: always include "Apt" / "Unit" / "#" prefix.
- **Phone number not captured.** Required for international + many last-mile carriers (Uber Connect, courier). Skip = failed delivery.
- **No EIN / EORI on commercial international.** Customs hold; broker fees. Required field for B2B export/import.
- **PO Boxes mixed with street.** USPS only delivers to PO Box; UPS/FedEx don't. Detection + carrier compatibility check.
- **Geocode result trusted blindly.** Geocoder maps "1234 Main" to an arbitrary street; bad routing. Confidence threshold + parcel boundary cross-check.

## Tracking events

- **Duplicates not deduped.** Carrier sends same scan 3 times → 3 customer SMS → support storm. Dedupe key: (tracking#, event_code, event_timestamp at minute granularity).
- **Out-of-order events change derived status.** Hub batch upload arrives late; "out for delivery" event after "delivered" event = status flips back. Re-derive status from full event log; never trust last-event-only.
- **Status flickering.** "In Transit" → "Out for Delivery" → "In Transit" (warehouse re-sort) → notification spam. Suppress backwards transitions OR batch notifications.
- **Polling at high frequency for static shipments.** Carrier API quota burned on shipments not moving. Backoff schedule (1h initial, double up to 1 day for stale).
- **Webhook secret static, never rotated.** Compromised once = forever. Rotation cycle.
- **Webhook with no HMAC verification.** Anyone POSTs fake "delivered" → customer notified of phantom delivery. Verify signature.
- **Tracking events stored indefinitely.** Storage explosion + privacy. Retention policy (1-3 years typical).
- **Carrier-specific event codes leaked to UI.** Customer sees "DXYZ-001" — meaningless. Normalize to user-friendly statuses.
- **No fallback when carrier silent.** Shipment stuck "in transit" 14 days; no alarm. Auto-flag stale shipments + ops queue.

## Label + purchase

- **Idempotency key absent on label purchase.** Network retry → 2 labels = 2 charges. Required.
- **Void window missed.** Carrier voids only within 24h; ops rebook label next day; original label still charged. Void-window monitor + auto-void unused.
- **Label generated for incorrect package.** Item sold but pack-out used wrong order; label-to-shipment binding broken. Scan-to-pack workflow.
- **Label PDF not stored.** Reprint requires re-purchase (= new charge). Persist label asset + metadata.
- **Thermal printer protocol mismatch.** ZPL sent to EPL printer = blank labels. Detect printer + serve correct format.
- **Old labels reused for new shipments.** Tracking history confused; carrier billing disputes. Label single-use enforced.
- **Multi-piece master label disconnected from children.** Tracking master vs children inconsistent; recipient doesn't know how many parcels expected. Link master + children + display.

## Dim weight + cost surprises

- **Dimensions optional at creation.** Customer ships oversize; carrier billed by dim weight; merchant rebilled $50 weeks later. Mandatory dims.
- **Dim weight not previewed at quote.** Quote $5; actual bill $25. Show dim weight calc + final billable weight.
- **Carrier divisor outdated in code.** UPS changed divisor 2017 → calculations off; customer underpriced. Update divisors per carrier policy changes.
- **Surcharge accumulation invisible.** Residential + fuel + peak + over-max-length → 2x base rate. Itemized breakdown.
- **Negotiated rates not applied.** Customer's UPS account has 30% off but list rates shown; conversion lost OR money left on table. Account credentials → negotiated tier auto-pulled.

## Service availability

- **Service code purchased to non-served zone.** "Next Day Air" to Alaska — carrier doesn't run there same-day; downgrades automatically; customer expectations broken. Validate service-to-zone before purchase.
- **Saturday/Sunday delivery assumed.** Most carriers don't run weekends; ETA wrong. Calendar-aware transit calc + delivery-day filter.
- **Holiday calendar absent or stale.** Carrier-observed holidays (Memorial Day, Labor Day, Thanksgiving, Christmas, regional) — transit excludes those days.
- **International transit not zone-checked.** Some countries unreachable for some services; quote returns rate; label fails at print.
- **Cut-off times not respected.** Carrier last-pickup at 5pm; label printed at 4:45 has no chance; ETA wrong. Cutoff aware ETA + warn before purchase.

## Customs + cross-border

- **HS code missing for international.** Customs holds; surprise tariff bill; delays of weeks. Mandatory HS for international.
- **Customs value undeclared / incorrect.** Under-declaration = customs fraud (criminal); over-declaration = needless duties. Use actual transaction value.
- **Country of origin ignored.** Tariff rate hinges on origin (NAFTA/USMCA preferences, anti-dumping duties). Capture + propagate.
- **DDP advertised but not collected at checkout.** Carrier delivers; customer charged at door; refuses; RTS. Either collect at checkout (DDP) or disclose DDU prominently.
- **Restricted commodity sent to country that bans it.** Knife to Korea (restricted); seized. Per-country restricted-commodity lookup.
- **No sanctions screening on recipient.** Sanctioned individual / entity / country shipped to → OFAC violation, fines + criminal. Screen at booking.
- **Section 321 ($800 de minimis) abuse.** Splitting shipment to avoid duties → CBP audit + back-duties + penalty.

## Driver app + safety

- **Location tracked off-duty.** Driver clocked out, app still pings GPS; privacy lawsuit (CA, EU). Halt tracking on duty-end.
- **HOS warning as soft suggestion.** Driver pushes through; accident; lawsuit. Hard block at HOS limits.
- **DVIR optional.** OOS vehicle driven; DOT roadside violation; potentially deadly. Block route start until DVIR.
- **Photo POD includes minor / face / license plate.** Privacy violation + GDPR. Auto-blur faces + plates.
- **Signature stored as image without proof.** No timestamp / GPS on signature. Embed metadata.
- **POD optional on high-value.** Lost-package claim with no POD = denial. Mandatory POD; high-value mandates signature.
- **Driver app login persistent.** Driver fired; logs in next week; sees customer addresses. SSO + immediate revocation.
- **Biometric face login without BIPA consent (IL).** $1k-$5k per violation; class actions. Explicit consent + retention schedule.
- **Driver phone number exposed to recipient.** Personal phone harassed; driver quits. Use masked numbers (Twilio).

## Route + dispatch

- **Route built without time-window respect.** Stop has 9-11am window; route arrives at 2pm; failed delivery. VRP solver must respect windows.
- **Vehicle capacity not checked.** 200 cuft of packages on 150 cuft van; can't load. Capacity validation.
- **Hazmat-incompatible loads on same vehicle.** Class 3 + Class 5 in proximity = fire risk. Compatibility matrix.
- **Refrigerated load on non-reefer vehicle.** Cold chain broken; product spoiled. Vehicle-attribute matching.
- **Auto-route ignores driver familiarity.** New driver on most-complex route; productivity tanks. Driver-skill weighting.
- **No re-optimization mid-route.** Vehicle breakdown → manual reassignment chaos. Real-time re-optimization or ops-friendly bulk reassign UI.

## Manifest + EOD

- **Manifest not closed at end of day.** Carrier doesn't process; rebill or lose tracking. Auto-close with EOD scheduler.
- **Manifest mismatch (shipped not on manifest).** Carrier accepts on faith first time; rebills + relationship damage. Reconciliation step.
- **Manifest closed with shipments not yet ready.** "Closed but I haven't packed it" → carrier confused. Workflow ordering.

## Pickup management

- **Pickup requested without sufficient lead time.** Carrier no-show; customer waits. Honor carrier's minimum lead time.
- **Pickup window too narrow.** Driver arrives 5 min late = missed; rebill of pickup fee. Window-buffer logic.
- **No-show pickup billed regardless.** Carrier shows; nothing to pick up; charge. Confirm-or-cancel near window.

## Returns

- **Return label included in box but not trackable.** Customer ships return; merchant unaware; can't refund. Use trackable return label; subscribe to events.
- **Return RMA not linked to original order.** Merchant receives return; can't reconcile. Always RMA → original.
- **Return shipping cost shown to customer too late.** Customer expects free return; charged at print; complaint. Disclose at request.
- **Restocking fee at refund without disclosure.** Refund less than expected; chargeback. Disclose in policy + at request.

## Claims

- **Claim filed without evidence.** Carrier denies. Auto-prompt for photos + value docs.
- **Claim filed past window.** Carrier rejects on filing-deadline grounds. Track windows + auto-flag.
- **Claim status not tracked.** Months pass; merchant assumes denied; doesn't follow up. Status pipeline + escalation.
- **Refund issued before claim approved.** Merchant double-loses. Approval-then-refund workflow OR explicit policy.

## Operational scale

- **Photos at full DSLR resolution.** Storage cost explodes. Compress + size-cap on upload.
- **Tracking event histories never archived.** Hot table grows to TB; queries slow. Archive after 1y to cold storage.
- **Webhook outbound to slow customer endpoint blocks worker.** Pool starvation. Async + timeout + DLQ.
- **Carrier API credentials in plaintext config.** Leak = fraud + theft. KMS / vault.
- **Single carrier credential for all tenants.** Tenant rate-card leak; account-level errors blast all. Per-tenant credentials.
- **No SLA monitoring on tracking webhook delays.** Consumer notifications hours late; degraded experience. Monitor end-to-end latency.
- **Address-validation provider rate-limit on Black Friday.** Whole platform stalls. Provider redundancy + caching.

## Money + reconciliation

- **Carrier adjustments ignored.** Carrier rebills $0.50 each on 10k shipments → $5k loss un-noticed. Reconciliation pipeline matching adjustments to shipments.
- **Refunds for void labels not posted.** Money sits with carrier; you've "paid" for nothing. Auto-post refunds.
- **Insurance premium per shipment but no tracking.** Insurance billed; coverage uncertain; claim time discovers gap. Per-shipment coverage record.
- **Currency mismatch in international rate.** Carrier returns USD; customer expects EUR; conversion missing. Currency-aware money type.
