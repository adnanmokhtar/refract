# Logistics — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `logistics` (shipping, delivery, fulfillment):

**Entity / model names**: `Shipment`, `Parcel`, `Package`, `Carrier`, `Service`, `Rate`, `Label`, `Tracking`, `TrackingEvent`, `Delivery`, `Driver`, `Route`, `Stop`, `Vehicle`, `Hub`, `Manifest`, `Pickup`, `Customs`, `Hawb`, `Mawb`, `Bol` (Bill of Lading).

**Folder / route names**: `shipments/`, `tracking/`, `rates/`, `labels/`, `pickups/`, `delivery/`, `routes/`, `manifests/`, `/track/[number]`, `/rates/quote`, `/label/print`, `/api/v1/webhooks/carrier`.

**Dependencies**: `shipengine`, `easypost`, `shippo`, `aftership`, `parcel.io`, `route4me`, `mapbox-directions`, `google-maps-routing`, `here-maps`, `dhl-api`, `fedex-api`, `ups-api`, `usps-api`, `dpd-api`, `royal-mail`, `aramex`, `aramex-api`, `pld` (paperless trade), `narvar`, `convey`, `project44`.

**Database schema**: tables for `shipments` + `tracking_events` + `addresses` (origin + destination per shipment) + `carriers` is the strongest signal. Presence of `tracking_number` + `service_code` columns near-conclusive.

**Distinguishing variants**:
- **Carrier integration** (multi-carrier shipping API like ShipEngine) — focus on rates/labels/tracking aggregation.
- **Last-mile delivery** (DoorDash, Postmates patterns) — Driver, Route, real-time location.
- **3PL / warehouse** — Pick, Pack, Receipt, Inventory.
- **Freight / LTL** — Bill of Lading, Pallet, Class, Density.
- **Cross-border** — Customs, HS code, Duty, Brokerage.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Shipment` | the logical movement | `id, reference (your_order_id), origin_address_id, destination_address_id, status, carrier_id, service_code, declared_value, currency, weight_total, parcel_count, created_at, ship_at, delivered_at` | created → label_purchased → in_transit → out_for_delivery → delivered (or returned/lost/damaged) |
| `Parcel` | physical box (1 shipment can have N) | `shipment_id, sequence, weight, length, width, height, dim_unit, weight_unit, packaging_type, contents_description, declared_value` | follows shipment |
| `Address` | origin or destination | `name, company, street1, street2, city, state, postal, country, phone, email, residential_or_commercial, validated, geocoded, lat, lng` | normalized at create; carrier-specific normalization may differ |
| `Carrier` | shipping company | `id, code (ups/fedex/dhl/usps/etc), name, supported_services[], supported_countries[], credentials_id` | active → suspended (account issue) |
| `Service` | speed/level offered by carrier | `carrier_id, service_code, name (overnight/2day/ground), domestic, international, dimensions_max, weight_max, transit_days_estimate, requires_appointment` | persistent |
| `Rate` | price quote | `shipment_id, carrier_id, service_code, amount, currency, transit_days, delivery_date_estimate, fees_breakdown, expires_at` | quoted → selected → purchased / expired |
| `Label` | printable shipping doc | `shipment_id, parcel_id, carrier_id, tracking_number, label_url (PDF/PNG/ZPL), label_format, voided_at` | created → printed → applied → in_use → voided |
| `TrackingEvent` | scan or status update | `shipment_id, tracking_number, event_code, event_description, status_category, location, timestamp, source (carrier_webhook / poll / manual)` | append-only |
| `Pickup` | scheduled carrier pickup | `id, carrier_id, address_id, requested_window_start, requested_window_end, confirmation_number, parcels_count, status` | requested → confirmed → completed / missed / cancelled |
| `Delivery` | last-mile delivery (own fleet) | `id, shipment_id, route_id, driver_id, vehicle_id, attempt_number, status, delivered_at, proof_type (signature/photo/pin), proof_url, refused_reason` | assigned → en_route → arrived → delivered / failed |
| `Driver` | delivery person (own fleet) | `id, name, phone, license_number, license_expiry, hours_log[], vehicle_assigned_id, status (off_duty/on_duty/driving/break), location_last_known` | active → suspended → terminated |
| `Vehicle` | truck/van/bike | `id, license_plate, type (van/truck/bike/scooter/walk), capacity_cuft, capacity_kg, fuel_type, refrigerated, last_maintenance_at, status` | active → maintenance → retired |
| `Route` | sequence of stops for a driver | `id, driver_id, vehicle_id, hub_id, planned_start_at, planned_end_at, stops[], optimized, miles, status` | planned → active → completed |
| `Stop` | one stop on a route | `route_id, sequence, address_id, eta, ata, type (pickup/delivery), shipment_ids[], time_window_start, time_window_end, service_time_minutes, status` | pending → arrived → completed / skipped / failed |
| `Hub` / `Facility` | warehouse/depot | `id, name, address_id, type (origin/sortation/regional/last_mile), capabilities, hours, dock_count` | active → closed |
| `Manifest` | end-of-day handoff doc | `id, carrier_id, hub_id, shipments[], total_weight, total_count, tendered_at, signed_by` | open → closed → tendered |
| `Customs Declaration` | for international | `shipment_id, contents_type (merchandise/gift/sample/return), contents_description, hs_codes[], country_of_origin, ein_number, eori_number, incoterms (DDP/DDU/DAP), customs_value` | drafted → submitted → cleared / held |
| `Insurance Claim` | loss/damage claim | `shipment_id, claim_type, declared_value, claim_amount, evidence[], status, submitted_at, decided_at, decision` | filed → investigating → approved / denied / paid |

## Status state machines

**Shipment:**
```
created → label_purchased → picked_up → in_transit → out_for_delivery → delivered
                                ↓             ↓                    ↓
                          held_at_hub    exception        delivery_failed → retry → delivered
                                              ↓                    ↓
                                          returned_to_sender  refused → returned_to_sender
                                                                     ↓
                                                                 lost / damaged → claim
