---
description: Regenerate the phased alignment plan from the current ledger state. Run when the original plan has aged out (codebase changed, new findings surfaced, prior phases revealed wrong sequencing, parked findings accumulated). Preserves `verified` rows; recomputes phasing for the rest. Mirrors /migration-replan.
kind: command
pack: align
---

# /align-replan

## The Premise (read this first)

**Read before writing. Cite real findings, never invented.** Replan reads the current `ai/align/ledger.md` + `ai/align/gate-history.md` + `ai/align/rollback-history.md` and rewrites `ai/align/plan.md` — preserving every `verified` row's original phase number and re-phasing only the rest. Every re-phased row's `evidence` must still resolve at HEAD (re-detect at scope-of-one). Don't paraphrase from memory.

The plan written on day 1 doesn't survive contact with reality. By phase 3, the codebase has changed, new findings may have surfaced, parked findings may have piled up. Replan reads the current ledger and produces a fresh plan for everything still in flight.

## When to use

- A phase took 3× longer than estimated → other phase estimates need recalibration.
- New findings landed (e.g., a recent feature merge introduced drift) → ledger has new `detected` rows that need phasing.
- A phase revealed a hidden dependency between findings → reorder.
- After `/align-rollback <N>` → previous plan's assumptions are stale.
- After `/align-park <id>` accumulated 5+ parked rows → re-plan once they're unparked OR explicitly excluded.
- After `/setup-project --refine` updated `_extracted-idioms.md` → idiom-gaps that halted previous phases may now be resolvable.

## When NOT to use

- A single finding failed → use `/align-phase <N> --start-from=<id>` to retry.
- The plan is fresh (run today) → no replan needed.
- Mid-phase, with rows in `in-progress` → finish or rollback the active phase first.

## Pre-requisites

- `ai/align/ledger.md` exists.
- `ai/align/plan.md` exists (replan rewrites it).
- No `in-progress` rows (the active phase is settled).

If pre-requisites missing → halt + report.

## Phase 1 — Understand (the ask)

Inputs:
- `ai/align/ledger.md` — current finding inventory + status.
- `ai/align/plan.md` (existing) — the plan being replaced.
- `ai/align/gate-history.md` — phases that passed (those rows stay verified).
- `ai/align/rollback-history.md` — phases rolled back (those rows return to `detected`).
- `ai/align/halts/parked/` — parked findings registry.

