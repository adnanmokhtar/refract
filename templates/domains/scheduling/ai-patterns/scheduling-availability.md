---
name: scheduling-availability
description: "Pattern: Scheduling (timezone-correct, recurrence-safe, conflict-free, DST-aware)"
kind: ai-pattern
---

# Pattern: Scheduling (timezone-correct, recurrence-safe, conflict-free, DST-aware)

> **Hard rule** — Every scheduled instant is stored as a UTC instant PLUS its IANA timezone, never a bare local timestamp; recurring series expand through an RFC-5545 RRULE / iCal engine, never a naive `addDays`/`addMonths` loop; a booking is confirmed inside a transaction guarded by a database exclusion / unique constraint over `(resource, time-range)`, never an application read-then-write; recurrence expansion is bounded; slot creation is idempotent; the user's timezone and the resource/business timezone are kept distinct and DST boundaries (the skipped hour, the duplicated hour) are resolved per-occurrence in-zone.

**When to apply**
- Any calendar / appointment / booking / availability feature where users in different timezones pick a slot on a shared resource (a person, a room, a piece of equipment).
- Recurring events / series (weekly standups, monthly invoicing appointments, daily reminders) that must survive DST transitions, month-length differences, and leap years.
- Anything where two requests can compete for the same slot and a double-booking is unacceptable.

**When NOT to apply**
- A single, immutable, zone-agnostic countdown ("payment due in 30 days") with no wall-clock semantics — a plain UTC instant is enough; no zone, no recurrence engine.
- A purely display-side relative timestamp ("posted 3h ago") — formatting concern, not a scheduling concern.
- An append-only event log where "when it happened" is recorded UTC after the fact and never rescheduled — there is no future wall-clock to preserve.

**Halt conditions / mandatory cites**
- Cite the event-instant storage (UTC column + paired IANA-zone column) at `<path:line>`. A bare local timestamp with no zone = halt.
- Cite the recurrence expansion through an RRULE / iCal engine at `<path:line>`. An `addDays`/`addMonths` loop = halt (naive recurrence).
- Cite the booking-confirm transaction + the exclusion/unique constraint over `(resource, time-range)` at `<path:line>`. A read-then-write availability check with no constraint = halt (double-booking race).
- Cite the recurrence bound (COUNT / UNTIL / windowed cap) at `<path:line>`. An unbounded eager expansion = halt.
- Cite the past/out-of-availability rejection, the DST-boundary resolution, and the idempotent slot key at `<path:line>` each.
- Grep ban: "it's timezone-safe / no double-booking / recurrence works" without file:line for the UTC+zone storage, the RRULE engine, the exclusion constraint, and the DST resolution.

## Why

Scheduling is deceptively hard because three independent things must all be right at once, and each has a silent failure mode the user sees on their own calendar:

1. **Time is ambiguous without a zone** — a wall-clock `09:00` means nothing until you say *whose* clock. Store the absolute instant in UTC AND the IANA zone it was authored in; a bare local timestamp gets silently shifted by the next DST change and is unreadable on every later read.
2. **Calendars are not arithmetic** — "every week at 09:00 local" is NOT "+7×86400 seconds": DST changes the UTC offset, months have different lengths, leap years exist. Only an RFC-5545 RRULE engine that resolves each occurrence's wall time in-zone gets this right.
3. **Slots are contended** — availability is a read-then-write race. Two requests both read "free" and both insert. The ONLY reliable arbiter is the database: an exclusion / unique constraint over `(resource, time-range)` inside a transaction, so exactly one concurrent confirm wins.

The pattern: store UTC + IANA zone, expand recurrence via RRULE, generate availability in the resource's zone projected to the requester's zone, and confirm bookings transactionally behind an exclusion constraint — bounded, idempotent, DST-aware.

## Storing a scheduled instant (UTC + IANA zone)

> The TypeScript below uses Luxon (`DateTime`) + a Postgres-style schema for illustration. Substitute your project's actual idiom from `.claude/_extracted-codebase.md`: the temporal library (`Temporal`, `date-fns-tz`, `java.time` `ZonedDateTime`, Python `zoneinfo`), the ORM, and the column types. The SHAPE — persist the absolute UTC instant AND the IANA zone, never a bare local string — is what's universal.

