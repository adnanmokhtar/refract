---
name: memory-leak-hunt
description: Hunt a memory leak by heap-diffing over time and attributing the growing allocation. Use when a process's heap/RSS grows monotonically under steady load — never bump the limit to hide it.
---

# memory-leak-hunt

Diff the heap over time, attribute the growing retained set, fix the source, confirm the heap goes flat. Never guess, never bump the limit to make the alert stop.

## When to use

- RSS/heap climbs monotonically and never recovers after GC under flat traffic.
- Eventual OOM-kill, restart-loop, or container-memory alert on a long-running process.
- GC thrash — CPU rising and pauses lengthening as the live set grows.

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

## Boundary

`profile-perf`'s Memory + GC axis diagnoses a single snapshot (allocation rate, GC pressure at one moment). THIS skill is the over-TIME hunt: two-or-more snapshots under steady load, the growing-retained-set diff, and the flat-heap soak that confirms the fix.

## Related

- `profile-endpoint` — its steady-load generator is the same one that holds load flat here; it profiles one snapshot's hot path, this hunts growth over time.
- `@performance-optimizer` — designs the bounded replacement (LRU, TTL, ring buffer) once the source is attributed.
