# Booking — domain-specific anti-patterns

Specific to time-slot reservation systems. Generic web bugs become catastrophic here because customers + providers + revenue all collapse on a single failure.

## Time zones

- **Booking time stored in operator TZ as a naive datetime.** DST flip silently shifts every recurring booking by an hour. Always UTC + explicit `time_zone` IANA name on the row.
- **Customer's TZ inferred from IP.** Travelers + VPN users see wrong slots. Ask explicitly + remember; default from browser, not IP.
- **Display in operator TZ for customer.** "Your appointment is at 9am" — customer's local 4am if cross-continent. Show customer's TZ explicitly: "9am Pacific Time / 6pm your time."
- **Recurring booking interpreted as wall-clock OR UTC, inconsistently.** "Every Monday 9am" as wall-clock = DST shifts in offset; as UTC = wall-clock shifts. Pick one (typically wall-clock for human routines) + document.
- **DST spring-forward slot creation.** Booking at 2:30am on the day "2:30 doesn't exist" → exception or silent corruption. Detect + skip or shift.
- **DST fall-back slot creation.** Two 1:30am instants. Disambiguate; usually pick the first (PST 1:30, then PDT 1:30 again). Or block.
- **Reminder send time in UTC.** Customer in JST gets reminder at 3am. Use customer TZ.
- **Calendar export ICS without VTIMEZONE.** Outlook + Apple cal misinterpret on import. Always full VTIMEZONE block.
- **Date-only filtering.** `WHERE DATE(starts_at) = '2025-06-15'` cuts off bookings spanning midnight in customer TZ. Always range queries with proper TZ casting.

## Race conditions + double-booking

- **Slot availability as a Boolean column on the slot.** Two clients race; both see "true"; both write "false"; second write wins; one paid for nothing. Use UPDATE with row-lock + version check, OR a unique constraint, OR Postgres `EXCLUDE USING gist (tstzrange WITH &&)`.
- **No soft-hold during checkout.** Customer A picks slot 2pm, fills payment, pays in 4 min. Customer B picked same slot at minute 1, finished payment in 3 min. A gets confirmed; B's payment captured but slot already gone. Soft-hold with TTL is mandatory.
- **Soft-hold without DB-level uniqueness.** App-level check leaks under concurrency. SQL constraint or `SELECT FOR UPDATE`.
- **Hold release on timer only — no race-safe release on confirm.** Hold says "expires at T+10"; confirm at T+10:01; another customer just took it. Atomic "convert hold to booking" transaction.
- **Hold not invalidated on customer back-button.** Customer abandons checkout; hold sits 10 min; slot wasted. Release on explicit cancel + on session disconnect (best-effort).
- **Provider's external calendar event blocking the slot AFTER the booking confirmed.** External sync runs every 15 min; booking made at minute 5; sync fires at minute 7 importing a Google Calendar event from minute 4 conflicting with booking. Two-way sync conflict-resolution required.
- **Multi-resource booking checks staff but not room.** "Massage in Room A with Sarah" — system checks Sarah free, books. Room A also booked elsewhere. ALL resources must be checked atomically.
- **Class capacity check NOT atomic with booking insert.** `if attendees < max → INSERT` race → 21 attendees in 20-cap class. SELECT...FOR UPDATE OR `INSERT ... WHERE ...` with capacity check in single SQL.

## Cancellation + no-show

