# On-demand — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `on-demand`:

**Entity / model names**: `Customer`, `Worker` (or `Driver` / `Courier` / `Provider` / `Tasker`), `Request`, `Ride`, `Trip`, `Job`, `Delivery`, `Quote`, `Match`, `Surge`, `SurgeZone`, `Vehicle`, `Verification`, `BackgroundCheck`, `Rating`, `Tip`, `Cancellation`, `Dispute`, `LocationUpdate`, `Heading`, `ETA`, `Route`, `Payout`, `Earnings`, `Acceptance`, `Deactivation`.

**Folder / route names**: `dispatch/`, `matching/`, `requests/`, `rides/`, `trips/`, `surge/`, `worker/`, `driver/`, `courier/`, `tracking/`, `payouts/`, `earnings/`, `verification/`, `disputes/`, `sos/`, `geofence/`.

**Dependencies (any language)**: `mapbox`, `google-maps`, `here-maps`, `osrm`, `valhalla`, `pubnub`, `pusher`, `socket.io`, `mqtt`, `kafka`, `postgis`, `redis-geo`, `h3-js`, `s2-geometry`, `twilio` (SMS for ETA + driver auth), `onfido`, `persona`, `checkr`, `sterling-talent`, `branch-payouts`, `tipalti`, `wise-payouts`, `stripe-connect`.

**Database schema**: tables for `requests` + `workers` + `matches` + real-time `location_updates` (high-frequency, often partitioned/timeseries) is the strongest signal. Presence of `surge_zones` + `quotes` with dynamic pricing → marketplace dispatch, not just delivery.

**Distinguishing from logistics**: on-demand is unscheduled + matched-on-request (rider opens app NOW). Logistics is planned routes + assigned in advance. If you see `Route` with pre-planned multi-stop optimization → logistics. If you see `Match` between an open request + nearest worker → on-demand.

