---
name: data-cutover-orchestrate
description: Orchestrate porting a feature's data from a V1 store to a DIFFERENT V2 store during a per-feature migration — resumable checkpointed backfill, V1→V2 field-mapping application, cross-store reconciliation (counts + checksum), and gating the read-cutover on backfill completeness behind a reversible flag. The cross-store counterpart to database/migrations' single-store expand-contract. Distinct from parity-test-generate (which COMPARES V1/V2 output, does not move data).
kind: skill
pack: migration
---

# data-cutover-orchestrate

Move a feature's data from its V1 store to a V2 store safely, then gate the read-flip on proof the two stores agree. This is the data half of a cutover — `port-feature` writes the V2 code, this skill fills the V2 store and decides when reads may follow.

## Premise

The failure mode is flipping reads to V2 before the backfill is complete and verified: users hit V2 and see missing or stale rows the backfill never reached. The second failure mode is dual-writing to both stores with no reconciliation — the two stores silently diverge (a dropped write, a mistransformed field, a mid-window schema change) and nobody notices until a customer reports data that "changed by itself".

**Cite-or-halt.** Every cutover-readiness claim cites the reconciliation query result + the backfill checkpoint. "The data is migrated" is a vibe, not evidence. A read-cutover gate that opens on "looks done" is the incident.

**Boundary — parity-test-generate COMPARES, this skill PORTS.** `parity-test-generate` runs V1 and V2 against identical inputs and asserts the *outputs* are equivalent per a tolerance taxonomy. It never moves a row between stores; its shadow/dual-write comparator diffs *responses*, not *stored data*. This skill moves the rows and reconciles the *stores*. Parity tests prove V2's logic matches; reconciliation proves V2's data is present. You need both — a green parity suite over an empty V2 store still fails at read-cutover.

**Boundary — database/migrations owns SINGLE-STORE, this skill owns CROSS-STORE.** `database/ai-patterns/migrations.md` owns evolving one store in place: expand-contract column changes, batched backfill *within* a table, online DDL (`CREATE INDEX CONCURRENTLY`, `NOT VALID` constraints). When V2 keeps the same store and only reshapes the schema, that is its job — do not double-own it here. THIS skill owns the unowned seam: porting data from a V1 store to a *different* V2 store (different engine, different schema, different service), reconciling across the two, and gating the read-cutover. If there is one store, stop and use database/migrations.

## When to run

- A feature whose V2 uses a different store or schema than V1 (SQL→document, monolith DB→service-owned DB, one table→a normalized set, on-prem→managed), and you are about to fill the V2 store.
- Before flipping reads to V2 — this skill produces the readiness verdict that gate consults.
- After the ledger row reaches `In-progress`/`V2-shadow` and the V2 write path exists.

Do NOT run for single-store schema evolution (same store, new columns/indexes) — that is `database/migrations`. Do NOT run to decide output equivalence — that is `parity-test-generate`.

## The cutover sequence

Run these in order. Each phase emits an artifact the next phase and the gate consume.

1. **Pick the source of truth for the window.** For the duration of the port, exactly one store is authoritative for reads. Declare it (`source_of_truth: v1`) in `ai/migration/plans/<feature>.md`. Ambiguity here is how both stores end up half-right.

2. **Dual-write OR change-data-capture.** Once V2's schema exists, every write to V1 must also reach V2 — either an application-level dual-write (write V1, then write V2 through the same field mapping) or CDC tailing V1's log into V2. Both need a reconciliation that *proves* they agree; a dual-write you don't audit is two stores drifting on a timer. Writes stay authoritative to the source-of-truth store; V2 is written-but-not-read until the gate opens.

3. **Resumable, checkpointed backfill.** Never a single unbounded `SELECT * → write` pass — at scale it dies partway and restarts from zero. Batch by key range (id / created_at window), record the last committed cursor to a durable checkpoint (`ai/migration/backfill/<feature>.checkpoint`), and make each batch an **idempotent upsert** so a re-run over already-ported keys converges instead of duplicating. Safe to kill and restart at any point; progress is the checkpoint, not a log line.

4. **Apply the V1→V2 field mapping during backfill.** The mapping IS the migration's contract — cite it (`ai/migration/mapping/<feature>.md`, per migration-discipline's "Inventory V2 before reading V1"). Every V1 column maps to a named V2 field or is explicitly dropped. The transform applied in the backfill MUST be the identical transform the dual-write path applies — one shared mapping function, not two hand-written copies (see detector 6).

5. **Reconciliation / consistency audit.** After the backfill catches up, prove the stores agree: row counts per key range, plus a checksum or sample-diff of field values (hash of the mapped payload, or a sampled row-by-row diff). Emit a single divergence metric — `mismatched_keys / total_keys`. This query and its result are the evidence the gate reads; no result, no gate.

6. **Read-cutover gate.** Flip reads to V2 ONLY when backfill is 100% (checkpoint cursor past the max key) AND reconciliation is green (divergence ≤ the declared threshold, ideally 0). The flip is behind a feature flag and reversible in one step — flag back to V1, reads return to the still-current V1 store (dual-write kept V1 warm). Ledger transition `V2-shadow → V2-canary → V2-only` follows this gate, not a calendar.

7. **V1 decommission after a soak.** Keep dual-writing and reads on V2 for the agreed soak window with the divergence metric alarmed. Only after a clean soak stop the dual-write, then retire the V1 store (its own `V2-only → V1-deleted` ledger step with evidence).

**Schema-changed-mid-window hazard.** If the V1 schema (or the mapping) changes after backfill started, every already-ported key was mapped by the old transform and is now wrong. Re-backfill the affected range from a reset checkpoint; a mid-window mapping change without a re-backfill is detector 7.

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

A cutover runbook + a readiness verdict, written to `ai/runbooks/migration-cutover-<feature>.md` and reflected in the ledger row:

- **Source-of-truth choice** for the window, with the reason.
- **Backfill checkpoint / progress** — last committed cursor, keys ported / total, resumable-from-here.
- **The reconciliation query + its result** — counts per range, checksum/sample-diff, the divergence number.
- **Read-flip gate status** — `BLOCK` until backfill 100% AND divergence ≤ threshold; `CLEAR` with both cited. Default is BLOCK.
- **Rollback path** — the single-step flag flip back to V1, verified reversible, with V1 confirmed still warm via dual-write.

Closure verbs: `BLOCK cutover` (gate red — name the missing checkpoint/reconciliation), `CLEAR cutover` (both cited green), `RE-BACKFILL <range>` (mid-window drift), `RECONCILE` (audit missing). Every verb names the artifact that clears it.

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

- `parity-test-generate.md` (skill) — COMPARES V1/V2 *outputs* against identical inputs; this skill PORTS + reconciles the *stores*. You need both — a green parity suite over an empty V2 store still fails at read-cutover.
- `migration-discipline.md` (rule) — mandates the checkpointed backfill + reconciliation and the backfill-complete + reconciliation-green read-cutover gate this skill executes.
- `feature-port.md` (pattern) — the per-feature lifecycle whose cutover phase this skill fills.
- `database/ai-patterns/migrations.md` (cross-pack, boundary) — owns SINGLE-STORE schema evolution in place (expand-contract, online DDL); this skill owns the CROSS-STORE seam. One store → hand off there.
- `parity-auditor.md` (agent) — consults this skill's readiness verdict (default `BLOCK`) before advancing the ledger row through cutover.
