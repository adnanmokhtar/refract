---
description: One-shot per-phase alignment runner. After /align-scan + /align-plan, executes phase N — runs DETECT → DECIDE → FIX → VERIFY → RECORD per row in parallel waves, then auto-runs /align-gate <N>. Auto-routes per row (trivial/standard → standard find-and-align loop; heavy → supervised loop with reviewer pause). Same discipline, same artifacts, same closure-verb vocabulary as the manual flow — but parallel and unattended. Built for routine alignment sweeps where serial wall-time and human-watch pauses are the bottleneck. Mirrors /migration-fast.
kind: command
pack: align
---

# /align-fast <N>

## The Premise (read this first)

**One command. Align the entire phase in parallel, no human-watch pauses.** This command is the fast path for ANY phase — it collapses the two-step intended flow (`/align-phase <N>` → `/align-gate <N>`) into a single invocation that runs every row, regardless of tier, in parallel waves respecting the dependency graph.

**The "fast" in fast** = (a) parallel dispatch — multiple sub-agents work the phase simultaneously, respecting `scope` overlaps; (b) automatic tier routing — trivial/standard rows go through the standard `find-and-align` loop, heavy rows go through the supervised loop, all dispatched by fast itself with no user choice required between commands; (c) lenient pre-flight — the run starts unless something is genuinely broken (missing oracle / missing scan / missing plan).

**Nothing is skipped.** Every discipline check from the manual flow still runs:
- Every row still gets DETECT → DECIDE → FIX → VERIFY → RECORD.
- VERIFY still runs lint + typecheck + scoped tests + re-detect; coverage still must NOT drop.
- Frontend phases still run a11y / visual / bundle-size regression checks.
- `/align-gate <N>` still runs at the end with the full 14-check matrix.
- Heavy-tier rows still require reviewer approval before merge — fast surfaces them and pauses the row for approval (the rest of the phase continues).
- Halts still surface to `ai/align/halts/<row-id>.md` per row — they don't halt the whole run, but they do block that specific row from advancing until the user resolves.

**What it removes** is the wall-clock waste between steps — the human-watch pauses, the manual checkpoints, the "run command, wait, run next command, wait, run next" cycle. AND the artificial sequential bottleneck — independent rows in the same phase run in parallel.

This command runs **one phase**. Scan + plan are pre-requisites (just like `/migration-fast`). For the full sweep, run `/align-scan` once, `/align-plan` once, then `/align-fast 1`, `/align-fast 2`, ... per phase, ending with `/align-final`.

The existing multi-step flow (`/align-phase` → `/align-gate`) is **untouched**. Reach for it when you specifically want to inspect findings before any fix, supervise per-row, or run the gate manually.

## When to use vs not

**USE `/align-fast <N>`** for any phase you want to drive end-to-end without supervision. Routine mechanical phases (dead code, silent catches) are the highest-value targets — they're tedious to step through manually.

**USE the manual flow** (`/align-phase` → `/align-gate`) when you specifically want:
- To inspect each finding before any code is touched (`--dry-run` mode in `/align-phase`).
- To supervise heavy-tier rows per-row.
- To run the gate as a separate CI step.

Fast mode does NOT silently downgrade heavy → trivial. Heavy rows still get the supervised loop — fast just dispatches that loop in parallel with the trivial/standard rows of the same phase instead of forcing the user to run them separately afterward.

## What happens per row (full lifecycle)

Fast dispatches the per-finding loop per row. Read this so you can verify fast doesn't just "delete code":

### 0. Pre-flight (mandatory)

Before any row runs:
- `_extracted-idioms.md` not empty (oracle exists).
- Mechanical pass at HEAD: lint, typecheck, build, tests all green.
- No uncommitted changes.
- Plan + ledger exist; phase N has rows with `status: detected`.

If any pre-flight fails → halt the entire run; surface remediation.

### 1. DETECT (re-verify fingerprint)

**Cache reuse**: by default, rows at `status: verified` are skipped — their last-detect verdict is trusted. Rows at `status: detected` / `in-progress` / `halted` / `failed` always get a fresh detector dispatch. Pass `--re-audit` to force re-dispatch on **every** row including `verified` ones (use this when you suspect a row was falsely-verified or has rotted since the gate).