**Distinguishing from marketplace**: marketplace sells goods between buyer + seller; on-demand sells real-time service performance. If service requires worker physically going somewhere within minutes → on-demand. If service is digital or scheduled → marketplace or saas.

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Customer` | service requester | `id, name, email, phone, default_payment_method_id, rating_avg, rating_count, marketing_consent` | created → verified → active → suspended → deleted |
| `Worker` / `Driver` / `Courier` | service performer | `id, name, email, phone, status (offline/online/on_request/on_trip), classification (employee/contractor), rating_avg, acceptance_rate, completion_rate, current_location, vehicle_id?, last_active_at` | applied → background_check → approved → active → on_trip → deactivated |
| `Vehicle` (if applicable) | worker's mode | `id, worker_id, type (sedan/suv/bike/scooter/foot), license_plate, year, make, model, insurance_id, inspection_date, capacity` | registered → inspected → active → expired → deactivated |
| `Verification` | identity / license / background | `id, worker_id, type (gov_id/license/insurance/bg_check/vehicle_inspection), provider, status, expires_at, document_ref, verified_at` | requested → in_review → approved/rejected → expired |
| `Request` | customer's open ask | `id, customer_id, type (ride/delivery/job), pickup_location, dropoff_location?, requested_at, scheduled_for?, special_requirements (wheelchair/large/etc), status` | created → matching → matched → in_progress → completed (or cancelled / failed) |
| `Quote` | priced offer | `id, request_id, base_fare, distance_fare, time_fare, surge_multiplier, service_fee, tax, total, currency, expires_at` | computed → presented → accepted → expired |
| `SurgeZone` | dynamic pricing region | `id, polygon, h3_cells[], multiplier, reason (high_demand/event/weather), starts_at, ends_at` | active → expired |
| `Match` | request ↔ worker pairing | `id, request_id, worker_id, offered_at, eta_seconds, response (accepted/rejected/timed_out), responded_at` | offered → accepted (or rejected/timeout) |
| `Trip` / `Job` / `Delivery` | active service | `id, request_id, worker_id, customer_id, started_at, completed_at, distance_km, duration_seconds, route_polyline, total_fare, status` | accepted → en_route_pickup → arrived_pickup → in_progress → en_route_dropoff → arrived_dropoff → completed |
| `LocationUpdate` | worker GPS ping | `worker_id, lat, lng, heading, speed, accuracy, timestamp, trip_id?` | append-only, retention-bounded |
| `ProofOfDelivery` (delivery) | completion evidence | `id, trip_id, type (photo/signature/code/contactless_drop), data_ref, captured_at` | captured → uploaded → verified |
| `Rating` | post-service feedback | `id, trip_id, rater_role (customer/worker), ratee_id, stars (1-5), tags[], comment?, submitted_at` | submitted → moderated (if flagged) |
| `Tip` | post-service gratuity | `id, trip_id, amount, currency, captured_at` | added → captured → paid_to_worker |
| `Cancellation` | abandoned request/trip | `id, request_id, by_role (customer/worker/system), reason, fee_charged?, occurred_at` | recorded |
| `NoShow` | counterparty didn't appear | `id, trip_id, by_role, declared_at, evidence_ref?` | submitted → reviewed → upheld/dismissed |
| `Earnings` | worker income from a trip | `id, worker_id, trip_id, base, time, distance, surge_premium, tip, bonus, deductions (fees/insurance), net, payout_cycle_id?` | accrued → ready → paid |
| `Payout` | money sent to worker | `id, worker_id, amount, currency, method (instant/bank_transfer), provider_ref, status, period_start, period_end, fee` | initiated → in_transit → completed → failed |
| `Dispute` | contested charge / event | `id, trip_id, by (customer/worker), category (overcharge/route/conduct/lost_item/refund), description, status, resolution` | opened → investigating → resolved → closed |
| `Deactivation` | worker removed from platform | `id, worker_id, reason, by_role, appeal_deadline, status (active/appealed/upheld/reversed)` | issued → appealed → upheld/reversed |
| `LostItem` | item left in vehicle / with worker | `id, trip_id, customer_id, description, status, contact_attempts[], resolution` | reported → contacted → returned/closed |
| `SOS` / `Emergency` | in-trip safety trigger | `id, trip_id, role, lat, lng, triggered_at, response_status` | triggered → dispatched → resolved |

## Status state machines

**Request:**
```
created → matching → matched → accepted_by_worker → en_route_pickup → arrived_pickup
            ↓                                            ↓                    ↓
         no_match (timeout)                         cancelled (customer)    arrived
                                                                              ↓
                                              in_progress → en_route_dropoff → arrived_dropoff → completed
                                                    ↓                              ↓
                                              cancelled (mid-trip)            completed
```

**Worker:**
```
applied → onboarding (gov_id + license + bg_check + vehicle_inspection) → approved
                                ↓                                           ↓
                            rejected                                    active
                                                                           ↓
                                                                    online ↔ offline
                                                                           ↓
                                                                       on_request → on_trip → online
                                                                           ↓
                                                                    deactivated → appealed → reinstated/upheld
```

**Match:**
```
offered (to worker) → accepted (worker)
                   ↓
                rejected (worker) → re-match (next worker)
                   ↓
                timeout → re-match (next worker, accept-rate hit)
```

**Quote:**
```
computed → presented (to customer) → accepted (becomes Request commitment)
                                  ↓
                              expired (TTL) → recompute on tap
```

**Surge zone:**
```
inactive → triggered (demand > threshold) → active (multiplier applied) → cooling → expired
```

**Payout:**
```
accruing → period_close → ready → initiated → in_transit → completed
                                       ↓                       ↓
                                    failed                 reversed
