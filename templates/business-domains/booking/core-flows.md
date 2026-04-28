# Booking — core flows

The flows every booking system must support. P1 = "without these, bookings can't happen reliably." P2 = retention. P3 = scale + operator productivity.

## P1 — must-have for v1

### 1. Search availability

```
Customer enters: service + (optional provider) + (optional date range)
  → server computes available slots for that window:
       for each provider matching service:
         expand WorkingHours into UTC ranges for the date range
         subtract BlackoutPeriods
         subtract existing Bookings (with buffers)
         subtract SoftHolds (active, not expired)
         apply lead-time + cutoff filters
         return slots in customer's TZ
  → display calendar / list of slots
```

Critical invariants:
- Slots computed FRESH on every request — caching the slot list invites doublebook (caching the inputs, fine).
- Lead time enforced: cannot show 2pm slot if it's already 1:30pm and lead-time is 1h.
- Capacity awareness: class with 18/20 booked still shows; full class either hidden or shown disabled.
- TZ correctness: slot at "Tuesday 9am" must be the same wall-clock moment regardless of customer's TZ choice when displayed for the provider.

### 2. Book a slot (race-safe)

```
Customer selects slot
  → POST /soft-hold { slot_start, slot_end, provider_id, service_id }
       server: INSERT INTO holds with EXCLUSION CONSTRAINT or row-lock
              if conflict → 409, "just booked, choose another"
              else → return hold_id with TTL (e.g. 10 min)
  → customer fills details + payment
  → POST /bookings { hold_id, customer_data, payment_token? }
       server: validate hold still active
              create Booking (tentative)
              charge deposit / full payment if required
              on success: status=confirmed; release hold (booking now owns the slot)
              on payment failure: roll back; release hold
  → confirmation page + email/SMS
```

Critical invariants:
- Soft-hold is a proper DB constraint, not a "soft" check. Either UNIQUE constraint or `EXCLUDE USING gist (tstzrange(...) WITH &&)` in Postgres, or row-lock + serializable isolation.
- Idempotency on POST /bookings — Idempotency-Key header; double-click = same booking.
- Hold TTL enforced server-side; sweeper cron releases expired.
- If payment fails partway, the slot must release (no zombie holds).
- Confirmation code is unguessable (UUID or signed) — used in cancel/reschedule links.

### 3. Confirmation + reminders

```
On booking confirmed:
  → email immediate ("booked for Tuesday 3pm with Dr. Smith")
  → schedule reminders:
       T-24h email
       T-2h SMS (if customer opted in)
       (configurable per service / per tenant)
  → ICS attachment in email (for calendar import)

Cron / scheduler runs:
  fetch due reminders → send via channel → mark sent
  (idempotent: send_id; never double-send)
```

Invariants:
- Reminder times computed in customer's TZ (so "T-24h" is meaningful).
- Reminder cancellation triggered on booking cancel/reschedule.
- Bounced email / undeliverable SMS → flag, retry once on different channel.

### 4. Cancellation

```
Customer clicks cancel link (signed, no login required)
  → display: booking detail + cancellation policy + fee preview
  → confirm cancel
  → POST /bookings/:id/cancel
  → server: validate cancel window
       compute fee per policy
       process refund (less fee) — original payment method
       set booking.status = cancelled
       cancel scheduled reminders
       fire cancelled webhook
       offer wait-list slot to next person (if any)
  → confirmation + receipt
```

Invariants:
- Late-cancel fee disclosed BEFORE the cancel is committed.
- Refund partial or none per policy; honest, no surprise charges.
- Reminder dispatch checked-in: "is booking still confirmed?" right before send.

### 5. Reschedule

```
Customer requests reschedule
  → display new slot picker (same constraints)
  → reschedule policy applied (reschedule fee? Min notice?)
  → on confirm:
       new booking created; old marked rescheduled (history preserved)
       OR same booking updated with audit-logged change
       (pick one model, document it)
  → reminders rescheduled
```

Invariants:
- Audit history retained — original time visible.
- Cannot reschedule into the past.
- Cannot reschedule beyond reschedule cutoff.

### 6. No-show handling

```
Booking time passes without check-in:
  → grace period (5-15 min)
  → operator marks no-show OR system auto-marks
  → no-show fee charged per policy
  → flag on customer profile (n no-shows; some businesses warn after threshold)
```

Invariants:
- Auto-mark no-show only AFTER appointment ends + grace.
- Customer notified ("we missed you") with reschedule offer.
- Operator can override (genuine reason).

