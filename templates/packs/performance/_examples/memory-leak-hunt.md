---
name: memory-leak-hunt
description: Hunt a memory leak by heap-diffing over time and attributing the growing allocation. Use when a process's heap/RSS grows monotonically under steady load — never bump the limit to hide it.
---

# memory-leak-hunt

Diff the heap over time, attribute the growing retained set, fix the source, confirm the heap goes flat. Never guess, never bump the limit to make the alert stop.

## Premise

A process whose heap/retained-set grows monotonically under steady load has a leak. Hunt it by heap-diffing over time and attributing the growing allocation — not by reading code and guessing, not by raising the memory limit. Every finding cites the growing object type / allocation site from a captured snapshot diff (dominator or retained-size delta between two snapshots taken under the same steady load), and the retaining path that keeps it alive. "Unbounded cache" requires the snapshot showing that collection's retained size climbing across snapshots, plus the code site that inserts without eviction. No "this looks like it might leak" without two snapshots and a growing delta.

## Halt conditions

- Refuse to declare a leak without at least two heap snapshots under steady load showing a monotonic growth in a specific retained set — a single snapshot only shows a moment, not a trend.
- Refuse to name a source without the retaining path (dominator chain / GC roots → the object) that proves what holds it.
- Halt if the "steady load" wasn't actually steady — growth under rising traffic is expected working-set, not a leak. Hold load flat.
- Don't accept "raise the limit" / "add a periodic restart" as a fix — those hide the leak, they don't close it.
- Don't propose the fix as done until a soak run shows the heap flat (see confirming the fix).

## When to use

- RSS/heap climbs monotonically and never recovers after GC under flat traffic.
- Eventual OOM-kill, restart-loop, or container-memory alert on a long-running process.
- GC thrash — CPU rising and pauses lengthening as the live set grows.

## Prerequisites

- A way to hold load steady (constant RPS / constant job rate) — the same generator used for `profile-endpoint` works.
- Two or more heap snapshots taken at spaced intervals under that steady load.
- Enough runtime (or accelerated allocation) that the leak accumulates visibly between snapshots.

## Technique — heap-diff over time

1. Reach steady state: warm the process, then hold load flat.
2. Snapshot A once the working set has plateaued (baseline live set).
3. Keep the SAME steady load running for a fixed interval.
4. Snapshot B (and optionally C at a further interval).
5. Diff B vs A by retained-size / dominator delta — the leak is the type/collection that grew most and keeps growing into C.
6. Attribute: walk the retaining path (dominator chain / GC roots) to the allocation site + the reference that never releases.

## Common leak sources

- **Unbounded cache / map** — inserts with no eviction, TTL, or max-size. Retained size climbs snapshot over snapshot.
- **Listener / subscription / closure not released** — `on(...)`/`subscribe` with no matching `off`/`unsubscribe`.
- **Module-level / global collection appended-to forever.**
- **Connection / timer / interval / goroutine created per event with no cleanup.**

## Confirming the fix

The leak is closed only when a soak run under the same steady load shows the heap flat — the retained set plateaus, GC reclaims to a stable floor, no OOM. A shorter run or a lower limit is not confirmation.

## Output (illustrative)

```
Leak hunt — worker service, steady 200 jobs/min

Symptom: RSS 180MB → 640MB over 40min, flat load, no plateau; OOM-kill at ~1GB.

Snapshots (heap comparison A@5min vs B@25min vs C@40min):
  Map<string, Session>  retained  62MB → 210MB → 340MB   ← growing, unbounded
  Buffer (job payloads) retained  18MB →  22MB →  23MB   (working set, stable)

Retaining path (dominator chain):
  GC root → sessionCache (module-level Map) → Session → socket → payload buffers
  Insert site: session-store.ts:41  cache.set(id, session)   — no delete, no TTL, no max size

Root cause: sessionCache grows one entry per job, never evicted.

Fix: bound the cache — LRU with max 10k entries + TTL on idle sessions.

Confirmation (soak, same load, 60min after fix):
  RSS 180MB → 205MB → 205MB   flat.  sessionCache retained plateaus at 41MB. No OOM.
```

## Boundary

`profile-perf`'s Memory + GC axis diagnoses a single snapshot (allocation rate, GC pressure at one moment). THIS skill is the over-TIME hunt: two-or-more snapshots under steady load, the growing-retained-set diff, and the flat-heap soak that confirms the fix.

## Related

- `profile-endpoint` — its steady-load generator is the same one that holds load flat here; it profiles one snapshot's hot path, this hunts growth over time.
- `@performance-optimizer` — designs the bounded replacement (LRU, TTL, ring buffer) once the source is attributed.
