# Logistics — feature checklist

The 80%-of-projects-need-this list. Logistics v1s commonly fail when scaled to volume — the gaps below are operational landmines, not feature gaps.

## Shipper-facing (merchant / business user)

### Setup
- [ ] Carrier account connection (UPS, FedEx, USPS, DHL, regional + international).
- [ ] Carrier credentials secure storage (per-tenant, encrypted at rest, never logged).
- [ ] Negotiated rate tier import (CSV from carrier or sync via API).
- [ ] Default origin address (warehouse / fulfillment center).
- [ ] Default packaging (templates: small box, medium, envelope).
- [ ] Service mapping (e.g., "fast" → UPS Next Day or FedEx Priority).
- [ ] Branded tracking page (logo, colors, custom domain).
- [ ] Webhook endpoints configuration with secret.
- [ ] User + role management.

### Shipment creation
- [ ] Single-shipment manual entry.
- [ ] Bulk creation via CSV upload.
- [ ] Order import from ecommerce platform (Shopify, WooCommerce, Magento).
- [ ] API for shipment creation.
- [ ] Multi-piece shipment support.
- [ ] Address book.
- [ ] Address validation with correction suggestions.
- [ ] Address normalization preview per carrier.
- [ ] International form generation (CN22, commercial invoice).
- [ ] HS code lookup.
- [ ] Hazmat declaration.

### Rate shopping
- [ ] Real-time rate quote across all enabled carriers.
- [ ] Filter: cheapest, fastest, by-carrier, by-service-level.
- [ ] Surcharge breakdown visible.
- [ ] Estimated transit time + delivery date.
- [ ] Rate-card application (markup / margin / negotiated rates).
- [ ] Saved rate preferences (auto-pick rule).
- [ ] Rule engine: "to ZIP X, use carrier Y" / "package over Z lbs use freight".

### Label printing
- [ ] PDF preview before purchase.
- [ ] Print to standard printer (8.5×11) or thermal (4×6 ZPL).
- [ ] Browser-extension or local print bridge for thermal.
- [ ] Batch print (50+ labels at once).
- [ ] Reprint label (if lost; use carrier API NOT new purchase).
- [ ] Void label with refund tracking.
- [ ] Customs documents auto-attach for international.

