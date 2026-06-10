---
name: scheduling-discipline
description: Scheduling, availability & recurrence discipline
kind: rule
---

# Scheduling, availability & recurrence discipline

## Hard rule

Every scheduled instant MUST be stored as a UTC instant PLUS the IANA timezone it was authored in (`America/New_York`, never `EST`, never a bare local `2026-03-08 02:30:00` string) — a wall-clock time without its zone is ambiguous on every read and DST silently shifts it. Recurring series MUST be expanded through an RFC-5545 RRULE / iCal engine, NEVER by looping `addDays(7)` / `addMonths(1)` over a local timestamp — naive date-add drifts across DST, month lengths, and leap years. A booking MUST be confirmed inside a single transaction guarded by a database exclusion / unique constraint over `(resource, time-range)` — a read-then-write availability check with no constraint is a double-booking RACE that will confirm two appointments for one slot. Recurrence expansion MUST be bounded (a `COUNT`, an `UNTIL`, or a hard horizon) — an unbounded `RRULE:FREQ=DAILY` is an effectively infinite series. Bookings in the past or outside published availability MUST be rejected; slot creation MUST be idempotent; user timezone and resource/business timezone MUST be kept distinct.

A scheduling bug is a meeting that fires an hour off, a series that drifts after the clocks change, or two customers standing in the same slot — failures the user sees on their own calendar, so they erode trust immediately.

## Must