### 7. Provider calendar view (operator side)

```
GET /admin/calendar?provider=X&date=...
  → return bookings + blackouts + buffers in provider's TZ
  → render as day/week/month calendar
  → drag to reschedule (with constraints)
  → click slot to add manual booking (walk-in / phone)
```

## P2 — retention + experience

### 8. Customer profiles + history
- Customer's past bookings.
- Saved payment methods.
- Notes (allergies, preferences, room preference).
- Re-book button on past booking ("again?").

### 9. Wait list
- Slot full → "Add me if it opens."
- On cancel: notify next on list with deadline (e.g. 30 min).
- Auto-roll to next if not claimed.

### 10. Recurring bookings
- "Every Monday at 9am for 12 weeks."
- RRULE-based; exceptions per occurrence.
- Cancel one or all-future occurrences.

### 11. Memberships / packages
- "Buy 10 sessions for $200; valid 6 months."
- Booking deducts a credit.
- Auto-renewal optional.

### 12. Group / class bookings
- One slot, multiple attendees.
- Capacity + waitlist.
- Each attendee has own confirmation.
- Cancel one attendee ≠ cancel class.

### 13. Multi-resource bookings
- Service requires X room + Y staff + Z equipment.
- Slot is available only if ALL match.
- Conflict detection across all resources.

### 14. External calendar sync (Google / Outlook / Apple iCal)
- Operator's external calendar pushed in (busy times block bookings).
- Confirmed bookings pushed out (so external calendar reflects).
- Two-way sync with OAuth + webhook for changes.
- Conflict handling: external event drops in over a booking.

### 15. SMS / WhatsApp confirmation + reminders
- Major retention: SMS reminders cut no-shows by 30-50%.
- Two-way (customer can reply CONFIRM or CANCEL).

## P3 — scale + revenue

### 16. Dynamic / surge pricing
- Peak hours cost more; off-peak discounted.
- Configured per service/provider; computed at booking time.

### 17. Group bookings (party of N at restaurant)
- Single booking with party_size; tables joined / multi-table allocation.
- Larger parties may require deposit.

### 18. Walk-in flow
- No-prior-reservation arrival; queue + estimated wait.
- Convert to booking when seated/started.

### 19. Reviews + ratings (per booking)
- Post-completion prompt.
- Provider-specific + service-specific ratings.

### 20. Provider performance dashboard
- Bookings count, utilization %, no-show rate, cancellation rate, revenue, top services, ratings.

### 21. Customer marketing
- Win-back email after 3 months no booking.
- "Time for your next checkup?" healthcare nudge.
- Birthday / anniversary discount.

### 22. Multi-location + multi-tenant
- Customer searches across locations.
- Booking pinned to a location.
- Reports per location.

### 23. Integrations
- POS (charge for add-ons at checkout).
- CRM (HubSpot / Salesforce sync).
- Email marketing.
- Accounting (sync revenue, refunds).

## Idempotency-critical endpoints

- `POST /soft-holds` — double-tap creates two holds; second should fail or return same hold.
- `POST /bookings` — Idempotency-Key required.
- `POST /bookings/:id/cancel` — re-cancel = same outcome.
- `POST /bookings/:id/reschedule` — re-call = same.
- Reminder dispatcher worker — same reminder may be claimed twice; dedupe.

## Webhooks to produce

- `booking.created`, `booking.cancelled`, `booking.rescheduled`, `booking.completed`, `booking.no_show`.
- `reminder.sent`.
- `waitlist.slot_offered`, `waitlist.claimed`.
- `provider.availability_changed`.

## Webhooks to consume

- Payment provider: charge / refund / dispute.
- Calendar provider (Google/Outlook): event.created/updated/deleted.
- SMS provider (Twilio): delivery status, inbound replies.

## Time-of-day pitfalls

- DST transitions: a slot at "2:30am Spring Forward day" doesn't exist. Either skip (no slot) or shift forward; document.
- DST fall-back: "1:30am" happens twice. Disambiguate or block.
- Recurring booking spanning DST: hold wall-clock or hold UTC offset. RRULE typically holds wall-clock; visualize precisely.
- New Year midnight booking: TZ + locale matter.
- Leap day: recurring "every 28th of Feb" works; "every 29th" fails 3 of 4 years — handle.
- Crossing midnight: 11pm-1am booking spans two days; queries must use a range, not a date equality.