- **Cancellation policy enforced in T&Cs only, not in code.** Customer cancels 1 hour before; no fee charged because operator forgot. Encode policy.
- **Late-cancel fee charged without explicit pre-disclosure at cancel.** Customer surprised; chargeback; loses business + dispute fees. Show fee BEFORE confirm-cancel; require acknowledgment.
- **No-show auto-marked too aggressively.** Customer 5 min late; system flagged no-show; charged fee; customer rage. Configurable grace period; provider override.
- **No-show fees charged on a card that's been removed.** Customer removed card after booking; system can't charge; balance owed but uncollectible. Either require re-pay-method capture OR write off.
- **Reminder still sent after cancel.** "See you tomorrow!" to cancelled customer = brand damage. Cancel scheduled jobs on booking cancel.
- **Reschedule treated as new booking, losing history.** Customer disputes "you keep cancelling on me" — system has 3 separate bookings, not 1 with reschedule history.
- **Cancel link expires too soon.** Email arrives, customer clicks 3 days later, expired token, calls support. TTL ≥ booking-time.
- **Cancel link unauthenticated AND uses sequential booking ID.** `?booking=1234` → guess `1233` to cancel another customer's. Use signed token (HMAC) or UUID.
- **Refund issued before fee deducted.** Customer paid $100, refunded $100 + $25 fee owed but uncollected. Refund = paid - fee, atomically.
- **Reschedule + refund timing inconsistent.** Customer reschedules; new slot is cheaper; refund of difference manual. Document policy + automate.

## Reminders

- **Reminder sent without consent.** TCPA class action ($500-$1500/text). Capture explicit opt-in for SMS at booking.
- **Reminder content reveals PHI.** Healthcare booking SMS: "Reminder: colonoscopy tomorrow at 9am." HIPAA breach. Generic content; details on call-back.
- **Reminder time before the user's bedtime.** "Your 8am dentist" sent at 11pm = annoyance. Customer-TZ-aware + quiet-hours logic.
- **Reminder send at the moment of action vs after commit.** Booking inserted; reminder scheduled inline; transaction rolls back; reminder fires for non-existent booking. Schedule on `booking.created` event after commit.
- **At-most-once reminder delivery.** SMS provider returns 5xx; system marks "sent." Customer never received. At-least-once + de-dupe.
- **At-least-once with no de-dupe.** Provider retries; customer gets 3 reminders. Idempotency key on every send attempt.
- **Reminder cron runs on every cluster node.** Each node sends → 3x reminders. Leader-elected scheduler.
- **Provider switch mid-flight (Twilio → MessageBird).** Old phone numbers configured; new ones not. Reminders silently fail. Smoke-test integration weekly.

## Availability computation

- **Slot list cached for 5 min.** Customer A sees a slot, books at min 1; customer B's cached list at min 4 still shows it; conflict at confirm. Cache the inputs (working hours, blackouts) — recompute slot output on every request.
- **Buffer time not subtracted from availability.** "Service is 60 min, 15 min cleanup" — system shows back-to-back 60-min slots. Provider stressed + late. Buffer enforced in slot generation.
- **Lead time not enforced server-side.** Customer's clock is fast; books at minute 0:01 of lead-time window. Server validates.
- **Booking horizon not enforced.** "Book up to 60 days out" → customer books 365 days out via direct API. Validate.
- **Holidays / blackouts ignored.** Christmas day shown as available because nobody set it as closed. Centralized calendar holiday table per region.
- **Provider's commute / travel time ignored.** Multi-location provider shows availability at Location A while booked at Location B 30 min ago. Travel-time buffer per location pair.
- **Service unavailable due to no qualified provider.** "Massage" service has 0 qualified providers today; system still shows availability based on rooms. Conjunctive availability (service AND provider AND resource).

## Calendar sync