```ts
// src/modules/scheduling/core/scheduled-event.ts
import { DateTime } from 'luxon';

// Schema: a zoned event stores the UTC instant AND the IANA zone it was authored in.
//   start_at_utc  timestamptz   NOT NULL        -- the absolute instant
//   timezone      text          NOT NULL        -- IANA name, e.g. 'America/New_York' (NEVER 'EST')
//   is_floating   boolean       NOT NULL DEFAULT false
//   wall_start    text          NULL            -- for floating events: '2026-03-08T09:00' (no offset)

export function toStoredInstant(
  wallClock: string,        // '2026-03-08T09:00'  (what the author typed)
  zone: string,             // 'America/New_York'  (IANA — validated against the tz database)
): { startAtUtc: Date; timezone: string } {
  if (!isValidIanaZone(zone)) throw new InvalidTimezoneError(zone);   // reject 'EST', 'PST', etc.

  const zoned = DateTime.fromISO(wallClock, { zone });
  // DST guard: a non-existent wall time (spring-forward gap) is invalid — do not silently shift it.
  if (!zoned.isValid && zoned.invalidReason === 'unsupported zone') throw new InvalidTimezoneError(zone);
  if (!zoned.isValid) throw new NonExistentLocalTimeError(wallClock, zone);   // e.g. 02:30 on spring-forward day

  return { startAtUtc: zoned.toUTC().toJSDate(), timezone: zone };   // store BOTH — UTC + the zone
}

// On read, the absolute instant is unambiguous; render it in whatever zone the viewer needs.
export function renderInViewerZone(startAtUtc: Date, viewerZone: string): string {
  return DateTime.fromJSDate(startAtUtc, { zone: 'utc' }).setZone(viewerZone).toFormat('ff');
}
```

The instant is stored once, in UTC, with the IANA zone beside it. A bare local timestamp with no zone is FORBIDDEN — it is ambiguous on every read and DST shifts it.

## Expanding a recurring series (RRULE, never naive date-add)

```ts
// src/modules/scheduling/core/recurrence.ts
import { RRule, RRuleSet, rrulestr } from 'rrule';
import { DateTime } from 'luxon';

const MAX_OCCURRENCES = 730;   // hard cap — an unbounded rule is NEVER expanded to infinity

export function expandSeries(
  rruleString: string,         // 'FREQ=WEEKLY;BYDAY=MO;UNTIL=20270101T000000Z'  (RFC 5545)
  dtstartWall: string,         // '2026-01-05T09:00'  (the series anchor, wall clock)
  zone: string,                // 'America/New_York'  — the zone the series is anchored in
  window: { from: Date; to: Date },   // expand ONLY within the requested window
): Date[] {
  // Anchor DTSTART in its zone, in UTC, for the engine.
  const dtstart = DateTime.fromISO(dtstartWall, { zone }).toUTC().toJSDate();
  const set = new RRuleSet();
  set.rrule(new RRule({ ...RRule.parseString(rruleString), dtstart }));

  // Bounded, windowed expansion — between() never materializes the whole infinite series.
  const naiveOccurrences = set.between(window.from, window.to, /* inc */ true);
  if (naiveOccurrences.length > MAX_OCCURRENCES) {
    throw new RecurrenceTooLargeError(rruleString, naiveOccurrences.length, MAX_OCCURRENCES);
  }

  // DST-correct resolution: rrule returns the wall-clock pattern; re-anchor EACH occurrence in its zone
  // so "every Monday 09:00 local" stays 09:00 local on both sides of a DST transition.
  return naiveOccurrences.map((occ) => {
    const wall = DateTime.fromJSDate(occ, { zone: 'utc' }).toFormat("yyyy-MM-dd'T'HH:mm");
    return DateTime.fromISO(wall, { zone }).toUTC().toJSDate();   // re-resolve offset per occurrence
  });
}
```

The series is stored as the RRULE string + anchor + zone — never as expanded rows — and materialized lazily per window with a hard cap. A `for (i) addDays(dtstart, 7*i)` loop is FORBIDDEN: it drifts an hour after every DST change and breaks on month-length and leap years.

## Generating availability slots (resource zone vs. requester zone)

