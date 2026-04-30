---
description: Rebuild a read-model projection from the event store. Drop-then-rebuild with progress, catchup time, and final-state verification.
---

# /replay-projection

Purpose: rebuild a stale or corrupted projection. Also the only safe way to apply schema changes to a read model.

## Premise

Real signals only. Cite the actual projection name, current `last_event_id`, event-store row counts, and per-batch progress from the live database — never narrate a replay you didn't run. Read before writing: confirm projector position + advisory lock state BEFORE any TRUNCATE or write. PROD requires `CONFIRM_PROD_REPLAY=yes`; without it, halt.

## Mechanical halt

Cite-or-halt: every progress line and verification stat must come from an actual SQL query result (event count, row count, position). No estimated "should be done now" lines. If the advisory lock can't be acquired, halt — do not "best-effort" replay alongside another writer.

## When to invoke

- Projection state diverged from event store (bug found, audit failed).
- New projector added — needs initial backfill from existing events.
- Existing projector schema changed — drop + rebuild from events.
- Suspected projector regression — replay against staging events, diff against prod table.
- Quarterly drift check — replay into a shadow table, diff vs live (should be empty).

## What it does

```
1. Acquire advisory lock on projection name. Refuse if another replay is running.
2. Read projector position (last_event_id from projection_state).
3. If --drop: TRUNCATE the projection table + reset position to 0.
4. Stream events from event_store ORDER BY global_position ASC.
5. For each event:
     a. Lookup projector handler by event type + version (upcaster if needed).
     b. Apply within a transaction with position update (atomic).
     c. Print progress every 10k events: events/sec, ETA, current global_position.
6. On completion: print final state stats + verify row count vs expected.
7. Release advisory lock.
```

## Usage

```bash
# Full rebuild (drops table)
.claude/skills/replay-projection.sh --name=order_summary --drop

# Catchup from current position (no drop, just continue)
.claude/skills/replay-projection.sh --name=order_summary

# Replay into a shadow table (live untouched, diff after)
.claude/skills/replay-projection.sh --name=order_summary --shadow

# Single aggregate (rebuild one stream — useful for support tickets)
.claude/skills/replay-projection.sh --name=order_summary --aggregate=order-abc-123

# Dry-run (no writes; reports what WOULD change)
.claude/skills/replay-projection.sh --name=order_summary --dry-run
```

Or `/replay-projection order_summary --drop`.

## Safety rails

- PROD environment requires `CONFIRM_PROD_REPLAY=yes` env var. Misclick guard.
- Drop + rebuild on a live projection BLOCKS reads from that table during replay → use `--shadow` for online rebuilds.
- Long-running replay (>5min) prints heartbeat to logs every 30s — ops can verify it's alive.
- Killed mid-replay = position table rolls back to last committed batch boundary; rerun resumes from there. NEVER mid-batch.

## Output

```
/replay-projection order_summary --drop

[lock acquired]
[truncate order_summary]
[reset position to 0]

[stream events] global_position=0  type=OrderPlaced  ts=2024-01-01T00:00:00Z
[10000 / ~3.4M] 4200 evt/s  eta 13m22s  pos=10000
[20000 / ~3.4M] 4180 evt/s  eta 13m18s  pos=20000
...
[3400000 / ~3.4M] done in 12m48s  avg 4427 evt/s

[verify]
  events processed:   3,400,000
  rows in projection: 412,837
  unhandled events:   142  (logged at warn — none required handling)
  upcaster hits:      8,219  (OrderPlaced v1 → v2)
  errors:             0

[lock released]
[done]
```

## Verification after replay

```bash
# Compare row count to a known invariant (e.g. orders count vs distinct order ids in events)
psql -c "SELECT COUNT(DISTINCT aggregate_id) FROM event_store WHERE aggregate_type = 'order'"
psql -c "SELECT COUNT(*) FROM order_summary"
# These should match for a non-deletable projection.

# Spot-check an aggregate
psql -c "SELECT * FROM order_summary WHERE id = 'order-abc-123'"
# Then rehydrate from events:
.claude/skills/rehydrate-aggregate.sh --id=order-abc-123 | jq .
# Compare manually OR run --shadow + diff.
```

## Shadow rebuild (online)

For a non-disruptive rebuild on a live system:

1. `--shadow` creates `order_summary__shadow` table with same schema.
2. Replay writes ONLY to shadow.
3. After completion, run a diff query to verify shadow == live (should be empty if live projector is healthy):
   ```sql
   SELECT * FROM order_summary EXCEPT SELECT * FROM order_summary__shadow;
   SELECT * FROM order_summary__shadow EXCEPT SELECT * FROM order_summary;
   ```
4. If empty: drop shadow OR atomically swap (BEGIN; ALTER TABLE order_summary RENAME TO order_summary__old; ALTER TABLE order_summary__shadow RENAME TO order_summary; COMMIT;).
5. If non-empty: investigate live projector for drift bug.

## When NOT to use

- "Quick fix" for a corrupted row — that's an event store mutation problem, not a projection problem. Investigate the root cause.
- Performance tuning — replay is for correctness, not speed. Add indexes / partitioning / projection sharding instead.

## See also

- `ai/patterns/event-sourcing.md` — projector contract + event store schema.
- `.claude/rules/event-sourcing-discipline.md` — replay guarantees.
- `ai/runbooks/projection-rebuild.md` — production rebuild procedure with team coordination.
