# Booking — domain glossary

## Detection signals

If 3+ of these are present in the codebase, classify as `booking`:

**Entity / model names**: `Booking`, `Reservation`, `Appointment`, `Slot`, `TimeSlot`, `Availability`, `Schedule`, `WorkingHours`, `Calendar`, `Provider`, `Resource`, `Staff`, `Service`, `Treatment`, `Class`, `Session`, `Customer`, `Cancellation`, `Reschedule`, `NoShow`, `Reminder`, `WaitList`, `BlackoutPeriod`, `Recurrence`.

**Folder / route names**: `bookings/`, `appointments/`, `reservations/`, `availability/`, `calendar/`, `providers/`, `services/`, `/book`, `/book/[provider]/[service]`, `/availability`, `/cancel/[token]`.

**Dependencies**: `rrule.js` (recurring rules), `luxon` / `date-fns-tz` / `dayjs-timezone`, `bigcalendar`, `fullcalendar`, `ical-generator`, `node-ical`, `cronstrue`, `simply-book`, `cal.com`, `google-calendar-api`, `microsoft-graph` (Outlook), `twilio` (SMS reminders), `nylas`.

**Database schema**: tables for `bookings` + `availability` + `providers/staff` + `services` is the strongest signal. Presence of `slot_start_at` + `slot_end_at` + `resource_id` is very specific.

**Distinguishing from event-ticketing**: ticketing = inventory of identical seats, no service-provider matching, no reschedule typically. Booking = matches a customer to a provider/resource for a duration.

**Distinguishing from on-demand (Uber-like)**: on-demand = "I want it now, dispatch closest." Booking = "I want it Tuesday at 3pm with this person." On-demand has live driver tracking; booking has slot reservation.

**Sub-domains** (worth flagging in code):
- Salon/spa
- Healthcare/medical
- Restaurant
- Fitness/gym/yoga (class booking + memberships)
- Professional services (legal, financial)
- Co-working / desk
- Equipment rental
- Hotels (different enough — see lodging-specific concerns)

## Core entities

| Entity | Owns | Key fields | Lifecycle |
|---|---|---|---|
| `Provider` / `Staff` / `Resource` | the bookable thing | `id, name, type (person/room/equipment), tenant_id, time_zone, working_hours, services_offered[], capacity (1 for person, N for class)` | active → inactive |
| `Service` | what's being booked | `id, name, duration_minutes, buffer_before, buffer_after, price, currency, requires_resource_type, capacity, deposit_required` | active → inactive |
| `WorkingHours` | provider's normal availability | `provider_id, day_of_week, start_time, end_time, time_zone` | per-day rules |
| `BlackoutPeriod` | exception (vacation, sick) | `provider_id, starts_at, ends_at, reason` | absolute time range |
| `Slot` (computed, not always stored) | a bookable interval | `provider_id, service_id, starts_at, ends_at, capacity_remaining` | derived from WorkingHours - Bookings - Blackouts |
| `Booking` / `Reservation` / `Appointment` | confirmed reservation | `id, customer_id, provider_id, service_id, starts_at, ends_at, status, time_zone_at_booking, price, deposit_paid, source (web/admin/walk-in), confirmation_code, notes` | tentative → confirmed → arrived → completed (or cancelled / no_show / rescheduled) |
| `RecurrenceRule` | repeating booking | `booking_id, rrule (RFC 5545), exceptions[], end_date` | series with exceptions |
| `Cancellation` | voided booking | `booking_id, cancelled_by (customer/provider/system), cancelled_at, reason, fee_charged, refund_status` | logged event |
| `Reschedule` | moved booking | `original_booking_id, new_booking_id, reason, requested_by` | logged event |
| `NoShow` | customer didn't arrive | `booking_id, marked_at, fee_charged, refund_blocked` | flagged on booking |
| `Reminder` | scheduled notification | `booking_id, channel (email/sms/push), send_at, sent_at, status` | scheduled → sent (or failed) |
| `WaitList` entry | when slot full | `id, customer_id, service_id, provider_id?, preferred_window, position, notify_when_available` | waiting → offered → claimed (or expired) |
| `Customer` / `Client` / `Patient` | who books | `id, name, email, phone, dob?, prefs, time_zone, allergies?/notes` | active |
| `SoftHold` | temporary slot block during checkout | `slot_ref, customer_session, expires_at` (e.g. 5-15 min) | held → released (TTL) → claimed (booking confirmed) |
| `CancellationPolicy` | per service/tenant | `min_notice_hours, fee_percent, fee_minimum, no_show_fee, late_cancel_fee, deposit_forfeit` | versioned |
| `Class` / `GroupSession` | booking with N attendees | `id, service_id, provider_id, starts_at, capacity, attendees[]` | scheduled → in_progress → completed |
| `Membership` / `Package` | pre-paid booking credits | `customer_id, plan_id, credits_remaining, expires_at, auto_renew` | active → cancelled / expired |
| `Calendar` (external) | provider's Google/Outlook cal | `provider_id, provider (google/outlook/ical), credentials, last_sync_at` | linked → unlinked |

