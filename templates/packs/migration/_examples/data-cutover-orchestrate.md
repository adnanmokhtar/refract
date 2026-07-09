---
name: data-cutover-orchestrate
description: Orchestrate porting a feature's data from a V1 store to a DIFFERENT V2 store — resumable checkpointed backfill, V1→V2 field-mapping application, cross-store reconciliation (counts + checksum), and gating the read-cutover on backfill completeness behind a reversible flag. The cross-store counterpart to database/migrations' single-store expand-contract. Distinct from parity-test-generate (which COMPARES V1/V2 output, does not move data).
---

# data-cutover-orchestrate

Move a feature's data from its V1 store to a V2 store safely, then gate the read-flip on proof the two stores agree. `port-feature` writes the V2 code; this skill fills the V2 store and decides when reads may follow.

This skill is the procedural arm of `migration-discipline.md` § "cross-store data port" + `feature-port.md` cutover phase.

## Premise

The failure mode is flipping reads to V2 before the backfill is complete and verified — users hit V2 and see rows the backfill never reached. The second is dual-writing with no reconciliation — the stores silently diverge. **Cite-or-halt**: every cutover-readiness claim cites the reconciliation result + the backfill checkpoint. "The data is migrated" is a vibe, not evidence.

- **Boundary — `parity-test-generate` COMPARES, this skill PORTS.** Parity tests diff V1/V2 *responses*; this skill moves rows and reconciles *stores*. A green parity suite over an empty V2 store still fails at read-cutover.
- **Boundary — `database/migrations` owns SINGLE-STORE, this skill owns CROSS-STORE.** One store reshaped in place (expand-contract, online DDL) is `database/migrations`. Porting to a *different* V2 store (engine/schema/service) is this skill. One store → stop, use `database/migrations`.

## When to use

- A feature whose V2 uses a different store/schema than V1, and you are about to fill the V2 store.
- Before flipping reads to V2 — this skill produces the readiness verdict the gate consults.

## The cutover sequence

1. **Pick the source of truth** for the window — exactly one store is authoritative for reads.
2. **Dual-write OR CDC** — every V1 write must reach V2; both need a reconciliation that proves they agree.
3. **Resumable, checkpointed backfill** — key-range batches, durable checkpoint cursor, idempotent upsert. Never one unbounded `SELECT * → write`.
4. **Apply the V1→V2 field mapping** from `ai/migration/mapping/<feature>.md` — one shared mapper for backfill AND dual-write, not two copies.
5. **Reconciliation** — per-range counts + checksum/sample-diff; emit `mismatched_keys / total_keys`. This result is the gate's evidence.
6. **Read-cutover gate** — flip reads ONLY when backfill is 100% AND divergence ≤ threshold; the flip is a reversible one-step flag.
7. **V1 decommission after a clean soak** — stop dual-write, retire V1 with evidence.

## Output

A cutover runbook + readiness verdict at `ai/runbooks/migration-cutover-<feature>.md`: source-of-truth choice, backfill checkpoint/progress, the reconciliation query + result, read-flip gate status (default `BLOCK`), one-step rollback path. Closure verbs: `BLOCK cutover` / `CLEAR cutover` / `RE-BACKFILL <range>` / `RECONCILE` — each names the artifact that clears it.

## Failure modes

- **Cutover-ready claim without a reconciliation result AND checkpoint** — both are artifacts, not adjectives; verdict is BLOCK.
- **Gate opens on "backfill exited 0"** rather than checkpoint-complete + reconciliation-green — the primary failure mode; reject it.
- **Schema changed mid-window, no re-backfill** — already-ported keys were mapped by the old transform; re-backfill the affected range from a reset checkpoint.

## Related

- `parity-test-generate.md` — COMPARES V1/V2 output (this skill PORTS + reconciles data).
- `migration-discipline.md` — the rule mandating checkpointed backfill + gated read-cutover.
- `database/migrations` (cross-pack) — owns single-store schema evolution; this skill owns the cross-store seam.
- `parity-auditor.md` (agent) — consults this skill's readiness verdict before cutover.
