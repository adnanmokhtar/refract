# Logistics — stakeholders

Logistics has dense external dependencies — carriers, customs, recipients, regulators — and ops-heavy internal roles. Build for the dispatcher as much as for the driver.

## Shipper (the merchant / business sending packages)

The paying customer. Often integrating logistics into their own platform.

**Workflows:**
- Connect carrier accounts (provide credentials).
- Negotiate carrier rates (or use platform-negotiated).
- Push order data into shipping system (API, ecommerce platform sync, manual).
- Rate-shop per shipment.
- Print labels; pack; tender to carriers.
- Monitor in-transit.
- Handle exceptions (lost, damaged, delayed).
- Reconcile carrier billing.
- File claims when needed.

**Pain points:**
- Carrier integrations break (API changes, credential rotations).
- Rate shopping speed at checkout (consumer waiting).
- Address quality (bad addresses = failed deliveries = chargebacks).
- Surprise surcharges weeks later (dim weight, residential, fuel).
- International complexity (customs, DDP/DDU, restricted commodities).
- Returns logistics (separate flow, often manual).
- Carrier service level slipping (peak season, weather).

**KPIs:**
- Cost per shipment.
- On-time delivery rate.
- Damage / loss rate.
- Cart-abandonment-due-to-shipping.
- Return rate.

**Permissions:**
- Carrier account config.
- Rate cards.
- Shipment CRUD.
- Reports.
- Webhook config.

## Recipient (the consumer)

The party expecting a package. Has zero control, full anxiety.

**Workflows:**
- Receive tracking notification (email/SMS).
- Check tracking page.
- Receive delivery (or notification of attempt).
- File issue if not received / damaged.
- Return if needed.

**Pain points:**
- "Where's my package?" — tracking unclear.
- Wide ETA windows (8am-8pm meaningless).
- Missed delivery — no easy reschedule.
- Apartment/business hour mismatch.
- Photo POD shows wrong house.
- Delivered-but-missing (porch piracy).
- Damage on arrival.

**KPIs (recipient-side):**
- WISMO (Where Is My Order) inquiry rate.
- Delivery success rate.
- Reattempt acceptance.
- Delivery satisfaction.

## Driver (last-mile, own fleet)

The face of the brand to the recipient. Often gig or low-wage; high turnover.

**Workflows:**
- Arrive at hub.
- Pre-trip vehicle inspection (DVIR).
- Load vehicle.
- Drive route (turn-by-turn).
- For each stop: navigate + park + carry + deliver + capture POD.
- Failed delivery: document reason; redirect or retry.
- Return to hub; post-trip DVIR; turn in undelivered.

**Pain points:**
- Address accuracy (bad address = wasted stop).
- Apartment building access (gate codes, buzzer numbers).
- Heavy package without ramp / dolly.
- Time pressure (140 stops/day).
- App crashes / GPS losing signal.
- Signature capture friction.
- Customer complaints when not their fault.
- Pay structure (per-stop vs hourly vs piece-rate).

**KPIs:**
- Stops per hour.
- On-time delivery %.
- POD compliance.
- Customer complaint rate.
- Damage rate.

**Permissions:**
- Own routes only (or routes assigned).
- POD capture.
- Status updates.
- Limited recipient PII (name, phone, instructions).

## Driver (long-haul / freight)

CDL-licensed; over-the-road; multi-day trips; HOS-regulated.

**Workflows:**
- Pre-trip planning (route, fuel, rest stops).
- DVIR pre-trip.
- HOS log management.
- Pickups + drops at terminals.
- Customs at border (international).
- Delivery (often appointment-based at receiving dock).
- Post-trip DVIR + paperwork.

**Pain points:**
- HOS clock pressure.
- Detention time (waiting at dock without pay).
- Parking shortages at truck stops.
- ELD compliance.
- Spouse + family time.
- Health (sedentary + diet).

**KPIs:**
- Miles per period.
- On-time delivery.
- Fuel efficiency.
- Safety score.

## Dispatcher

The traffic controller. Coordinates routes + drivers + exceptions.

**Workflows:**
- Plan routes (manual or auto).
- Assign drivers to routes.
- Monitor live execution (map view).
- Handle exceptions (vehicle breakdown, late deliveries).
- Communicate with drivers (chat / call).
- Coordinate with customer service for inquiries.
- End-of-day reconciliation.

**Pain points:**
- Last-minute changes cascade (one stop reassign = re-optimize).
- Driver unavailability surprises.
- Real-time visibility lag.
- Multi-shipper coordination.
- Customer escalations.

**KPIs:**
- Route completion %.
- Stops per route.
- Reassignment rate.
- Customer satisfaction.

