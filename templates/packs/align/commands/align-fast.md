---
description: "Runs one align phase unattended: find-and-align per row in parallel waves (disjoint scopes, serial commit queue), the sweep gate after every wave, then /align-gate. Halts on a dirty tree or red CI."
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /align-fast <N>

**Discipline pointer:** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) — SOLID / clean-code closure vocabulary (single source of truth).

## The Premise (read this first)

**One command. Align the entire phase in parallel, no human-watch pauses.** This command is the fast path for ANY phase — it collapses the two-step intended flow (`/align-phase <N>` → `/align-gate <N>`) into a single invocation that runs every row, regardless of tier, in parallel waves respecting the dependency graph.

**The "fast" in fast** = (a) parallel dispatch — multiple sub-agents work the phase simultaneously on rows whose `scope` sets are disjoint; (b) automatic tier routing — trivial/standard rows go through the standard `find-and-align` loop, heavy rows go through the supervised loop, all dispatched by fast itself with no user choice required between commands. **The pre-flight is not lenient.** A dirty tree or a red mechanical baseline halts the run before any row starts: parallel, unattended edits on top of either cannot be attributed or verified (`ai/patterns/align-guardrails.md` § dirty-tree behaviour, mechanical-red short-circuit).

**Nothing is skipped.** Every discipline check from the manual flow still runs:
- Every row still gets ROUTE → DETECT → DECIDE → FIX → VERIFY → RECORD (`find-and-align`), with the full proof ladder L0–L13.
- The **sweep gate** runs after every wave over the whole run so far: one way per pattern (AL-33), line-level scope (AL-34), test and snapshot lock, emitted names.
- EQ rows still prove a zero computed-style diff; VC rows stop at `pending-approval` until a human signs.
- `/align-gate <N>` still runs at the end with the full 17-check matrix.
- Heavy-tier rows still require reviewer approval before merge — fast surfaces them and pauses the row for approval (the rest of the phase continues).
- Halts still surface to `ai/align/halts/<row-id>.md` per row — they don't halt the whole run, but they do block that specific row from advancing until the user resolves.

**What it removes** is the wall-clock waste between steps — the human-watch pauses, the manual checkpoints, the "run command, wait, run next command, wait, run next" cycle. AND the artificial sequential bottleneck — independent rows in the same phase run in parallel.

This command runs **one phase**. Scan + plan are pre-requisites (just like `/migration-fast`). For the full sweep, run `/align-scan` once, `/align-plan` once, then `/align-fast 1`, `/align-fast 2`, ... per phase, ending with `/align-final`.

The existing multi-step flow (`/align-phase` → `/align-gate`) is **untouched**. Reach for it when you specifically want to inspect findings before any fix, supervise per-row, or run the gate manually.

## When to use vs not

**USE `/align-fast <N>`** for any phase you want to drive end-to-end without supervision. Routine mechanical phases (raw imports moved onto a named wrapper, EQ token snaps, renames under a declared naming rule) are the highest-value targets — they're tedious to step through manually.

**USE the manual flow** (`/align-phase` → `/align-gate`) when you specifically want:
- To inspect each finding before any code is touched (`--dry-run` mode in `/align-phase`).
- To supervise heavy-tier rows per-row.
- To run the gate as a separate CI step.

Fast mode does NOT silently downgrade heavy → trivial. Heavy rows still get the supervised loop — fast just dispatches that loop in parallel with the trivial/standard rows of the same phase instead of forcing the user to run them separately afterward.

## What happens per row (full lifecycle)

Fast dispatches the per-finding loop per row. Read this so you can verify fast doesn't just "delete code":

### 0. Pre-flight (mandatory — any failure halts the whole run)

