# Logistics — core flows

P1 = without these, no shipments move. P2 = without these, customer support drowns. P3 = differentiator.

## P1 — must-have for v1

### 1. Rate shopping
The pre-purchase quote layer.

```
Caller submits shipment intent (origin + destination + parcel dims/weight + service preferences)
  → validate addresses (basic format + completeness)
  → normalize addresses per carrier requirements (different carriers, different normalization)
  → for each enabled carrier: query rates API
    → carrier returns N services with rate + estimated transit + delivery date
  → aggregate rates from all carriers
  → apply markups / discounts / customer rate cards
  → sort by user preference (cheapest / fastest / preferred carrier)
  → return rate set with quote_id
  → quote expires in N minutes (rates fluctuate; carrier credit changes)
```

Key invariants:
- Address normalization differs per carrier — same input may be "valid" for UPS, "invalid" for USPS. Track per-carrier normalization result.
- Dim weight calculation: `(L × W × H) / divisor` — divisor varies (139 for domestic US, 5000 metric, etc.).
- Surcharges: residential, fuel, peak season, oversize, additional handling — included in API rate or applied separately depending on carrier.
- Negotiated rates: carrier accounts have shipper-specific pricing; pull-rates must use the right account credential.
- Do NOT cache rates beyond their TTL (fuel surcharges change weekly).

### 2. Label creation + printing
```
User selects rate + parcel info confirmed
  → call carrier rate-purchase API with quote_id (idempotency key required)
  → carrier returns: tracking_number + label (PDF/PNG/ZPL/EPL)
  → store label in object storage; generate signed URL
  → emit shipment.label_purchased event
  → if user wants print: stream PDF / send to thermal printer (ZPL for Zebra)
  → label has barcode + tracking number + service indicator + return address + recipient address + carrier branding
```

Key invariants:
- Idempotency on label purchase — double-charge avoided. Idempotency key = customer-supplied OR hash of (shipment_id + carrier + service).
- Voiding: call within carrier's void window (typically same-day or 24-48h); after window, label is non-refundable.
- Multi-piece shipment: one master + child labels; track relationship.
- Hazmat / dangerous goods: additional declaration + label markings; carrier-specific (ORM-D phased out 2021; Limited Quantity now).

### 3. Pickup scheduling
```
Carrier pickup requested for date + time window + count + total weight
  → carrier API returns confirmation + pickup_id
  → driver arrives within window
  → manifests / packing slips ready
  → driver scans pickup → carrier confirms via API or webhook
  → if missed pickup: reschedule (and don't re-bill if same-day)
```

### 4. Tracking ingestion
```
Carrier emits tracking event (webhook or polling)
  → match tracking_number to shipment in our system
  → dedupe (carrier may emit same event repeatedly)
  → categorize event (info_received / in_transit / out_for_delivery / delivered / exception)
  → store event with timestamp + location + raw event code + normalized status
  → emit shipment.tracking_updated event
  → if status terminal (delivered / lost / returned): update shipment.status
  → notify subscribers (customer email/SMS, internal listeners)
```