**Permissions:**
- Route planning + reassign.
- Driver chat.
- Live map.
- Exception handling.

## Warehouse / fulfillment ops

Pick-pack-ship operations.

**Workflows:**
- Receive inventory + put away.
- Order pick (per pick list / batch / wave).
- Pack (correct box size, fragile handling, packing slip).
- Generate shipping label (auto from order data).
- Tender to carrier (manifest barcode scan).
- Inventory reconciliation.
- Returns processing.

**Pain points:**
- Pick errors (wrong item, wrong qty).
- Pack errors (wrong box, missing label).
- Address quality (bad address = redo).
- Equipment downtime (printer, scanner).
- Peak season ramp.

**KPIs:**
- Orders shipped per hour.
- Pick accuracy.
- Same-day fulfillment %.
- Damage rate.

## Customer service

Inbound inquiries about orders + shipments.

**Workflows:**
- Respond to "where's my order" tickets.
- Look up tracking + history.
- Coordinate with carrier on exceptions.
- Issue refunds / replacements when shipment lost / damaged.
- File carrier claims on shipper's behalf.
- Address corrections mid-transit.

**Pain points:**
- Multiple carrier portals to navigate.
- Slow carrier response on claims.
- Lacking visibility into in-transit nuance.
- Empowering reps to resolve without escalation.

**KPIs:**
- First-contact resolution.
- Ticket volume per shipment count.
- Customer satisfaction.

**Permissions:**
- Order + shipment lookup.
- Status update / address correction.
- Refund up to limit.
- Claim filing.

## Carrier (UPS, FedEx, USPS, DHL, regional)

Service provider. API-mediated relationship.

**Touchpoints:**
- Rates API.
- Label purchase API (with idempotency).
- Tracking events (webhook + polling).
- Pickup scheduling API.
- Service map / zone data.
- Manifest acceptance.
- Adjustments (post-shipment billing corrections).
- Claims portal.
- Account management.

**Pain to engineer around:**
- API outages (status page monitoring + failover).
- Rate-limit throttling.
- Schema changes (versioned APIs needed).
- Webhook delivery delays (polling fallback).
- Adjustments arriving weeks later (reconciliation pipeline).

## Carrier account manager

Human contact at carrier for negotiation + escalation.

**Touchpoints:**
- Rate negotiation annually.
- Issue escalation (lost claim ignored, accessorial dispute).
- Service introductions.
- Account performance review.

## Customs broker (international)

Licensed agent that clears goods through customs.

**Touchpoints:**
- Commercial invoice + packing list submission.
- HS classification confirmation.
- Duty + tax payment on shipper's behalf.
- Held-at-customs resolution.
- Importer of Record arrangements.
- Bond posting for high-value entries.

## Receiver / recipient business (B2B)

Businesses that receive freight; often warehouse or store with dock.

**Workflows:**
- Receive ASN (advance shipping notice) from sender.
- Schedule appointment for delivery.
- Receive at dock; sign BOL; mark exceptions (OS&D).
- Stock product.

**Pain:**
- Appointment availability (limited dock slots).
- Mismatched ASN vs actual.
- Damage discovery post-receipt.

## Insurance broker / carrier

For cargo insurance + claims.

**Touchpoints:**
- Coverage configuration per shipment value.
- Claim filing + evidence submission.
- Investigation + decision.
- Payment.

## Regulator

- **DOT / FMCSA** — driver hours, vehicle, hazmat, audits.
- **State PUC / DOT** — intrastate.
- **Customs (CBP, EU customs)** — imports/exports.
- **Privacy authorities** (FTC, CA AG, EU DPAs).
- **OSHA** — workplace safety.
- **FAA** (for drone-delivery operators).

## Insurance underwriter

Reviews fleet + ops; sets premium + coverage.

## Stakeholder-driven feature priorities

| If complaint is from... | Then priority is... |
|---|---|
| Recipients flooding WISMO | Better tracking page + proactive notifications |
| Drivers complaining about app | Stop-detail clarity + offline mode + POD speed |
| Dispatchers re-optimizing constantly | Auto-route engine + exception flagging |
| Shippers getting surprise rebills | Dim-weight preview + adjustment reconciliation |
| Warehouse pick errors | Barcode scan validation + pick list redesign |
| Customer service drowning | Self-service rescheduling + claim portal |
| Carrier reps escalating issues | Better adjustment + claim management UI |

## Anti-pattern: "ignore the regulator until they show up"

DOT compliance, customs filings, sanctions screening, hazmat — these are not optional and not gracefully retrofittable. Build at v1 with the boring requirements (HOS hard limits, sanctioned-party screening, customs forms, BIPA consent for biometric POD). Otherwise the first audit cycle is existential.