```ts
// src/modules/scheduling/core/availability.ts
import { DateTime, Interval } from 'luxon';

/**
 * Availability = the resource's working-hours rules, in the RESOURCE's zone,
 * MINUS existing bookings MINUS blackouts, projected into the REQUESTER's zone at the edge.
 */
export function generateSlots(
  resource: { id: string; timezone: string; workingHours: WorkingHours; slotMinutes: number; bufferMinutes: number },
  day: string,                 // the requested day, interpreted in the RESOURCE's zone
  existing: Booking[],         // confirmed bookings for this resource
  requesterZone: string,       // the customer's zone — used ONLY for display projection
): Slot[] {
  // Day boundaries computed in the RESOURCE's zone (NOT server-UTC — same bug class as reporting).
  const dayStart = DateTime.fromISO(day, { zone: resource.timezone }).startOf('day');
  const slots: Slot[] = [];

  for (const win of resource.workingHours.forDay(dayStart)) {   // e.g. 09:00–17:00 in resource zone
    let cursor = win.start;
    while (cursor.plus({ minutes: resource.slotMinutes }) <= win.end) {
      const slotStart = cursor;
      const slotEnd = cursor.plus({ minutes: resource.slotMinutes });

      // Half-open [start, end) overlap, including buffer/setup time around each appointment.
      const overlaps = existing.some((b) => {
        const bStart = DateTime.fromJSDate(b.startAtUtc, { zone: resource.timezone }).minus({ minutes: resource.bufferMinutes });
        const bEnd = DateTime.fromJSDate(b.endAtUtc, { zone: resource.timezone }).plus({ minutes: resource.bufferMinutes });
        return slotStart < bEnd && bStart < slotEnd;            // [start, end) — back-to-back is NOT overlap
      });

      if (!overlaps && slotStart.toUTC().toJSDate() > new Date()) {   // reject past slots vs server `now`
        slots.push({
          startAtUtc: slotStart.toUTC().toJSDate(),             // canonical instant (UTC)
          resourceZone: resource.timezone,                     // resource's zone, kept distinct
          displayLocal: slotStart.setZone(requesterZone).toFormat('ff'),   // projected to requester at the edge
        });
      }
      cursor = slotEnd;
    }
  }
  return slots;
}
```

The resource owns availability in its own zone; the requester sees slots projected into theirs; the canonical instant is UTC. The two zones are kept DISTINCT, and the day window is computed in the resource's zone — never server-UTC.

## Booking a slot (transaction + exclusion constraint, no double-booking)

```sql
-- migration: the DATABASE is the arbiter that prevents two confirms winning the same slot.
-- Postgres: an exclusion constraint over (resource, time-range) using a GiST index.
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE bookings (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  resource_id   uuid NOT NULL,
  during        tstzrange NOT NULL,                 -- half-open [start, end) UTC range
  timezone      text NOT NULL,                      -- IANA zone the booking was authored in
  status        text NOT NULL DEFAULT 'confirmed',
  idempotency_key text NOT NULL,
  -- No two CONFIRMED bookings for the same resource may have overlapping ranges:
  EXCLUDE USING gist (resource_id WITH =, during WITH &&) WHERE (status = 'confirmed'),
  UNIQUE (idempotency_key)                          -- idempotent confirm
);
```

```ts
// src/modules/scheduling/core/slot-booker.ts

export class SlotBooker {
  constructor(private db: Db, private clock: Clock) {}

  async confirm(req: BookRequest, ctx: AuthContext): Promise<Booking> {
    const start = req.startAtUtc;
    const end = addMinutes(start, req.durationMinutes);

    // Guard 1: not in the past (server `now`, small skew grace) — never trust the client clock.
    if (start.getTime() < this.clock.now().getTime() - SKEW_GRACE_MS) throw new PastBookingError(start);
    // Guard 2: inside the resource's published availability.
    if (!(await this.isWithinAvailability(req.resourceId, start, end))) throw new OutsideAvailabilityError();

    try {
      // The transaction + exclusion constraint is the ONLY reliable double-booking guard.
      return await this.db.transaction(async (tx) => {
        const [row] = await tx.query(
          `INSERT INTO bookings (resource_id, during, timezone, idempotency_key)
           VALUES ($1, tstzrange($2, $3, '[)'), $4, $5)         -- half-open [start, end)
           ON CONFLICT (idempotency_key) DO UPDATE SET idempotency_key = EXCLUDED.idempotency_key
           RETURNING *`,
          [req.resourceId, start, end, req.timezone, req.idempotencyKey],
        );
        return row;   // exactly one concurrent confirm survives; the loser hits the exclusion constraint
      });
    } catch (e) {
      if (isExclusionViolation(e)) throw new SlotAlreadyBookedError(req.resourceId, start);   // the loser
      throw e;
    }
  }
}
```

The application NEVER decides availability with an `if (isFree)` read-then-write. The database's exclusion constraint rejects the second concurrent confirm; the `idempotency_key` makes a ret / double-click / redelivered job produce exactly one booking.

## DST boundary handling (the skipped hour and the duplicated hour)

