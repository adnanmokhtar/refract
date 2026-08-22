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

## When to run

- A feature whose V2 uses a different store or schema than V1 (SQL→document, monolith DB→service-owned DB, one table→a normalized set, on-prem→managed), and you are about to fill the V2 store.
- Before flipping reads to V2 — this skill produces the readiness verdict that gate consults.
- After the ledger row reaches `In-progress`/`V2-shadow` and the V2 write path exists.

Do NOT run for single-store schema evolution (same store, new columns/indexes) — that is `database/migrations`. Do NOT run to decide output equivalence — that is `parity-test-generate`.

## The cutover sequence

1. **Pick the source of truth** for the window — exactly one store is authoritative for reads.
2. **Dual-write OR CDC** — every V1 write must reach V2; both need a reconciliation that proves they agree.
3. **Resumable, checkpointed backfill** — key-range batches, durable checkpoint cursor, idempotent upsert. Never one unbounded `SELECT * → write`.
4. **Apply the V1→V2 field mapping** from `ai/migration/mapping/<feature>.md` — one shared mapper for backfill AND dual-write, not two copies.
5. **Reconciliation** — per-range counts + checksum/sample-diff; emit `mismatched_keys / total_keys`. This result is the gate's evidence.
6. **Read-cutover gate** — flip reads ONLY when backfill is 100% AND divergence ≤ threshold; the flip is a reversible one-step flag.
7. **V1 decommission after a clean soak** — stop dual-write, retire V1 with evidence.

## Detectors (cite-or-halt)

Each finding cites `<path:line>` (the backfill script, the reconciliation query, the flag wiring) plus the checkpoint/result artifact. No cite → the claim doesn't hold.

1. **Backfill not resumable/checkpointed.** BAD: one `SELECT * FROM v1 → insert into v2` pass, no cursor, no restart story — dies at scale, restarts from zero. GOOD: key-range batches, durable checkpoint, idempotent upsert, safe to kill/restart. Grep: backfill scripts with no `LIMIT`/`WHERE id >`/cursor read; a single `forEach`/`for row in` over a full-table fetch.

2. **Backfill not verified before cutover.** BAD: backfill "finished", reads flipped, no reconciliation ran. GOOD: reconciliation green artifact exists and is cited before the flag flips. Grep: a read-flag flip commit with no reconciliation output referenced in the same PR/ledger row.

3. **Dual-write with no drift reconciliation.** BAD: writes fan out to V1 + V2, nothing ever compares them. GOOD: a scheduled reconciliation + a divergence metric alarmed. Grep: a second store write next to the primary with no comparator/metric emitting `mismatch`.

4. **Read-cutover not gated on backfill completeness.** BAD: reads switch on a deploy/date/manual toggle unrelated to checkpoint state. GOOD: the flag's open condition reads `checkpoint == complete && divergence <= threshold`. Grep: the read-selection flag has no dependency on the checkpoint/reconciliation state.

5. **No consistency audit between stores.** BAD: no counts, no checksum — "we trust the backfill". GOOD: per-range counts + checksum/sample-diff with a numeric divergence result. Grep: no query that touches both stores and produces a count/hash comparison.

6. **Field mapping applied inconsistently.** BAD: the backfill transform and the live dual-write transform are two separate code paths → they diverge on the fields where they differ. GOOD: one shared mapping function called by both. Grep: two distinct V1→V2 field assignments (backfill file vs write-path file) not sharing a mapper.

7. **Schema changed mid-window, no re-backfill.** BAD: mapping/V1 schema edited after backfill start; already-ported keys never re-mapped. GOOD: affected key range re-backfilled from a reset checkpoint. Grep: a mapping/schema change timestamp later than the checkpoint's first-run timestamp with no subsequent re-backfill entry.

## Output

A cutover runbook + readiness verdict at `ai/runbooks/migration-cutover-<feature>.md`: source-of-truth choice, backfill checkpoint/progress, the reconciliation query + result, read-flip gate status (default `BLOCK`), one-step rollback path. Closure verbs: `BLOCK cutover` / `CLEAR cutover` / `RE-BACKFILL <range>` / `RECONCILE` — each names the artifact that clears it.

## Failure modes

- **Cutover-ready claim without a reconciliation result AND checkpoint** — both are artifacts, not adjectives; verdict is BLOCK.
- **Gate opens on "backfill exited 0"** rather than checkpoint-complete + reconciliation-green — the primary failure mode; reject it.
- **Schema changed mid-window, no re-backfill** — already-ported keys were mapped by the old transform; re-backfill the affected range from a reset checkpoint.

## False positives / gotchas

- **Append-only / immutable V1 dataset.** If V1 rows are write-once and never mutated (event log, ledger of past facts), there are no in-flight writes to lose — a one-shot backfill suffices and dual-write is over-engineering. Dismiss detector 3 here *with the reason cited* (the dataset's immutability, `<path:line>` showing no update path). Still reconcile counts/checksum before cutover — a one-shot backfill can still drop rows.
- **Acceptable eventual-consistency window.** A short lag between a V1 write and its V2 mirror may be fine (async CDC, minutes-behind replica). That is acceptable ONLY if declared explicitly in the plan with a bounded window and the reconciliation threshold set to tolerate it — an *undeclared* lag is detector 3, not a false positive. Make the window a number.
- **Reconciliation sampling vs full-scan at scale.** A full row-by-row checksum of a billion-row store may be infeasible per run. A statistically-sized sample plus exact per-range counts is an accepted tradeoff — but state the sample rate and confidence, and full-scan the ranges the backfill most recently touched. Don't let "sampling" quietly mean "we checked 100 rows and shipped".
## Halt conditions

- **Refuse any cutover-ready claim without the reconciliation result AND the backfill checkpoint.** Both are artifacts, not adjectives. Missing either → verdict is BLOCK, full stop.
- **Never gate reads on an unverified backfill.** A flag that opens on "backfill script exited 0" (not on checkpoint-complete + reconciliation-green) is the primary failure mode — reject it.
- **Single-store schema evolution is database/migrations' job.** If there is one store and the change is columns/indexes/constraints in place, do not run this skill — hand off to `database/migrations` and do not double-own the backfill.
- **Output equivalence is parity-test-generate's job.** If the question is "does V2 return the same shape as V1", that is the parity suite, not reconciliation — don't conflate a green parity run with a full V2 store.

## Related

- `parity-test-generate.md` — COMPARES V1/V2 output (this skill PORTS + reconciles data).
- `migration-discipline.md` — the rule mandating checkpointed backfill + gated read-cutover.
- `database/migrations` (cross-pack) — owns single-store schema evolution; this skill owns the cross-store seam.
- `parity-auditor.md` (agent) — consults this skill's readiness verdict before cutover.