Optional flags:
- `--re-scan-first` — runs `/align-scan --since=<last-scan-commit>` before replanning. Use when the codebase has changed materially since the last scan (new modules, refactors, new dependencies).
- `--include-drifted` — re-phase rows whose `idiom_cited` references a changed oracle entry (per `align-scan`'s "Idiom drift detected" output). Rows referencing changed idioms get re-evaluated. `verified` rows flip to `detected` ONLY if the change materially affects them (renamed / signature change / removed); cosmetic changes leave verified rows alone. Use after `/setup-project --refine` updated `_extracted-idioms.md`.
- `--phases=<N>` — target number of remaining phases.
- `--preserve-verified` (default `true`) — keep `verified` rows in their original phase numbers; renumber only future phases.
- `--include-parked` — include `parked` rows in the new plan (default: parked rows stay parked; `--include-parked` revives them as `detected`).
- `--max-findings-per-phase=<N>` — cap per phase (default: 12).
- `--strategy=<class|domain|mixed>` — phasing strategy (default: same as original plan).

## Phase 2 — Organize (decompose the work)

**Dispatch `@align-ledger-auditor` first.** Replanning on top of a drifted ledger re-phases fiction: a row marked `verified` with no commit keeps its phase number and is never revisited. The reconciliation runs before categorisation, and any drift it reports is resolved (or explicitly accepted in `notes`) before the new plan is written. Under `--include-drifted`, dispatch `@align-evidence-auditor` over the rows whose `idiom_cited` references a changed oracle entry — a citation that no longer resolves is a `REJECT`, and the row returns to `detected` rather than being re-phased as if it were still closable.

Replan strategy:

1. **Categorize ledger rows by status:**
   - `verified` (phase gated PASS) → preserve in their original phase numbers.
   - `fixed` (closed but gate hasn't run yet) → preserve in their phase; the gate will run when the phase is closed.
   - `parked` → exclude from plan (default) OR include if `--include-parked` (with rationale logged).
   - `archived-pre-existing` → exclude from plan (no-op rows).
   - `archived-deprecated` → exclude from plan (decided not to fix).
   - `detected`, `in-progress`, `halted` → re-phase.

2. **Re-detect at scope-of-one for each re-phasable row.** A finding can age out — another PR may have already fixed it. Run the row's detector against its evidence; if 0 hits, mark `archived-pre-existing` and exclude from plan.

3. **Re-evaluate dependency graph** for the rows being re-phased. Dependencies may have shifted (a new shared helper landed; an idiom gap closed via `/setup-project --refine`).

4. **Honor failures-learned.** If `gate-history` shows phase N rolled back due to "scope creep on shared module," the replanned phase 1 captures the lesson (e.g., split the shared-module rows into a dedicated phase).

5. **Cap phase size** per `--max-findings-per-phase`.

6. **Mechanical-first ordering preserved** — even after replan, phase 1 is mechanical (dead code / silent catches) unless every mechanical finding is already verified.

## Phase 3 — Retrieve (read the right context)

- All ledger rows.
- Gate-history.
- Rollback-history.
- Park registry.
- (If `--re-scan-first`) the scan output.

## Phase 4 — Generate (produce the output)

Write the new `ai/align/plan.md` with:
- Verified rows in their original phase numbers (preserved).
- Re-phasable rows in new phase numbers (renumbered if `--preserve-verified=false` OR if the original phase was rolled back).
- Parked rows in a "Deferred" section (informational; not in any phase unless `--include-parked`).
- Archived rows in an "Archived" section (informational).

Update `ai/align/ledger.md`:
- Each re-phased row's `phase` field updated.
- A `replan_at: <iso>` field added to each re-phased row.
- A `replan_count: <N>` counter incremented.

## Phase 5 — Update (persist changes)

- `ai/align/plan.md` — rewritten.
- `ai/align/ledger.md` — phase fields updated for re-phased rows.
- `ai/align/_history.md` — append one line: `<iso> replan | preserved=<P> repahased=<R> deferred=<D>`.

## Phase 6 — Validate (verify correctness)

- Every verified row's `phase` field unchanged from the original plan.
- Every re-phased row has `phase: <N>` and `status` ∈ `{detected}`.
- No row has both `phase: <N>` AND `status: parked` (parked rows aren't in any phase).
- Phase 1 contains mechanical findings if any mechanical findings are still re-phasable.
- No phase exceeds `--max-findings-per-phase`.

If any check fails → halt + report.

## Phase 7 — Improve (feed the learning loop)

- If a row has `replan_count > 3`, surface "row chronically un-fixable; consider `/align-park` with rationale OR re-classify".
- If the same class is re-phased > 2× in a row, surface "phasing strategy may be wrong for this class".
- If parked rows accumulated > 10, surface "consider `/setup-project --refine` if blockers are idiom-gaps; OR `/align-deprecate` for never-fix decisions".

## Output to user

```
Align replan complete:
  Verified rows preserved:    <V>
  Re-phased rows:              <R>
  Newly-archived (re-detect):  <A>  (fingerprint absent at scope-of-one)
  Parked (excluded from plan): <P>
  Excluded (deprecated):       <D>

Plan now has <K> phases (was <K0>).
Phase 1: <theme>, <N> findings.
Phase 2: <theme>, <N> findings.
...

Next: /align-phase 1   OR   /align-fast 1
```

## Hard rules

- **`verified` rows are immutable.** Replan never re-phases a verified row. Use `/align-rollback <N>` first if a verified phase needs re-doing.
- **Re-detect every re-phased row.** Plan rows must reflect current reality; aged-out fingerprints become `archived-pre-existing`.
- **No silent re-phasing.** Every change is logged in `_history.md` + the row's `replan_at` field.
- **Parked rows stay parked** (default). Use `--include-parked` to revive; the parked rationale carries forward into the new plan's notes.

## Failure modes

- **Active phase has in-progress rows** — refuse; finish or rollback the active phase first.
- **Replan changes a verified row's phase** — bug in the implementation; halt; surface.
- **All re-phasable rows turn out to be archived-pre-existing** — surface "alignment complete; no work left in plan; consider running `/align-final`".

## Related

### Agents
- `.claude/agents/align-ledger-auditor.md` — reconciles the ledger before it is re-phased; replanning on drifted state re-phases fiction.
- `.claude/agents/align-evidence-auditor.md` — dispatched under `--include-drifted` over rows whose `idiom_cited` no longer resolves.

### Sibling commands in align pack
- `/align-scan` — produces the ledger (run with `--since=<commit>` to update incrementally).
- `/align-plan` — produces the original plan.
- `/align-rollback <N>` — undoes a phase before replan.
- `/align-park <id>` / `/align-unpark <id>` — manage parked rows.
- `/align-status` — read state before replan.

### Cross-pack
- `migration/commands/migration-replan.md` — sibling pattern; this command mirrors it.

### Rules
- `.claude/rules/align-discipline.md` — the discipline this command enforces.