- **One-way sync only (operator → external).** Operator's manual events on Google not blocked in booking app → double-book. Two-way mandatory.
- **External event without conflict resolution.** External event drops onto an existing booking. Pick rule: external wins (cancel booking + notify), booking wins (don't sync), or alert + manual.
- **Sync token / cursor lost.** Re-sync from scratch = duplicate events. Persist cursor.
- **Recurring external event treated as N independent events.** RRULE ignored; future occurrences not blocked. Expand RRULE.
- **OAuth token expiry silent failure.** Token refresh fails; sync silently dies; double-bookings start. Monitor token health + alert.

## Payments

- **Hold / pre-auth treated as charge.** "Held" amount on customer's card silently expires after 7 days; no-show fee then unable to be charged.
- **Refund issued via provider dashboard, not via app.** App still says "paid"; reconciliation broken. All refunds via app.
- **Stored card without explicit consent.** Customer pays once; card silently saved; charge for no-show months later → "I never authorized this." Explicit opt-in.
- **Currency mismatch (booking in EUR, charge in USD).** Customer's bank silently converts at bad rate; complaint or chargeback. Single currency at booking time, lock.
- **Tip / gratuity flow missing.** Service-industry mainstay; missing tipping = lost revenue + provider unhappy.

## Multi-resource / class bookings

- **Class signup without per-attendee record.** One booking for the class; 20 customers. Cancel one customer = no record of who. Per-attendee.
- **Waitlist offers not time-bound.** Slot opens; offer to next; offer never expires; if they don't claim, slot wasted. Offer TTL (e.g. 30 min) → next.
- **Waitlist bypassing.** Direct booking after a cancel skips the waitlist. Hold slot for waitlist for grace period before opening.
- **Class capacity check uses cached count.** Stale; over-capacity. Live count + lock.

## Recurring bookings

- **RRULE expansion at write time, storing N rows.** Recurring weekly for "until cancelled" = unbounded rows. Store rule + cap expansion.
- **Edit one occurrence breaks the series.** Customer reschedules week 5; weeks 6-10 unchanged but logic confuses week 5 vs series. Use exception model (RFC 5545 EXDATE / RECURRENCE-ID).
- **Series cancellation leaves orphan reminders.** Reminder cron sees individual rows; cancellation flagged on series. Cancellation cascades.

## Walk-ins + manual entry

- **Walk-in not entered into system.** Provider's calendar diverges from system → next online booking double-books.
- **Walk-in entered with placeholder customer ("walk-in 3").** Customer history fragmented across bookings; no recall.
- **Phone-booked appointment not confirmed via SMS.** Customer doesn't get the same reminder cadence; no-show.

## Customer profile

- **Phone number not validated.** Typo (`555-555-555` missing digit) — reminders fail. Validate at form + send a verification SMS for new bookers.
- **Email + phone normalized differently across regions.** "+1 555..." vs "1 555..." vs "555..." → duplicate customers. Normalize on save.
- **Duplicate customer profiles.** Same person, two bookings under different emails. Operator can't see history. Merge tooling.
- **No-show count zeros out on profile edit.** Operator changes phone; no-show flag lost; customer exploits.
- **Block list not enforced.** Customer marked "do not book" still able to book online. Check on POST /bookings.

## Operator UI

- **Calendar view doesn't reflect just-made bookings.** Polling, not push. 30-second confusion window. Use websockets / SSE / aggressive refetch.
- **Drag-to-reschedule without conflict check.** Drop on busy slot; overwrites; conflict + customer fight.
- **Bulk-edit overwrites operator-set notes.** Custom note replaced by template. Don't overwrite without explicit confirmation.
- **Audit log absent.** "Who marked this no-show?" — silence. Log every state change.

## Healthcare-specific

- **PHI in booking name / notes visible in operator UI without role check.** Receptionist sees diagnosis. RBAC.
- **PHI in URLs.** `/bookings/12345/colonoscopy-prep` — leaked in proxy logs. Use opaque IDs.
- **Voicemail with PHI.** Auto-call leaving "this is your prostate exam reminder." HIPAA breach. Generic message.
- **PHI emails to customer's work email.** Recipient may share inbox. Allow customer to specify personal email.

## Performance + scaling

- **Slot generation O(N) per provider per request.** 50 providers, 30 days, 15-min granularity = 144,000 slots checked per request. Pre-compute per-day + cache + invalidate on booking/blackout change.
- **Calendar query without TZ-aware index.** Sequential scan. Index `(provider_id, starts_at)`.
- **Reminder dispatcher pulling all bookings every minute.** Filter by `next_reminder_at < now`; index that column.

## Trust + UX

- **No mention of cancellation fee until checkout.** Drop-off + reluctance + reviews.
- **"Confirmed" with no email or with email in spam.** Customer assumes failed; rebooks; double-booking; rage.
- **Provider photo missing or generic.** Trust signal absent.
- **Mobile flow with iOS-only payment options (Apple Pay) excluding Android.** Cross-platform parity.
- **Booking URL with no readable slug.** `/book/abc123def` looks phishy. `/book/dental-cleaning-2024-09-15-9am` reassures.
