---
description: Audit a calendar / availability / booking / recurrence feature — timezone storage, RRULE vs naive recurrence, double-booking protection, DST handling, recurrence bounds, and idempotency — from the REAL code, never an assumed shape.
---

# /audit-scheduling

Diagnose whether a scheduling feature is timezone-correct, recurrence-safe, and conflict-free: how instants are stored, how series expand, what stops a double-booking, how DST boundaries are handled, and whether expansion is bounded and slot creation idempotent — from the ACTUAL code, not a guess.

## Premise

Real signals only. Cite the actual model/column at `<path:line>` where an instant is stored (UTC + IANA zone, or a bare local timestamp), the recurrence expansion at `<path:line>` (an RRULE engine call, or an `addDays`/`addMonths` loop), the booking-confirm path at `<path:line>` (a transaction + exclusion/unique constraint, or a read-then-write availability check), the DST handling, the recurrence bound, and the slot idempotency key — never narrate a design you didn't read. Read before judging: open the schema/migration AND the booking service AND the recurrence code BEFORE issuing any verdict.

## Mechanical halt

Cite-or-halt: every run MUST print (1) the instant-storage column(s) at `<path:line>` and whether it is UTC+IANA or a bare local timestamp, (2) the recurrence-expansion site at `<path:line>` and whether it is an RRULE engine or a naive date-add, (3) the booking-confirm path at `<path:line>` and whether a transactional exclusion/unique constraint protects it, (4) the DST-boundary handling, (5) the recurrence bound, and (6) the slot/booking idempotency key. If any of these cannot be produced from real code, HALT and say which — never an assumed storage model, never an assumed constraint, never an assumed RRULE.

This command READS code; it does not run the booking path or mutate any schedule. If the only way to confirm the exclusion constraint is the live DB, say so — read the migration set; do not infer the constraint from the table name.

## What it does

1. **Locate** the scheduling surface — the event/booking/slot model, the availability service, the recurrence code, the reminder jobs. Cite each at `<path:line>`.
2. **Timezone storage** — find where an instant is persisted. Is it a UTC instant PLUS a paired IANA-zone column, or a bare local timestamp / an abbreviation (`EST`)? Cite the column + the write site. A bare local timestamp is a finding.
3. **Recurrence** — find how a series materializes. An RRULE / iCal engine (`rrule`, `ical.js`, `Recurr`, `java.time` + RFC-5545), or an `addDays(7)` / `addMonths(1)` loop? Cite the expansion. A naive add is a BLOCKER.
4. **Double-booking protection** — find the confirm path. Is it a transaction guarded by an exclusion (`EXCLUDE USING gist`) / unique constraint over `(resource, time-range)`, or an application `if (await isFree(slot))` read-then-write? Cite the constraint in the migration AND the transaction in the service. A read-then-write with no constraint is a BLOCKER (race).
5. **Overlap detection** — is overlap checked with half-open `[start, end)` intervals, including buffer/setup time? Closed intervals (back-to-back false-positives) or no overlap check is a finding.
6. **DST handling** — is the skipped wall-clock hour (spring-forward) rejected/shifted by policy, and the duplicated hour (fall-back) resolved to one offset? Cite the policy. No DST handling is a finding.
7. **Recurrence bounds** — is every expansion bounded by COUNT / UNTIL / a windowed hard cap? An unbounded eager expansion is a BLOCKER.
8. **Past / availability guard** — are past bookings and out-of-availability bookings rejected server-side against a server `now`? Client-only checks are a finding.
9. **Idempotency** — is slot + booking creation keyed deterministically (idempotency key / `slot:<resource>:<startUtc>`)? Non-idempotent creation is a finding.
10. **Zone separation** — are user-tz and resource/business-tz kept distinct, with conversion at the edge? Conflation is a finding.
11. **Report** — per-axis verdict with the cited `<path:line>` for each, and the top fix.

## Flow

```text
locate scheduling surface (model, booking svc, recurrence, reminders) — cite <path:line>
  -> timezone storage:  UTC+IANA  | bare-local / abbreviation        [BLOCKER if bare-local]
  -> recurrence:        RRULE engine | addDays/addMonths loop        [BLOCKER if naive]
  -> double-booking:    txn + EXCLUDE/UNIQUE | read-then-write        [BLOCKER if read-then-write]
  -> overlap:           half-open [start,end) + buffer | closed/none  [finding]
  -> DST:               skipped + duplicated hour policy | none       [finding]
  -> recurrence bound:  COUNT/UNTIL/windowed cap | unbounded          [BLOCKER if unbounded eager]
  -> past/availability:  server-side reject | client-only             [finding]
  -> idempotency:       deterministic key | none                      [finding]
  -> zone separation:   user-tz vs resource-tz distinct | conflated   [finding]
  -> report: per-axis verdict + cited path:line + top fix
```

## Output

```
/audit-scheduling — <feature> @ <path:line>

Instant storage (<path:line>):
  start_at_utc timestamptz + timezone text ('America/New_York')   OK
  [or: start_at '2026-03-08 02:30' — BARE LOCAL, no zone — BLOCKER]

Recurrence (<path:line>):
  rrule.between(window) — RFC-5545 engine, re-resolved per occurrence   OK
  [or: for(i) addDays(dtstart, 7*i) — NAIVE ADD — BLOCKER]

Double-booking (<path:line>):
  txn + EXCLUDE USING gist (resource_id WITH =, during WITH &&)  @ migration:14   OK
  [or: if (await isFree(slot)) await book(slot) — READ-THEN-WRITE RACE — BLOCKER]

Overlap:          half-open [start,end) + buffer                 [or: closed / none — finding]
DST boundary:     skipped-hour shift + fall-back earlier-offset  [or: none — finding]
Recurrence bound: windowed, cap 730                              [or: UNBOUNDED — BLOCKER]
Past/availability: rejected server-side vs server now            [or: client-only — finding]
Idempotency:      idempotency_key UNIQUE                         [or: none — finding]
Zone separation:  user-tz vs resource-tz distinct               [or: conflated — finding]

Verdict: OK | NEEDS-TZ-FIX | NEEDS-RRULE | NEEDS-CONSTRAINT | BLOCKER

Top recommendation:
  - <e.g. add EXCLUDE constraint + wrap confirm in a transaction; or replace addDays loop with rrule; or pair the instant with an IANA-zone column>
```

## Rules

- READ-ONLY audit. Never run the booking path, never expand a real series into storage, never mutate a schedule.
- Cite-or-halt: real model, real recurrence call, real constraint in the migration, real DST policy — or halt naming what's missing.
- A bare local timestamp with no IANA zone, a naive `addDays`/`addMonths` recurrence, an unbounded eager expansion, and a read-then-write confirm with no exclusion/unique constraint are each reported as a BLOCKER, not an aside.
- Confirm the exclusion/unique constraint from the migration set — never infer it from the table name.
- Always print the double-booking verdict; a read-then-write with no DB constraint is the most damaging finding and is reported first.
- Never report a storage model, an RRULE, or a constraint you didn't read in the actual source.

## Cross-references

- `.claude/rules/scheduling-discipline.md` — the hard-rule list this command enforces (UTC+IANA, RRULE, transactional exclusion constraint, bounded recurrence, DST, idempotency).
- `ai/patterns/scheduling-availability.md` — the UTC+IANA storage, RRULE expansion, transactional booking, and DST-resolution code shapes.
- `<agents-path>/scheduling-reviewer.md` — review gate that consumes these findings.
- `<rules-path>/reporting` — shares the org/entity-timezone day-boundary discipline; cross-check the day-window math here too.