- **Store UTC instant + IANA zone, always paired**: persist the absolute instant as UTC (`timestamptz` / epoch millis) AND the originating IANA timezone in a sibling column (`start_at_utc`, `timezone`). For a *floating* / wall-clock event ("09:00 local, wherever the user is") store the local wall time + the zone and resolve to UTC at read time — but NEVER store a bare local timestamp with no zone at all.
- **Expand recurrence via an RRULE / iCal engine**: use `rrule` / `ical.js` / `Recurr` / your platform's RFC-5545 implementation to materialize occurrences. The DTSTART carries a zone; the engine handles month-length, leap-day, and DST transitions. Store the rule, not the expanded rows, as the source of truth.
- **DST-aware occurrence resolution**: when expanding a wall-clock series across a DST boundary, resolve each occurrence's wall time IN ITS ZONE, then convert to UTC per occurrence — so "every day at 09:00 local" stays 09:00 local on both sides of the transition even though the UTC offset changed.
- **Book inside a transaction with an exclusion/unique constraint**: the confirm path is `BEGIN; INSERT/UPDATE guarded by EXCLUDE USING gist (resource_id WITH =, time_range WITH &&) or a UNIQUE(resource_id, slot_start); COMMIT`. The database — not an application `if (isAvailable)` check — is the arbiter that prevents two concurrent confirms from both winning.
- **Detect overlap server-side**: a new booking is rejected if its `[start, end)` half-open interval overlaps any existing confirmed booking for the same resource (`a.start < b.end AND b.start < a.end`), accounting for declared buffer/setup/travel time around each appointment.
- **Bound every recurrence expansion**: every RRULE carries a `COUNT`, an `UNTIL`, or is expanded only within a requested window with a hard maximum (e.g. `<= 730` occurrences or a 2-year horizon). An open-ended rule is materialized lazily per-window, never eagerly to infinity.
- **Reject past + out-of-availability bookings**: a slot whose start is in the past (in the resource's zone, with a small clock-skew grace) or that falls outside the resource's published availability / working hours is rejected before the transaction — not silently accepted.
- **Idempotent slot + booking creation**: slot generation and booking confirmation are keyed by a deterministic key (`slot:<resource>:<startUtc>` / an idempotency key on confirm) so a ret, a double-click, or a redelivered job produces ONE slot / ONE booking, never duplicates.
- **Keep user-tz and resource-tz distinct**: the customer sees slots in THEIR timezone; the resource/business owns availability in ITS timezone; the stored instant is UTC. Display conversion happens at the edge. Never conflate the two zones or assume the server's zone for either.
- **Half-open intervals**: represent every slot/booking as `[start, end)` so back-to-back appointments (`10:00-10:30`, `10:30-11:00`) do not register as an overlap. Pick the convention once and apply it everywhere.
- **Authoritative "now" + clock skew**: compare against a single server-sourced `now` (UTC), never the client clock, with a small grace window for skew when rejecting past bookings.

## Must not

- Store a bare local timestamp (`2026-03-08 02:30:00`) with no IANA zone — every later read is ambiguous and a DST change shifts it silently.
- Store an abbreviation (`EST`, `PST`, `CET`) as the zone — abbreviations are not unique and don't carry DST rules; use the IANA name.
- Expand a recurring series by looping `addDays(7)` / `addMonths(1)` / `+ 7*86400*1000` over a timestamp — drifts across DST (an hour off after the clocks change), breaks on month-length (Jan 31 + 1 month), and on leap years.
- Confirm a booking from an application-level `if (await isAvailable(slot))` read-then-write with no DB constraint — two concurrent requests both read "available" and both insert -> double-booking.
- Skip overlap detection, or detect it with closed intervals that false-positive on back-to-back slots, or ignore buffer/setup time.
- Materialize an unbounded RRULE eagerly (`FREQ=DAILY` with no `UNTIL`/`COUNT`) -> effectively infinite occurrences -> memory blowup / runaway job.
- Accept a booking in the past or outside published availability because the check was client-side only.
- Generate slots non-idempotently (a cron that re-runs and re-inserts the same slots) -> duplicate slots for the same resource+time.
- Conflate the user's timezone with the resource/business timezone, or assume the server's timezone for either.
- Compute day boundaries ("this week's availability") in server-UTC for a resource in a non-UTC zone (same class of bug as the reporting timezone bug — see Cross-references).

## Should

- Wrap the booking path behind a project-internal `<SlotBooker>` / `<AvailabilityService>` so the transaction, the exclusion constraint, the overlap + buffer rule, and the past/availability guards live in ONE place — feature code requests a slot, it does not hand-roll the concurrency.
- Express recurrence as a stored RRULE string + DTSTART + zone, and expand lazily per requested window; keep an `exdate` / exception list for cancelled or moved single occurrences rather than forking the series.
- Model availability as the resource's working-hours rules MINUS existing bookings MINUS blackouts, computed in the resource's zone and projected into the requester's zone at the edge.
- Use a library-grade timezone layer (`Temporal`, `Luxon`, `date-fns-tz`, `java.time` `ZonedDateTime`, `pytz`/`zoneinfo`) — never hand-rolled offset arithmetic, never `new Date(str)` for zoned math.
- Drive reminders + recurrence materialization through the jobs layer (see `<rules-path>/background-jobs`) with idempotency keyed per occurrence, so a redelivered reminder fires once.
- Detect and surface the two DST edge cases explicitly: the *skipped* wall-clock hour (02:30 on spring-forward day does not exist) and the *duplicated* wall-clock hour (01:30 on fall-back day happens twice) — choose a documented resolution policy for each.
- Log structured `{ resourceId, slotStartUtc, timezone, rrule, occurrenceCount, outcome }` and alert on overlap-constraint violations (a caught double-book attempt) and on expansions that hit the occurrence cap.

## Review checklist (PRs touching calendars / availability / bookings / recurrence / reminders)

- [ ] Every stored instant is UTC + a paired IANA timezone column — no bare local timestamp, no abbreviation. Cite the column/write at `<path:line>`.
- [ ] Recurring series expand through an RRULE / iCal engine — no `addDays`/`addMonths` loop. Cite the expansion at `<path:line>`.
- [ ] Booking confirm runs in a transaction guarded by an exclusion / unique constraint over `(resource, time-range)` — not an app-level availability read. Cite the constraint + the transaction at `<path:line>`.
- [ ] Overlap detection uses half-open `[start, end)` intervals and accounts for buffer/setup time.
- [ ] Every recurrence expansion is bounded (COUNT / UNTIL / windowed with a hard cap).
- [ ] DST boundaries handled: wall-clock series resolved per-occurrence in-zone; the skipped hour and the duplicated hour have a documented policy.
- [ ] Past bookings and out-of-availability bookings are rejected server-side against a server-sourced `now`.
- [ ] Slot + booking creation is idempotent (deterministic key / idempotency key).
- [ ] User timezone and resource/business timezone are kept distinct; display conversion happens at the edge.
- [ ] Day-boundary / week-window math is computed in the resource's zone, not server-UTC.

## Anti-patterns

- **Bare local timestamp** — storing `start_at = '2026-03-08 02:30'` with no zone -> on read no one knows if that's UTC, server-local, or the user's wall clock; the spring-forward change shifts it by an hour. Store UTC instant + IANA zone.
- **`EST` as a timezone** — storing the abbreviation drops the DST ruleset and isn't even unique (`CST` = US Central or China Standard?). Store `America/New_York`.
- **`addDays(7)` recurrence** — `for (i) occur = addDays(dtstart, 7*i)` -> after the DST change every occurrence is an hour off; a monthly `addMonths(1)` from Jan 31 lands on Mar 3. Expand via RRULE.
- **Read-then-write availability** — `if (await isFree(slot)) await book(slot)` -> two requests both read free, both book -> double-booking. Confirm in a transaction behind an `EXCLUDE`/`UNIQUE` constraint; let the DB reject the loser.
- **Closed-interval overlap** — `start <= other.end AND other.start <= end` flags `10:00-10:30` and `10:30-11:00` as overlapping. Use half-open `[start, end)`: `start < other.end AND other.start < end`.
- **Unbounded RRULE** — `FREQ=DAILY` with no `UNTIL`/`COUNT` expanded eagerly -> the materializer tries to produce infinite rows. Bound by window + a hard cap; expand lazily.
- **Spring-forward booking** — accepting a 02:30 booking on the day 02:00->03:00 is skipped -> a time that does not exist -> `Invalid Date` / a silent shift. Detect the non-existent wall time and apply a documented policy.
- **Fall-back ambiguity** — 01:30 on fall-back day happens twice; "the 1:30 reminder" fires twice or at the wrong offset. Resolve which 01:30 (first/second offset) explicitly.
- **Past booking accepted** — only the client checks "is this in the future"; a replayed/crafted request books last Tuesday. Reject against a server-sourced `now` in the resource zone.
- **Duplicate slots** — a slot-generation cron re-runs and re-inserts the same `09:00` slot -> two identical slots, two people book "different" slots that are the same time. Key slot creation deterministically.
- **User-tz vs resource-tz muddle** — slots generated in the customer's zone but stored as if the business's, or vice versa -> everyone is an offset off. Keep the two zones distinct; store UTC; convert at the edge.
- **Server-UTC day boundary** — "today's availability" computed with `startOfDay(new Date())` in UTC for a clinic in GMT+8 -> the day window is 8 hours off (same bug class as the reporting timezone anti-pattern). Compute boundaries in the resource's zone.

## Enforcement

- `<commands-path>/audit-scheduling.md` (slash: `/audit-scheduling`) — locates the booking/availability code at `<path:line>` and reports, cite-or-halt: timezone storage (UTC+IANA vs bare local), recurrence (RRULE vs naive add), double-booking protection (transactional constraint vs read-then-write), DST handling, recurrence bounds, and idempotency — never an assumed shape.
- `<agents-path>/scheduling-reviewer.md` — review gate hard-failing on bare-local-timestamp storage, naive recurrence, read-then-write double-booking, missing overlap detection, DST-boundary bugs, unbounded expansion, past/out-of-availability bookings, non-idempotent slot creation, and user-tz/resource-tz confusion.
- CI lint MUST flag `addDays(`/`addMonths(`/`addWeeks(` inside a file tagged as recurrence/scheduling (heuristic for naive expansion; flag for review).
- CI lint MUST flag a booking-confirm path with no surrounding transaction or no exclusion/unique constraint reference (AST heuristic; flag for review).
- CI MUST assert the bookings table declares an exclusion (`EXCLUDE USING gist`) or unique constraint over `(resource_id, time-range)` in the migration set.
- CI lint MUST flag a timestamp column written without a paired timezone column in scheduling models (heuristic; flag for review).
- TODO: `scripts/validate-scheduling.sh` to walk scheduling models and assert (1) every event instant has a paired IANA-zone column, (2) every recurrence path resolves to an RRULE engine, and (3) every confirm path is transactional with a constraint.

## Cross-references

- `<patterns-path>/scheduling-availability.md` — UTC+IANA storage, RRULE expansion, DST-aware resolution, transactional booking with exclusion constraint, availability slot generation, and idempotent slot creation code shapes.
- `<rules-path>/reporting` — the org-timezone day-boundary discipline; scheduling shares the same "compute boundaries in the entity's zone, store/query UTC" rule. A server-UTC day boundary is a bug in both.
- `<rules-path>/background-jobs` — reminder + recurrence-materialization jobs run with per-occurrence idempotency; a redelivered reminder must fire once.
- `<rules-path>/notifications` — appointment reminders / confirmations / reschedule notices are sent through the notifications layer, keyed per occurrence.
- `<adr-path>/<NNN>-scheduling-timezone-model.md` — ADR pinning the UTC+IANA storage model, the floating-vs-zoned event policy, the DST skipped/duplicated-hour resolution, and the exclusion-constraint choice.