Key invariants:
- Webhook dedupe: many carriers send the same event 2-3 times for reliability. Store `(tracking_number, event_code, event_timestamp)` uniqueness.
- Out-of-order events: carrier scans uploaded in batches; later "in transit" event arrives after "delivered". Trust event_timestamp not arrival_time.
- Polling fallback: carriers without webhooks need polled; rate-limit-conscious; back off when no change.
- Status transitions: monotonic forward (don't downgrade from delivered to in_transit on a stale event).

### 5. Delivery (own fleet last-mile)
```
Routes planned (P2 — optimization)
  → routes assigned to drivers (push to driver app)
  → driver starts route (location tracking begins)
  → for each stop:
    → driver navigates (turn-by-turn via Mapbox/Google)
    → driver arrives → stop status = arrived
    → driver delivers → captures POD (photo + signature + PIN)
    → if delivery fails: capture reason (no_one_home / refused / wrong_address / damaged)
    → next stop
  → end of route: vehicle returns to hub; reconcile undelivered packages
```

Key invariants:
- POD capture mandatory; carrier-of-record liability without it.
- Photo POD: timestamp + GPS in EXIF; auto-blur faces (privacy).
- Signature POD: capture vector or PNG; size-limit for storage; retention 12+ months for chargebacks.
- Driver location: stream during active duty only; stop on duty-end (privacy + storage cost).
- Failed delivery: customer notified within 1h; rescheduling/redirect options offered.

### 6. Return-to-sender / failed delivery
```
Multiple delivery attempts (carrier-specific count, typically 3)
  → carrier holds at facility / pickup location
  → if not picked up within hold period (~5-10 days): RTS
  → label generated by carrier for return leg (or use original return label)
  → in-transit back to origin
  → on receipt: warehouse processes (restock, refund, dispose)
```

## P2 — keep customers + reduce ops drag

### 7. Address validation + correction
- Pre-shipment: validate against USPS / Melissa / SmartyStreets / Google.
- Suggest corrections; user accepts/overrides.
- For commercial addresses: validation vs USPS commercial directory.
- Apartment / suite parsing (#3 vs Apt 3 vs Unit 3).
- Country-specific formats (Japan, Brazil, India have unique conventions).

### 8. Tracking webhooks (outbound to your customers)
- Webhooks emitted on every status change.
- HMAC signature verification.
- Retries with exponential backoff (3-7 attempts).
- Dead-letter queue for permanent failures.
- Customer-configurable webhook endpoints.

### 9. Customer notification
- Email + SMS + push on key transitions: shipped / out for delivery / delivered / exception.
- Branded tracking page (customer's brand, not carrier's).
- Self-service rescheduling / address change (if carrier supports + service allows).
- Delivery instructions update mid-transit (front porch / leave with neighbor / require signature).

### 10. Manifests + end-of-day
- Group day's shipments per carrier into a manifest.
- Carrier scans manifest barcode → bulk acceptance.
- Closes the day; generates EOD reports.

### 11. Returns
- Return label generation (pre-paid or merchant-paid).
- Return tracking distinct from outbound.
- RMA reference linking to original shipment.
- Refund/restock workflow downstream.

### 12. Insurance claims
- Filed within carrier's window (typically 60-180 days).
- Evidence: photos, declared value docs, repair quotes.
- Status tracking + escalation when stuck.

## P3 — differentiator

### 13. Route optimization (own fleet)
- Vehicle Routing Problem (VRP) with constraints: time windows, vehicle capacity, driver hours, traffic, vehicle compatibility.
- Real-time re-optimization on disruption (traffic jam, vehicle breakdown).
- Multi-day planning for non-urgent.

### 14. Predictive ETA
- ML model on historical transit times + traffic + weather + season.
- Customer-facing ETA windows narrower than carrier's broad estimates.
- Update mid-transit as conditions change.

### 15. Carrier diversification + auto-routing
- Rules engine: "if Zone X + cheap-service-OK → carrier A; else carrier B".
- Fallback if primary carrier API down.
- Carrier scorecard (on-time rate, damage rate, claims rate) per lane.

### 16. Cross-border / customs
- HS code lookup + classification.
- Customs forms generation (CN22, CN23 for postal; commercial invoice for private carriers).
- Duty + tax estimation at checkout (Zonos, Easyship).
- Restricted commodities check per destination country.
- DDP collection at checkout vs DDU at delivery.

### 17. Hazmat shipping
- Dangerous Goods Declaration form generation.
- Per-carrier + per-mode (air vs ground vs ocean) restrictions.
- IATA/IMDG class lookup.

## Specific concerns

### Inflight events out-of-order
Scan at hub uploaded in batch; "delivered" event arrives before "out for delivery". Trust `event_timestamp` field not `received_at`; preserve original event order; re-derive shipment status from event log.

### Carrier API outages
Critical to ops. Buffer requests; retry with backoff; if persistent: route to alternate carrier OR queue for later; surface to user.

### Address ambiguity
"123 Main" matches dozens. Use carrier validation + display suggestions; require explicit override on validation failure; audit overrides (forensics on address-related fraud).

### Driver privacy
Location tracking is sensitive. Stream only during active route; stop tracking on clock-out; retention policy per state (some require 30d, some allow indefinite for safety).

## Webhooks the system must produce (to upstream / merchant)

- `shipment.created`, `shipment.label_purchased`, `shipment.label_voided`.
- `shipment.in_transit`, `shipment.out_for_delivery`, `shipment.delivered`.
- `shipment.exception`, `shipment.delayed`.
- `shipment.delivery_failed`, `shipment.returned`.
- `pickup.scheduled`, `pickup.completed`, `pickup.missed`.
- `claim.filed`, `claim.decided`.

## Webhooks the system must consume (from carrier)

- Carrier tracking events (per carrier API: UPS Track, FedEx Tracking, etc. — or aggregator).
- Carrier rate updates (rare; usually pull-only).
- Carrier billing reconciliation (post-shipment adjustment for dim weight, surcharges).
- Customs status (cleared / held / inspected).

## Idempotency-critical endpoints

- `POST /labels` — duplicate purchases = duplicate labels = duplicate charges.
- `POST /shipments/:id/void` — void twice = error or double-credit risk.
- `POST /pickups` — duplicate pickup requests = no-show fees.
- `POST /webhooks/carrier-tracking` — same event delivered N times.
- `POST /claims` — duplicate claim filings rejected by carrier.