Before any row runs:
- **The oracle resolves.** `convention-oracle` § 0 builds the oracle map (`oracle-map.py`); the wrapper inventory comes from the fallback order `.claude/_extracted-idioms.md` → `.claude/codebase-profile.md` → `ai/conventions.md`. Every row's `oracle:` quote must still be found (L0); a row whose quote is gone halts as `oracle-gone`, the rest continue.
- **Mechanical green at HEAD.** Lint, typecheck (`tsc --noEmit --incremental false`), build and tests. Red halts the run: a row's VERIFY cannot tell its own regression from the baseline's.
- **Clean tree.** `git status --porcelain` empty. Dirty halts the run: a row's commit would sweep in edits nobody can attribute, and the sweep gate's scope check would measure them as the row's.
- Plan + ledger exist; phase N has rows at `planned` or `detected`.
- The tools the ladder needs: `align-sweep-gate.py` (`find-and-align`'s script); `token-map.py` when the ui-ux pack is installed (without it, token rows stay VC and L8 is `NOT RUN`).

### 1. Per row — `find-and-align`

Each row runs the skill exactly as `/align-phase` runs it: **ROUTE** (an owner row moves to `routed (<command>)` with no commit; a T2g oracle moves to `pending-ratification`), **DETECT** (re-run the row's `detector_cmd`; 0 hits with the rule matching files → `archived-pre-existing`; a rule matching 0 files halts `re-detect-vacuous`), **DECIDE** (proof class EQ / VC / FN; `@align-idiom-auditor` before any edit), **FIX** (rule first where expressible; only the matched expression and the verb's footprint; tests, snapshots, fixtures, the class's lint config and baselines read-only), **VERIFY** (the ladder: `align-sweep-gate.py ladder` plus L9, L10a / L10b, L12), **RECORD**.

**Cache reuse**: rows at `status: verified` are skipped by default; `--re-audit` re-runs DETECT on every row, and a reappearing fingerprint flips the row to `halted` (`false-verified-or-drift`) for a re-fix in the same run.

Any ladder FAIL → the row reverts, `status: halted`, `ai/align/halts/<id>.md` gets the failing step and its ladder line; the other rows continue.

### 2. RECORD — one commit per row, through the commit queue

- Ledger row: `status: fixed`, `fixed_at`, `commit`, `gaps_closed`, `proof_class`, `proof` (the V-numbers that passed and `$RUN/ladder-<id>.json`); `approval:` only as a human wrote it.
- Commit subject: `align/<phase-N>/<row-id>: <one-line description>`.
- Heavy-tier row: `pending-review`; the commit exists, the row waits for `reviewer_approval`.

## Parallel dispatch strategy and isolation

Rows run in waves. A wave holds rows whose `scope` sets are **disjoint** (no shared file, no file under another row's scope directory); a row overlapping a running row waits for the next wave. Rows with an empty `scope` never run in parallel: no scope means nothing to lock.

```
Wave 1: rows with disjoint scopes                → sub-agents (Task), up to --max-parallel
        commit queue: one committer, ledger order → align/<N>/<id> commits
        SWEEP GATE over the run so far            → FAIL reverts the offending rows, the wave's others stand
Wave 2: next disjoint set …
```

**Isolation.** Two `git commit`s on one index race, and a "file lock" written into a prompt is not a lock. So sub-agents **edit and verify; they do not commit and do not write the ledger.** Each returns its diff's file list and its RECORD fields. The command itself is the **single committer**: in ledger order, it checks the row's changed files ⊂ its `scope`, stages exactly those files plus the row's ledger update, and commits. Two rows of one wave never share a file, so their edits cannot interleave. A tool with no sub-agent primitive gets the same guarantee from `scripts/align-parallel.sh`, which refuses overlapping scopes and runs either one git worktree per row with a serial integration queue (`--isolation=worktree`, the default) or the same serial commit queue (`--isolation=serial`).

**The sweep gate per wave.** After each wave's commits, run the run-level steps over the phase so far:

```bash
G=$(find .claude/skills -path '*/find-and-align/scripts/align-sweep-gate.py' 2>/dev/null | head -1)
for c in consistency scope lock-paths names ratchet; do
  GIT_OPTIONAL_LOCKS=0 TMPDIR="$RUN" python3 -I "$G" "$c" --repo=. --base="$PHASE_BASE" --ledger=ai/align/ledger.md --json > "$RUN/sweep-w$W-$c.json"
  echo "wave $W $c exit $? (0 PASS · 1 FAIL · 4 NOT RUN)"; done
```

`consistency` is AL-33: one before-value resolved to two after-values across two rows of different waves fails here and nowhere else. A FAIL reverts the rows the gate names (newest first), halts them with the gate line, and the run continues with the next wave.

**Concurrency caps.** `--max-parallel=5` for trivial rows, 3 for standard, heavy rows always serial with the reviewer pause. If the phase has only heavy rows, serial is the run.

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

- `--max-parallel=<N>` — cap parallel row dispatch (default: 5 trivial; standard cap at 3; heavy always serial). Rows in one wave never share a file; commits go through the single commit queue (§ Parallel dispatch strategy and isolation).
- `--scope=<path>` — limit row dispatch to rows whose `scope` files are inside the given path. Useful for incremental phase runs on large monorepos. Rows outside the scope stay `status: detected` for the next run.
- `--exclude-tier=<list>` — skip tiers (e.g., `--exclude-tier=heavy` for "trivial + standard only" — heavy rows are deferred to a follow-up `/align-phase <N> --start-from=<id>` run).
- `--re-audit` — discard cached `status: verified` verdicts and re-dispatch the detector for **every** row in phase N (including verified ones). Default: skip verified rows. Use this to verify done work is still correct — catches drift, false-verified rows, detector improvements that surface previously-missed gaps. Re-detected rows whose fingerprint reappears flip to `halted` and fast re-fixes them in the same run. Re-detected rows whose fingerprint stays absent stay `verified` (no code change). Mirrors `/migration-fast --re-audit`.
- `--dry-run` — run DETECT only, surface what would happen, no edits or commits.
- `--allow-main` — run on main / master branch (default: refuse).
- `--gate-strict` — refuse the gate on any check failure (default behaviour); included for explicitness.

## Pre-requisites (every one halts the run)

1. `ai/align/ledger.md` exists (produced by `/align-scan`).
2. `ai/align/plan.md` exists; phase N exists in plan (produced by `/align-plan`).
3. A declared convention resolves: the oracle map has at least one T1 or T2 row, and the inventory comes from the fallback order `.claude/_extracted-idioms.md` → `.claude/codebase-profile.md` → `ai/conventions.md`. A project that ships only `codebase-profile.md` runs (the old `_extracted-idioms.md`-only check halted the pack's own `web-dashboard` fixture).
4. Clean working tree (`git status --porcelain` empty).
5. Mechanical green at HEAD (lint, typecheck, build, tests).

A missing **tool** is not a pre-requisite: its ladder step prints `NOT RUN (<tool> not installed)`, which makes the row `[report-with-fix] (static EQ)` or Unconfirmed, never verified.

## Phase 1 — Understand (the ask)

Inputs:
- `<N>` — the phase number to run.
- All optional flags above.

## Phase 2 — Organize (decompose the work)

```
1. PRE-FLIGHT     — scan + plan + valid N + oracle map; clean tree; mechanical green (any failure halts)
2. ROUTE + DETECT — owner rows → routed; T2g → pending-ratification; re-detect the rest
3. WAVES          — disjoint-scope waves by tier (trivial, standard, heavy serial)
4. PER WAVE       — find-and-align per row (sub-agents) → commit queue → sweep gate
5. AUTO-GATE      — /align-gate <N>
```

## Phase 3 — Retrieve (read the right context)

- `align-discipline.md`
- The oracle map (`convention-oracle` § 0) and the inventory fallback (`_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`)
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
  Wave 1: <K> rows in parallel · sweep gate PASS (consistency 4 keys · scope · lock-paths · names)
  Wave 2: <K> rows in parallel · sweep gate FAIL consistency '#d92d20' → 2 afters (A031 reverted, halted)
  ...

Per-row outcomes:
  Fixed:                       <F>
  Archived (aged out):         <A>
  Routed (owner fix commands): <R>
  Pending approval (VC):       <V>
  Pending ratification (T2g):  <G>
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

Proof classes:
  EQ (zero diff):              <E>   (static EQ, runtime probe pending: <s>)
  FN (behaviour test):         <F>
  VC (approved visual diff):   <V-approved>; <V> waiting — never auto-accepted

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
- Every row in scope of the run has either advanced (`status: fixed | archived-pre-existing | routed | parked`), is waiting on a human (`pending-approval`, `pending-ratification`, `pending-review`) OR halted (`status: halted`) — no row is left in `in-progress`.
- Every wave has its sweep-gate files in `$RUN`; no commit outside the commit queue.
- Every PASSed phase has gate-history entry.
- Every halted row has `ai/align/halts/<id>.md`.

## Phase 7 — Improve (feed the learning loop)

- If the same row halts repeatedly across runs → surface "row mis-classified at scan; route to `/refactor`".
- If the gate REFUSES on the same check in 2+ phases → surface "discipline drift in check X; team should align".
- If `--max-parallel` saturates (all rows serialise on overlapping scopes) → the scan's scoping is too coarse; queue review.
- If the sweep gate's `consistency` fails twice on one key → the token map is not context-keyed for that value; route the key to a human decision, not a retry.
- If a heavy row sits awaiting reviewer approval > 24h → surface "blocking; route to /align-park or assign reviewer".

## Mechanical halt — refuse to skip discipline for speed

The fast command does NOT:
- Skip VERIFY because "tests are slow".
- Pass the gate because "most checks passed".
- Bundle multiple rows into one commit to "speed up", or let two sub-agents commit concurrently.
- Run on a dirty tree or a red mechanical baseline.
- Auto-accept a visual diff, or fill `approval:` itself.
- Modify the oracle to "make a row pass".
- Continue past a phase whose gate REFUSED (the run halts).
- Auto-merge heavy rows without reviewer approval.
- Run on main / master without explicit `--allow-main`.

The discipline IS the speed — same artifacts, same gate, parallel where safe.

## Hard rules (inherited from align-discipline)

- **Closure verbs are mechanical.** No new abstractions.
- **Net-lines ≤ 0 per row, per phase** (structural rows).
- **Tests, snapshots and baselines are read-only in an align commit.**
- **One way per pattern across the run** (the sweep gate).
- **One finding = one commit.**
- **Re-detect after every fix.**
- **Coverage non-decreasing.**
- **EQ by a zero diff, VC by a named approval.**
- **Oracle stays read-only.**
- **Heavy-tier rows reviewed before merge.**
- **Gap-count parity** (`gaps_in == gaps_closed`).

## Failure modes

- **Pre-flight halts the whole run.** `/align-scan` not run, `/align-plan` not run, no declared convention, invalid phase N, a dirty tree, red CI at HEAD. Fix the underlying issue and re-run.
- **A missing tool is a reduction, not a halt.** Its ladder step prints `NOT RUN`; the row cannot reach `verified` on that step.
- **A row's halt blocks only that row.** Other rows continue; the gate at end of phase REFUSES because the halt is unresolved; user fixes and re-runs `/align-gate <N>` directly OR re-runs `/align-fast <N>` after resolving.
- **A phase's gate REFUSES.** The phase stays in-progress; user resolves halts then re-runs `/align-gate <N>` to retry the gate (or re-runs `/align-fast <N>` for a full re-pass). Move to next phase only after gate PASSes.
- **Concurrency conflicts** — cannot happen inside a wave: rows sharing a file are never in one wave, and only the commit queue commits. A sub-agent that touched a file outside its row's scope is caught by the queue's scope check and the row halts.
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

### Agents
- `.claude/agents/align-idiom-auditor.md` — dispatched per row at DECIDE and VERIFY. The unsupervised path needs it most.
- `.claude/agents/align-gate-auditor.md` — runs the auto-gate at the end of this command; PASS/REFUSE is its verdict, not this command's.

### Skills
- `.claude/skills/find-and-align/SKILL.md` — the per-finding loop dispatched per row.
- `.claude/skills/align-detect/SKILL.md` — re-detect procedure.

### Cross-pack references
- `migration/commands/migration-fast.md` — sibling pattern; this command mirrors its parallel-dispatch + same-discipline approach.
- `scripts/align-parallel.sh` — the same isolation for tools without sub-agents (worktree per row, or a serial commit queue).
- `code-quality/commands/check-health.md` — pre-flight mechanical check; runs as part of pre-flight here.

### Rules
- `.claude/rules/align-discipline.md` — the discipline this command enforces.

### Patterns
- `ai/patterns/align-ledger.md` — ledger schema.