## Status state machines

**Booking:**
```
tentative (soft-hold) → confirmed → reminded → arrived → completed
       ↓                    ↓             ↓          ↓
   expired_hold       cancelled    no_show   refunded (post-completion edge)
                          ↓
                     rescheduled (closes this; new booking opens)
```

**Soft hold:**
```
created (e.g. at "select slot") → 5-15 min TTL → expired
                                      ↓
                                  confirmed (becomes booking)
```

**Reminder:**
```
scheduled → sent (or failed → retried)
```

**WaitList:**
```
waiting → offered (slot opened, customer notified, deadline to confirm) → claimed
                                                                        ↓
                                                               offer_expired → next in line
```

## Vocabulary distinctions (don't conflate)

- **Slot** vs **Availability** vs **Booking** — Availability is the rule (what's open). Slot is one interval matching the rule. Booking is a confirmed slot. Many systems compute slots on the fly; storing all slots ahead of time = explosion (1-min granularity * 30 days * N providers = millions of rows).
- **Soft hold** vs **Booking** — Soft hold is during checkout (5-15 min TTL). Booking is post-payment / post-confirmation. Without a soft hold, two customers race + double-book.
- **Capacity** vs **Resource count** — A class has capacity 20 (one resource, 20 attendees). A salon with 5 chairs has 5 resources, capacity 1 each. Different models.
- **Buffer** — time padding around a booking for cleanup, transit, prep. Provider's calendar shows buffer; customer-facing slot list excludes them as available.
- **Lead time** vs **Cutoff** — Lead time: minimum advance notice ("must book 24h ahead"). Cutoff: latest moment to cancel without fee.
- **No-show** vs **Cancellation** — Cancellation is intentional; no-show is silent. Different policies + fees usually.
- **Reschedule** vs **Cancel + new booking** — Rescheduling preserves history; cancel + new loses linkage (review trends, refund accounting).
- **Deposit** vs **Full prepayment** vs **Pay on arrival** — Different cancellation/refund logic per model. Deposit-only with no-show fee = common in restaurants/spa.
- **Walk-in** vs **Booking** — Walk-in = no prior reservation. Some systems blend (walk-in creates a same-day booking).
- **Recurring booking** vs **Class series** — Recurring: same customer + provider + slot pattern (e.g. weekly therapy). Class series: same instructor + service + slots, different attendees per session.
- **Time zone of operator** vs **time zone of customer** — Same booking shown differently to each. Store `starts_at` in UTC; display in respective TZ.

## Multi-tenancy variants

- **Single-business booking** (one salon's site): no tenant; one provider org.
- **Multi-location chain** (chain of clinics): tenant = location; providers per location.
- **SaaS booking platform** (Calendly, Cal.com, SimplyBook): tenant = each business; total isolation.
- **Marketplace booking** (Booksy, Fresha consumer-side): tenant = the operator; providers + customers shared discovery layer with per-business booking.
- **Aggregator** (OpenTable for restaurants): inventory pulled from many systems; bookings written back to source.

## Time zone discipline

The single most error-prone area in booking systems:

- ALWAYS store `starts_at` and `ends_at` as UTC instants in the DB.
- ALSO store `time_zone` IANA name on the booking (e.g. "Asia/Riyadh") — for display + DST logic.
- Provider's working hours are wall-clock in the provider's TZ ("Mon 9am-5pm").
- Slot generation: compute provider's UTC window for each day, then compare against incoming booking UTC.
- DST transitions: spring-forward day has 23 hours; fall-back has 25. Booking at 2:30am on spring-forward day in TZ where 2:30 doesn't exist = error case to handle (typically push forward).
- Customer-facing display: customer's TZ (from profile / browser).
- Operator-facing display: provider's TZ.
- Reminder send time: customer's TZ (so "1 hour before" makes sense to them).