```

**Dispute:**
```
opened → investigating (auto-triage + human if needed) → resolved (refund / no_action / partial) → closed
```

## Vocabulary distinctions (don't conflate)

- **Request** vs **Quote** vs **Trip** — Request: "I want a ride from A to B." Quote: "Here's the price + ETA." Trip: the executed service. Request might never become a Trip (no match, customer cancels, expired quote).
- **Match** vs **Assignment** vs **Dispatch** — Match: pairing logic decision. Offer: sent to worker for acceptance. Assignment: worker accepted. Dispatch: the orchestration system that does matching + offering.
- **Acceptance rate** vs **Completion rate** vs **Cancellation rate** — Acceptance: % of offers worker accepted. Completion: % of accepted trips actually completed. Cancellation: % of trips cancelled (by customer or worker, often tracked separately).
- **Surge** vs **Dynamic pricing** vs **Multiplier** — Surge: spike-driven price increase tied to a zone + time. Dynamic pricing: continuous per-trip pricing (ML-driven, harder to explain). Multiplier: the math applied (1.5x, 2.0x). Display + disclose explicitly.
- **ETA** vs **ETD** vs **time-to-pickup** — ETA: estimated time of arrival (worker → customer for pickup, worker → destination for trip). ETD: estimated time of departure. time-to-pickup: ETA at pickup point (most user-facing).
- **Cancellation fee** vs **No-show fee** vs **Cleaning fee** — Cancellation: customer cancels after threshold. No-show: customer didn't appear at pickup after worker arrived + waited. Cleaning: damage / mess after trip.
- **Worker** vs **Employee** vs **Contractor** vs **Independent contractor** — Worker is the platform-neutral term. Classification is jurisdiction-specific (employee = wages + benefits; contractor = 1099 / IR35 / self-employed). Misclassification = lawsuits + back taxes.
- **Trip insurance** vs **Worker's commercial insurance** vs **Personal auto** — Personal auto often excludes commercial use. Platform should provide trip-period commercial insurance (Period 1: app on, no request; Period 2: matched + en-route; Period 3: customer in vehicle). Different coverage tiers per period.
- **Deactivation** vs **Suspension** vs **Ban** — Deactivation: removed from platform with appeal path. Suspension: temporary deactivation. Ban: permanent without appeal (rare; legally risky).
- **Tip** vs **Gratuity** vs **Bonus** — Tip from customer. Bonus from platform (incentive payment, e.g., complete 25 rides this weekend = $50). Both go to worker but accounted separately for tax.
- **Payout** vs **Earnings** vs **Net** — Earnings: gross compensation per trip. Payout: money actually transferred (after platform fees, deductions, credits). Net: take-home after taxes (worker calculates).
- **Geofence** vs **Zone** vs **H3 cell** — Geofence: arbitrary polygon ("airport"). Zone: business area (downtown, suburb). H3 cell: hexagonal grid index for fast spatial lookup (Uber's H3 library).

## Multi-tenancy variants

- **Single-platform on-demand**: one operator running marketplace (Uber, DoorDash, TaskRabbit). Tenant boundary = none (or by region/city for ops, not for data isolation).
- **White-label dispatch** (Bringg, Onfleet): SaaS for restaurants / retailers to run their own delivery. `tenant_id` per merchant.
- **Aggregator** (Trafi, Citymapper-style): multi-platform integration; user gets quotes across providers. Each provider is a peer integration, not a tenant.
- **Hybrid (own + 3rd-party fleet)**: platform may dispatch to in-house workers OR forward to 3rd-party providers (Uber forwards some rides to taxi cooperatives). Routing decision per request.

## Geographic + spatial concepts

- **H3 / S2 / Geohash** — hexagonal/square grid systems for spatial indexing. Used for: surge zones, supply tracking, demand prediction, fast nearest-neighbor.
- **Pickup zone** — physical area around pickup point where worker meets customer. Critical at airports, stadiums, malls (designated pickup spots, not curb).
- **Dead zone** — area with no supply (rural, off-hour). Quote may decline matching; show estimated wait or "no service."
- **Service area** — official platform coverage (city + commuter ring). Outside = no service.
- **Restricted zone** — areas blocked (military bases, certain stadiums during events, country borders).

## Time-of-trip insurance periods (US standard)

- **Period 0**: app off → personal coverage only.
- **Period 1**: app on, no request → "contingent" liability often required by state.
- **Period 2**: matched, en-route to pickup → commercial liability.
- **Period 3**: customer in vehicle → full commercial coverage including comprehensive + collision.

These map to status state machine; insurance policy must align with platform state.