### Tracking
- [ ] Internal tracking dashboard (status of all active shipments).
- [ ] Search by tracking #, reference #, recipient name, address.
- [ ] Filter: status, carrier, date range, exception flag.
- [ ] Map view of in-transit shipments.
- [ ] Drill-down: full event timeline + raw carrier events.
- [ ] Customer-facing tracking page (no login, by tracking#).
- [ ] Branded tracking emails/SMS.
- [ ] Predictive ETA narrowing carrier window.

### Manifests + EOD
- [ ] Daily manifest per carrier auto-generated.
- [ ] Print barcode for driver scan.
- [ ] EOD reconciliation report.
- [ ] Late shipments holdover to next day.

### Returns
- [ ] Outbound + return label paired.
- [ ] Pre-paid return label (in box) vs on-demand (customer requests).
- [ ] Return shipment tracking distinct.
- [ ] RMA workflow integration.

### Reporting
- [ ] Spend per carrier per period.
- [ ] On-time delivery rate per carrier per lane.
- [ ] Damage / loss rate.
- [ ] Cost per shipment trend.
- [ ] Surcharge analysis (where dim weight is hitting).
- [ ] Saving opportunities (alternate carrier suggestions).

## Driver-facing (own fleet last-mile)

- [ ] Mobile app (Android + iOS).
- [ ] Login + duty status (off / on / driving / break).
- [ ] Route view: list + map + turn-by-turn.
- [ ] Stop detail (address, recipient, special instructions, photo of delivery zone if last visit).
- [ ] Navigation handoff (Google / Apple / Waze).
- [ ] Arrived / departed buttons.
- [ ] POD capture (photo + signature + PIN + GPS auto-stamp).
- [ ] Failed delivery reason capture.
- [ ] Reschedule with customer.
- [ ] Damage / refusal reporting.
- [ ] Real-time route updates (push from dispatch).
- [ ] Vehicle inspection checklist (DVIR — pre-trip + post-trip).
- [ ] Hours-of-service tracking (HOS / ELD compliance).
- [ ] Break + fuel + lunch logging.
- [ ] Earnings visibility (per stop / per hour, depending on model).
- [ ] In-app messaging with dispatch.
- [ ] Offline mode (deliveries continue without signal; sync later).

## Dispatch / ops-facing (own fleet)

- [ ] Live map of all drivers + vehicles.
- [ ] Route assignment + reassignment.
- [ ] Stop reassignment between drivers.
- [ ] Manual route building (drag stops to driver).
- [ ] Auto-routing (VRP solver).
- [ ] Time-window respect.
- [ ] Capacity check (cuft / kg / piece).
- [ ] Driver chat / call.
- [ ] ETAs to customer with re-estimation.
- [ ] Disruption handling (vehicle breakdown → re-route stops).
- [ ] Geofence on hub (auto check-in/out).

## Recipient-facing (consumer)

- [ ] Tracking page accessible by tracking# (no auth).
- [ ] Email + SMS notifications opt-in.
- [ ] Delivery preferences (front door / leave with neighbor / require signature / hold at location).
- [ ] Reschedule delivery (carrier-supported services).
- [ ] Address correction (carrier-supported).
- [ ] Photo POD viewable post-delivery.
- [ ] Issue report (didn't receive / damaged).
- [ ] Recipient identity verification for high-value (PIN delivery).

## Compliance + safety

- [ ] DOT / driver hours tracking + alerts (US: HOS rule).
- [ ] Driver license + medical card expiration tracking.
- [ ] Vehicle inspection (DVIR) records.
- [ ] Hazmat training documentation.
- [ ] Customs records retention (5+ years).
- [ ] Customer data privacy (driver location, recipient data).
- [ ] PCI scope avoidance (don't touch payment data unless necessary).
- [ ] Insurance certificates per vehicle + per driver.
- [ ] Background check tracking.

## Integrations

- [ ] Carrier APIs (UPS, FedEx, USPS, DHL, plus regional).
- [ ] Multi-carrier aggregator alternative (ShipEngine, EasyPost) as backup.
- [ ] WMS / ERP (NetSuite, SAP, Acumatica).
- [ ] Ecommerce platform (Shopify, BigCommerce, Magento, custom).
- [ ] Address validation provider (Loqate, SmartyStreets).
- [ ] Mapping (Mapbox, Google, HERE).
- [ ] Customs broker / DDP (Zonos, Easyship).
- [ ] ELD provider (Samsara, Motive, Geotab).
- [ ] Insurance provider (Shipsurance, U-PIC, InsureShield).

## Things v1s commonly miss

- **Address normalized differently across carriers.** Same input passes UPS validation, fails USPS — label rejects on print. Track normalized result per carrier; surface mismatches.
- **Tracking event dedup absent.** Carrier sends same event 3 times → notification storm to customer. Dedupe on (tracking#, event_code, event_timestamp).
- **Out-of-order tracking events.** Hub upload batch → "delivered" before "out for delivery". Re-derive status from event log, not last received.
- **Photo POD without face blur.** Privacy issue + GDPR. Auto-blur or restrict POD storage to recipient/shipper only.
- **Driver location stored at 1 Hz indefinitely.** Storage explosion + privacy. 5-min interval during route + delete after retention period.
- **Label voided but not refunded.** Some carriers void window short; if missed, label is paid-for permanently. Monitor void window + auto-refund where eligible.
- **No webhook signature verification.** Anyone can POST fake tracking events; fraud potential. HMAC verification mandatory.
- **Dimension capture optional.** Customer ships oversize without declaration → carrier rebills weeks later → margin gone. Mandatory dims on creation.
- **Dim weight not preview-calculated.** Customer surprised by carrier rebill. Show dim weight + actual weight + billing weight at quote time.
- **Saturday/Sunday transit assumed.** Most carriers don't run weekends; ETA wrong by 2 days. Calendar-aware transit calc.
- **Holiday calendar absent.** Christmas Eve, July 4, regional holidays affect transit; ETAs wrong.
- **Service availability not zone-checked.** "Next Day Air" purchased to remote area not served → carrier downgrades; customer expectations broken.
- **International shipments without HS codes.** Customs hold; surprise duties; customer angry. Mandatory HS for international.
- **DDP not collected.** Customer pays duty at door; refuses; RTS. Offer DDP collection at checkout for consumer-friendly experience.
- **No alternate carrier for outage.** UPS API down for 6 hours; ops paralyzed. Failover routing.
- **Carrier rebill / adjustment not tracked.** Carrier bills $5 more weeks later; reconciliation gaps; financial misalignment. Match adjustments back to shipments.
- **Lost package SLA undefined.** No event for X days; customer calls; ops scramble. Auto-flag at +5d (domestic) +14d (intl) without scan.
- **Manifest not closed.** Carrier shows shipments not received; rebills if late. Auto-close + manifest reconciliation.
- **Driver app login persisting indefinitely.** Driver leaves company; can still access route data. SSO + immediate revocation.
- **Vehicle assigned to driver without DVIR.** DOT violation if OOSD truck driven. Block route start until DVIR.
- **HOS warnings missed.** Driver fatigued; accident; lawsuit. Hard limits on HOS in app.

## Things often over-built in v1 (defer until validated)

- ML route optimizer in-house (use OR-Tools or Routific or Onfleet for v1).
- Custom mapping (use Mapbox/Google).
- Drone delivery integration (regulatory + scale isn't there).
- Lockers + parcel-shop network (partner with PUDO networks like UPS Access Point).
- Hazmat for all classes (start with Limited Quantity; add others on demand).
- Multi-language driver app for all locales (start English + 1 other based on workforce).
- Real-time crowdsourcing (Uber-for-deliveries) — operational complexity huge.
- Carbon-offset selection at checkout (P3+ for most).
- Cold-chain monitoring (only if shipping perishables).