```

**Tracking event categories** (normalized across carriers):
- `info_received` — label created, carrier informed.
- `in_transit` — accepted, in-network, on-vehicle.
- `out_for_delivery` — on final-mile vehicle.
- `delivered` — confirmed delivery.
- `attempted_delivery` — driver tried, couldn't complete.
- `available_for_pickup` — at pickup point.
- `exception` — anomaly (weather, address issue, customs hold).
- `expired` — tracking ages out (carrier-specific).
- `failure` — explicit failure (lost, damaged-beyond-recovery).
- `unknown` — carrier silence > expected interval.

**Route (last-mile own fleet):**
```
planned → assigned_to_driver → driver_started → in_progress → completed
                                                   ↓
                                                 paused (break / fuel)
                                                   ↓
                                                 truncated (early end)
```

## Vocabulary distinctions (don't conflate)

- **Shipment** vs **Parcel** vs **Package** — Shipment = logical (one purchase, one BOL); Parcel = physical box; Package = colloquial. One Shipment can be N Parcels.
- **Carrier** vs **Service** — Carrier = company (UPS); Service = level (UPS Next Day Air). Service code unique per carrier.
- **Rate** vs **Quote** vs **Charge** — Rate = pre-purchase price estimate; Quote = customer-facing rate (may include markup); Charge = actual amount billed by carrier (may differ due to dim weight, surcharges).
- **Tracking number** vs **Reference** vs **Master tracking** — Tracking# = per-parcel; Reference = your internal order ID; Master = group of related (multi-piece shipment).
- **DDP** vs **DDU** vs **DAP** vs **EXW** vs **CIF** vs **FOB** — Incoterms (international); allocate who pays/risks what at each transit stage.
- **Dim weight** vs **Actual weight** — carriers bill the greater; large-light packages "dim out" expensive.
- **HAWB** vs **MAWB** — House Air Waybill (forwarder-issued per shipment) vs Master Air Waybill (airline-issued, consolidated).
- **Last mile** vs **Final mile** vs **Last meter** — synonymous; the most expensive, hardest leg.
- **POD** (Proof of Delivery) — signature, photo, PIN, geo-stamp.
- **Returned to sender** vs **RTS** vs **RTO** — same; package back to origin.
- **OS&D** (Over, Short, Damaged) — receiving discrepancies in freight.
- **HOS** (Hours of Service) — DOT regulation; truck driver duty hours.
- **ELD** (Electronic Logging Device) — DOT-mandated for HOS recording.

## Multi-tenancy variants

- **Single-shipper SaaS**: one company shipping its own packages. No tenant boundary internal.
- **Multi-shipper platform** (ShipStation, ShipEngine model): many shippers; strict tenant isolation; shared carrier accounts (with rate negotiation per tenant).
- **Carrier marketplace** (multi-carrier API): platform aggregates, shippers shop. Tenant = shipper account.
- **3PL platform**: 3PL operator + multiple merchant clients. Tenant = merchant; warehouse staff cross-tenant.
- **Last-mile aggregator** (Onfleet, Bringg model): platform serves many shippers; drivers may serve multiple shippers (or single).
- **TMS** (Transportation Management System): mid-large shipper logistics control plane; tenant = business unit.