For each row needing detection (in dependency order — helper-introduce before consumer-swap):
- Re-read the row's `evidence` lines.
- Confirm the fingerprint pattern still matches.
- If fingerprint gone → mark `archived-pre-existing` (or stay `verified` if `--re-audit` and was previously verified); skip.
- If fingerprint moved → update `evidence` to new line; proceed.
- If fingerprint reappears on a previously-`verified` row (`--re-audit` only) → flip to `halted` with reason `false-verified-or-drift`; fast re-fixes it in step 3.
- If `shared_equivalent` doesn't resolve → halt; route to `/setup-project --refine`.

### 2. DECIDE (closure verb in vocabulary)

- Confirm closure verb ∈ `{remove, inline, dedupe, rename-comment-out, replace-with-shared}`.
- Confirm fix is behaviour-preserving (the row's class is not "bug" / "feature" / "perf").
- For `replace-with-shared`: re-confirm `shared_equivalent` exists.
- For `inline`: re-grep call sites; if 2+ found, halt (mis-classified).
- For `remove` on exported symbol: re-grep inbound imports; if any found, halt (mis-classified).

### 3. FIX (mechanical edit)

Apply the closure-verb edit per the row's `scope`:
- Touch only files in `scope`.
- Net-lines for the row's diff ≤ 0 (cumulative across all evidence sites).
- For `replace-with-shared` first site: net may be +1 (shared import); subsequent sites must net negative.

Validators run inline:
- `check_no_new_symbols` — `git diff --diff-filter=A` after FIX shows no new public exports.
- `check_scope_boundary` — `git diff --name-only` shows touched files ⊂ row.scope.

### 4. VERIFY (4 universal checks + 3 frontend checks)

1. Lint + typecheck on touched files (project commands).
2. Scoped tests (`<test-runner> <touched-files>`).
3. Re-detect at evidence lines (must return 0 hits).
4. Coverage non-decreasing.

For `PROJECT_KIND in {frontend-*}`:
5. a11y regression scoped to touched routes.
6. Visual regression scoped to touched components.
7. Bundle-size delta ≤ +1% per row.

Any fail → halt the row; revert; mark `status: halted`; write `ai/align/halts/<id>.md`; continue with remaining rows.

### 5. RECORD (one commit per row)

- Update ledger row: `status: fixed`, `fixed_at`, `commit`, `gaps_closed`, `notes`.
- Commit: `align/<phase-N>/<row-id>: <one-line description>`.
- Heavy-tier row: pause for reviewer approval; commit is created but ledger `notes` requires approval timestamp before the row's `status` flips.

## Parallel dispatch strategy

The fast command dispatches rows in parallel waves:

```
Wave 1: rows whose scope files don't overlap with any other unfixed row in phase N
Wave 2: next batch of non-overlapping rows
Wave 3: ...
```

Within a wave, up to `--max-parallel` rows run concurrently (default: 5). Rows whose `scope` overlaps with another in-progress row serialise.

Heavy-tier rows always run serially (one at a time, with reviewer-approval pause between).

**Concurrency cap rules:**
- Default `--max-parallel=5` for trivial-tier rows.
- Standard-tier rows cap at 3 concurrent (heavier diff per row; review attention preserved).
- Heavy-tier rows always serial.
- If the phase has only heavy rows, serial = the run.

## Project-specific anchors

> - **PROJECT_KIND**: `<extracted>`
> - **Test runner**: `<extracted>`
> - **Lint command**: `<extracted>`
> - **Typecheck command**: `<extracted>`
> - **Coverage command**: `<extracted>`
> - **a11y command** (frontend): `<extracted>`
> - **Visual regression command** (frontend): `<extracted>`
> - **Bundle-size command** (frontend): `<extracted>`
> - **Detector commands per class**: `<extracted from /align-scan dispatch table>`
> - **Reviewer designation** (for heavy rows): `<extracted from team config>`

## Optional flags

- `--max-parallel=<N>` — cap parallel row dispatch (default: 5 trivial; standard cap at 3; heavy always serial). Per-file lock prevents two rows from racing on the same file (see `align-discipline.md § Realism guards § Parallel race serialization`).
- `--scope=<path>` — limit row dispatch to rows whose `scope` files are inside the given path. Useful for incremental phase runs on large monorepos. Rows outside the scope stay `status: detected` for the next run.
- `--exclude-tier=<list>` — skip tiers (e.g., `--exclude-tier=heavy` for "trivial + standard only" — heavy rows are deferred to a follow-up `/align-phase <N> --start-from=<id>` run).
- `--re-audit` — discard cached `status: verified` verdicts and re-dispatch the detector for **every** row in phase N (including verified ones). Default: skip verified rows. Use this to verify done work is still correct — catches drift, false-verified rows, detector improvements that surface previously-missed gaps. Re-detected rows whose fingerprint reappears flip to `halted` and fast re-fixes them in the same run. Re-detected rows whose fingerprint stays absent stay `verified` (no code change). Mirrors `/migration-fast --re-audit`.
- `--dry-run` — run DETECT only, surface what would happen, no edits or commits.
- `--allow-main` — run on main / master branch (default: refuse).
- `--gate-strict` — refuse the gate on any check failure (default behaviour); included for explicitness.

## Pre-requisites (only the substantive ones — fast mode is lenient by default)

**Hard pre-requisites** (halt the run — these are real blockers):
1. `ai/align/ledger.md` exists (produced by `/align-scan`).
2. `ai/align/plan.md` exists; phase N exists in plan (produced by `/align-plan`).
3. `_extracted-idioms.md` exists and is non-empty (the oracle).

**Soft pre-requisites** (warn + proceed — fast mode does NOT halt on these):
- Dirty working tree (`git status --porcelain` non-empty) — warn only; the per-row commits will include the dirty changes only if they're inside a row's `scope`.
- Mechanical red at HEAD (lint / typecheck / build / tests failing) — warn only; per-row VERIFY will catch real regressions.
- Required detector tools missing — warn only; per-row DETECT halts the row but the rest continue.

If a hard pre-requisite (1–3) fails → halt with a one-line remediation pointer.

## Phase 1 — Understand (the ask)

Inputs:
- `<N>` — the phase number to run.
- All optional flags above.

## Phase 2 — Organize (decompose the work)

```
1. PRE-FLIGHT     — verify hard pre-reqs (scan + plan + valid N + oracle); warn on dirty tree
2. AUDIT-ALL      — re-detect each row's fingerprint in parallel
3. TIER TRIAGE    — split rows into waves (trivial, standard, heavy)
4. PARALLEL CHAIN — per-row dispatch in dependency waves (find-and-align skill)
5. AUTO-GATE      — /align-gate <N>
```

## Phase 3 — Retrieve (read the right context)

- `align-discipline.md`
- `_extracted-idioms.md`
- `_extracted-codebase.md` (PROJECT_KIND for stack-conditional VERIFY)
- Plan + ledger
- Per-class detector tools (re-detect at VERIFY time)

## Phase 4 — Generate (produce the output)

Per-row output streams to a phase-level log at `ai/align/runs/<YYYY-MM-DD-HHMMSS>-phase-<N>.log`. End-of-phase summary surfaces to user (same shape as `/align-phase` end-of-phase summary, with a "fast mode" line indicating parallel waves).

End-of-phase summary:

```
Align fast — phase <N> — <PASS | PARTIAL | FAIL>

Theme: <theme from plan>
Pre-flight:                    PASS
Total rows in phase:           <N>

Tier triage:
  Trivial:                     <T>
  Standard:                    <S>
  Heavy:                       <H> (each runs serially with reviewer pause)

Parallel waves dispatched:     <W>
  Wave 1: <K> rows in parallel
  Wave 2: <K> rows in parallel
  ...

Per-row outcomes:
  Fixed:                       <F>
  Archived (pre-existing):     <A>
  Halted:                      <Hl>
  Parked (via /align-park):    <P>

Cumulative diff:               +<X> / -<Y> = -<Z>
  Structural net:              -<S>  (≤ 0 by rule)
  Functional net:              +<F>  (idiom-cited)

Mechanical:
  Lint:                        PASS
  Typecheck:                   PASS
  Scoped tests:                PASS (<X> tests, <Y>ms)
  Coverage:                    <pre>% → <post>%

(Frontend phases only)
  a11y regression:             PASS
  Visual regression:           <D> diffs accepted
  Bundle-size delta:           +<%>

Auto-gate (/align-gate <N>):   <PASS | REFUSE>
  → On PASS: phase <N> rows flipped to status=verified; gate-history appended.
  → On REFUSE: phase stays in-progress; halts surface.

Wall-clock:                    <hh:mm:ss>

Next:
  /align-fast <N+1>            (next phase) — IF gate PASSED
  /align-status                (review halts) — IF gate REFUSED
  /align-final                 (only if N is the last phase)
```

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/align/runs/<timestamp>-*.log` — per-phase log.
- `ai/align/ledger.md` — updated per row.
- `ai/align/gate-history.md` — appended per phase that PASSed.
- `ai/align/halts/` — populated per halted row.
- `ai/index.md` — entry pointing to the latest run.

## Phase 6 — Validate (verify correctness)

- Pre-flight green.
- Every row in scope of the run has either advanced (`status: fixed | archived | parked`) OR halted (`status: halted`) — no row is left in `in-progress`.
- Every PASSed phase has gate-history entry.
- Every halted row has `ai/align/halts/<id>.md`.

## Phase 7 — Improve (feed the learning loop)

- If the same row halts repeatedly across runs → surface "row mis-classified at scan; route to `/refactor`".
- If the gate REFUSES on the same check in 2+ phases → surface "discipline drift in check X; team should align".
- If `--max-parallel` saturates (all rows serialise on overlapping scopes) → the scan's scoping is too coarse; queue review.
- If a heavy row sits awaiting reviewer approval > 24h → surface "blocking; route to /align-park or assign reviewer".

## Mechanical halt — refuse to skip discipline for speed

The fast command does NOT:
- Skip VERIFY because "tests are slow".
- Pass the gate because "most checks passed".
- Bundle multiple rows into one commit to "speed up".
- Modify the oracle to "make a row pass".
- Continue past a phase whose gate REFUSED (the run halts).
- Auto-merge heavy rows without reviewer approval.
- Run on main / master without explicit `--allow-main`.

The discipline IS the speed — same artifacts, same gate, parallel where safe.

## Hard rules (inherited from align-discipline)

- **Closure verbs are mechanical.** No new abstractions.
- **Net-lines ≤ 0 per row, per phase.**
- **One finding = one commit.**
- **Re-detect after every fix.**
- **Coverage non-decreasing.**
- **Frontend regressions green.**
- **Oracle stays read-only.**
- **Heavy-tier rows reviewed before merge.**
- **Gap-count parity** (`gaps_in == gaps_closed`).

## Failure modes

- **Hard pre-flight halts the whole run.** `/align-scan` not run, `/align-plan` not run, oracle missing, invalid phase N. Fix the underlying issue and re-run.
- **Soft pre-flight warns + proceeds.** Dirty tree, mechanical red at HEAD, missing detector tool — all warn only. Per-row VERIFY catches real regressions.
- **A row's halt blocks only that row.** Other rows continue; the gate at end of phase REFUSES because the halt is unresolved; user fixes and re-runs `/align-gate <N>` directly OR re-runs `/align-fast <N>` after resolving.
- **A phase's gate REFUSES.** The phase stays in-progress; user resolves halts then re-runs `/align-gate <N>` to retry the gate (or re-runs `/align-fast <N>` for a full re-pass). Move to next phase only after gate PASSes.
- **Concurrency conflicts** — two rows write the same file. Validator detects; second writer waits OR halts depending on lock semantics. Default: serialise within the file.
- **Reviewer pause for heavy row** — the run pauses (or surfaces a "needs approval" notification) but doesn't halt the whole run; trivial/standard rows of the same phase complete.
- **Detector tool flaky** — re-detect returns inconsistent results across runs; treat as fail (conservative); investigate tool config.

## Related

### Sibling commands in align pack
- `/align-scan` — produces the ledger (run once before phase 1).
- `/align-plan` — produces the phased plan (run once after scan).
- `/align-phase <N>` — manual per-phase variant.
- `/align-gate <N>` — runs at end of this command.
- `/align-final` — final cross-phase verification (run after the LAST phase's gate PASSes).
- `/align-rollback <N>` — undoes a phase if rethink needed.
- `/align-park <id>` — parks a halted row.
- `/align-status` — read-only progress reader.

### Skills
- `.claude/skills/find-and-align.md` — the per-finding loop dispatched per row.
- `.claude/skills/detect-drift.md` — re-detect procedure.

### Cross-pack references
- `migration/commands/migration-fast.md` — sibling pattern; this command mirrors its parallel-dispatch + same-discipline approach.
- `code-quality/commands/check-health.md` — pre-flight mechanical check; runs as part of pre-flight here.

### Rules
- `.claude/rules/align-discipline.md` — the discipline this command enforces.

### Patterns
- `ai/patterns/align-ledger.md` — ledger schema.