```ts
// src/modules/scheduling/core/dst.ts
import { DateTime } from 'luxon';

/** Spring forward: 02:00 -> 03:00, so 02:30 does NOT exist. Fall back: 01:00 happens twice. */
export function resolveWallTime(wall: string, zone: string): { instant: Date; note?: string } {
  const dt = DateTime.fromISO(wall, { zone });

  // Skipped hour: the wall time does not exist on this date in this zone.
  if (!dt.isValid && dt.invalidReason === 'invalid time') {
    // Documented policy: shift forward past the gap (e.g. 02:30 -> 03:30). Make it EXPLICIT, never silent.
    const shifted = DateTime.fromISO(wall, { zone }).plus({ hours: 1 });
    return { instant: shifted.toUTC().toJSDate(), note: 'non_existent_local_time_shifted_forward' };
  }

  // Duplicated hour: 01:30 on fall-back day maps to two instants (two UTC offsets).
  const earlier = dt;                              // first 01:30 (pre-transition offset)
  const later = dt.plus({ hours: 0 }).setZone(zone, { keepLocalTime: true });
  if (earlier.offset !== later.offset) {
    // Documented policy: pick the FIRST occurrence (earlier offset). Make the choice explicit.
    return { instant: earlier.toUTC().toJSDate(), note: 'ambiguous_local_time_chose_earlier' };
  }
  return { instant: dt.toUTC().toJSDate() };
}
```

The two DST edge cases are resolved with a documented policy and an explicit note — never an `Invalid Date` or a silent shift. A reminder for "01:30" on fall-back day must fire ONCE, at the chosen offset, not twice.

## Common mistakes

### Bare local timestamp
Storing `start_at = '2026-03-08T02:30'` with no zone → ambiguous on every read; the next DST change shifts it silently. Store the UTC instant AND the IANA zone.

### `EST` as the timezone
Storing an abbreviation drops the DST ruleset and isn't unique (`CST` = US Central or China Standard?). Store the IANA name `America/New_York`; validate against the tz database.

### `addDays(7)` recurrence
`for (i) occur = addDays(dtstart, 7*i)` drifts an hour after every DST change; a monthly `addMonths(1)` from Jan 31 lands on Mar 3. Expand through an RRULE engine that re-resolves the offset per occurrence.

### Read-then-write double-booking
`if (await isFree(slot)) await book(slot)` → two requests both read free, both insert → two confirmed bookings for one slot. Confirm in a transaction behind an `EXCLUDE`/`UNIQUE` constraint; let the DB reject the loser.

### Closed-interval overlap
`start <= other.end AND other.start <= end` flags back-to-back `10:00-10:30` / `10:30-11:00` as overlapping. Use half-open `[start, end)`: `start < other.end AND other.start < end`.

### Unbounded recurrence expansion
A `FREQ=DAILY` rule with no `UNTIL`/`COUNT` expanded eagerly → effectively infinite rows → memory blowup. Expand lazily per window with a hard occurrence cap.

### Spring-forward booking
Accepting 02:30 on the day 02:00→03:00 is skipped → a time that does not exist → `Invalid Date` / silent shift. Detect the non-existent wall time; apply a documented policy.

### Fall-back ambiguity
01:30 on fall-back day happens twice → "the 01:30 reminder" fires twice or at the wrong offset. Resolve which 01:30 (earlier/later offset) explicitly.

### Past / out-of-availability booking accepted
Only the client checks "is this in the future / within hours" → a replayed request books last Tuesday or 03:00. Reject server-side against a server-sourced `now` in the resource zone.

### Non-idempotent slot creation
A slot-generation cron re-runs and re-inserts the same `09:00` slot → duplicate slots; two people book the "same" slot. Key slot + booking creation deterministically.

### User-tz vs resource-tz muddle
Slots generated in the customer's zone but stored as the business's (or vice versa) → everyone is an offset off. Keep the two zones distinct; store UTC; convert at the edge.

### Server-UTC day boundary
"Today's availability" via `startOfDay(new Date())` in UTC for a clinic in GMT+8 → the window is 8 hours off (same bug class as the reporting timezone anti-pattern). Compute boundaries in the resource's zone.

## Cross-references

- `<rules-path>/scheduling-discipline.md` — the hard-rule list (UTC+IANA storage, RRULE expansion, transactional exclusion-constraint booking, bounded recurrence, DST policy, idempotency).
- `<rules-path>/reporting` — the org-timezone day-boundary discipline; scheduling shares the "compute boundaries in the entity's zone, store/query UTC" rule. A server-UTC boundary is a bug in both.
- `<rules-path>/background-jobs` — reminder + recurrence-materialization jobs run with per-occurrence idempotency; a redelivered reminder fires once.
- `<rules-path>/notifications` — appointment reminders / confirmations / reschedule notices sent through the notifications layer, keyed per occurrence.
- `<commands-path>/audit-scheduling.md` — diagnostic that locates the booking/availability code and reports timezone storage, recurrence, double-booking protection, DST, bounds, and idempotency.
- `<agents-path>/scheduling-reviewer.md` — review gate enforcing this pattern.
- `<adr-path>/<NNN>-scheduling-timezone-model.md` — ADR pinning the UTC+IANA model, the floating-vs-zoned policy, the DST skipped/duplicated-hour resolution, and the exclusion-constraint choice.
