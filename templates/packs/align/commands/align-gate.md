---
description: Phase exit gate. Reads ai/align/ledger.md + ai/align/plan.md, validates every row in phase N is status=fixed (or archived/parked), runs the 10-check matrix (gap-count parity, net-lines ≤ 0, no new symbols, no scope creep, test/coverage/lint/typecheck green, frontend regressions green). Read-only — never writes (except a one-line history entry).
kind: command
pack: align
---

# /align-gate <N>

## The Premise (read this first)

**The gate decides whether phase N can advance.** It is read-only: it does NOT fix findings, does NOT modify ledger rows, does NOT touch source. It validates that the phase met its exit criteria and writes a single history-entry line at `ai/align/gate-history.md`. If any check fails, the gate REFUSES — surfaces the failure, points to the remediation, and exits non-zero. The phase stays in the in-progress state until the user resolves the blocker (via `/align-phase` continuation, `/align-park`, or `/align-rollback`).

**Gates fail loudly. Silent passes are the failure mode.** Every check produces an explicit pass / fail line. Skipping a check (because the tool is unavailable, the test suite is slow, the visual regression baseline drifted) is a HALT, not a soft warning. The discipline is hard-edged on purpose — soft gates are how regressions ship.

## When to use

- After `/align-phase <N>` completes (or `/align-fast <N>` runs the gate automatically).
- Before merging the phase PR.
- As a CI step on every push to the phase branch.
- After `/align-park` or manual halt-resolution to confirm the phase is ready.

## When NOT to use

- Before `/align-phase` runs. The gate validates a completed phase, not a planned one.
- On a phase with uncommitted changes. Commit or stash first.
- During an active alignment run (gate is end-of-phase only).

## The 14-check matrix

The gate runs these 14 checks in order. The first failure surfaces; subsequent checks may run for additional context but the gate's verdict is REFUSE.

### Check 1 — Ledger completeness

Every row in `ai/align/ledger.md` with `phase: <N>` has `status ∈ {fixed, archived-pre-existing, parked}`. Any `detected` / `in-progress` / `halted` row is a refusal.

### Check 2 — Gap-count parity

For every `fixed` row, `gaps_closed == len(evidence)`. A row that closed 7 of 8 evidence sites is a refusal.

### Check 3 — Net-lines on structural rows ≤ 0

Run `git diff --shortstat <phase-base>..HEAD` filtered to commits whose row-id maps to a structural-class row. Lines-added must be ≤ lines-removed for the structural subset. Any net-positive structural diff is a refusal. Functional rows (security, perf, SOLID, clean-code) are exempt; their net-lines are governed by check 11 (idiom citation) instead.

### Check 4 — No new symbols (idioms-named exemption)

Run `git diff --diff-filter=A <phase-base>..HEAD -- '*.ts' '*.tsx' '*.js' '*.jsx' '*.py' '*.go' '*.rb'` (extension list per PROJECT_KIND); grep for new exports / public functions / public classes. For each new symbol, confirm it's named in `_extracted-idioms.md` (the idiom inventory). New symbols NOT named in idioms are a refusal — that's a Reinvented Wrapper / Reinvented Idiom.

### Check 5 — No scope creep

For every commit in the phase, parse the row-id from the commit message; cross-reference the ledger row's `scope` field; confirm `git show --name-only <commit>` only touched files in `scope`. Any out-of-scope file is a refusal.

### Check 6 — Mechanical pass (lint + typecheck + tests)

Run the project's lint / typecheck / test commands at HEAD. Any error is a refusal.

### Check 7 — Coverage non-decreasing (within tolerance)

Run scoped coverage at `<phase-base>` and at HEAD; coverage % at HEAD must be ≥ coverage % at base **minus the tolerance threshold** (default 0.5%; configurable per project in `ai/conventions.md § Coverage`). A drop within tolerance is sample fluctuation, not a real regression — passes. A drop beyond tolerance is a refusal. See `align-discipline.md § Realism guards § Coverage tolerance`.

(Security rows may shift coverage due to intentional behaviour change; the absolute % must still satisfy the tolerance rule. If a security row caused the drop, the test suite update should have offset it — investigate which test was deleted/skipped and re-add or update it.)

### Check 8 — Frontend regressions (frontend stacks only)

For `PROJECT_KIND in {frontend-*}`:
- a11y test suite at HEAD must be ≥ baseline (no score drop).
- Visual regression diffs reviewed and accepted (or zero diffs).
- Bundle-size at HEAD ≤ baseline + 1%.

Any regression is a refusal.

### Check 9 — Oracle unmodified

Run `git diff <phase-base>..HEAD -- '_extracted-idioms.md' 'ai/conventions.md' 'ai/architecture.md'`. Any non-empty diff is a refusal.

### Check 10 — Per-tier artifact set complete

For each fixed row:
- **trivial**: ledger row + commit (validated by checks 1, 5).
- **standard**: + `notes` field has 1-paragraph rationale (≤ 200 chars, > 20 chars).
- **heavy**: + `impact_analysis_path: ai/align/impact/<id>.md` resolves AND the file has ≥ 1 reviewer-approval timestamp in `notes`.

Missing artifacts at the row's tier = refusal.

### Check 11 — Idiom citation for functional adds

For each fixed row whose `class` is functional (solid-violation, clean-code, performance, security) AND the row's diff added lines: confirm the row's `idiom_cited` field resolves AND the cited idiom file appears in the diff's import lines (or the added block calls the named symbol from the idiom). Missing or unresolved citation = refusal. Validator: `check_added_lines_cite_idioms`.

### Check 12 — Security assertion present

For each `class=security` row in the phase, scan the row's commit for a co-committed test file change that asserts the security closure (gate denies, validator rejects, escape neutralises, parameterised query executes). Missing assertion = refusal. Validator: `check_security_assertion_present`.

### Check 13 — Perf baseline + assertion present

For each `class=performance` row in the phase, confirm:
- The row's `notes` field contains a baseline (latency / queries / HTTP / wall-clock) — captured pre-fix.
- The commit added a perf assertion (test asserting query count / wall-clock / cache hit) OR an observability annotation referencing the dashboard that will validate the fix.

Missing baseline OR missing assertion = refusal. Validator: `check_perf_baseline_present`.

### Check 14 — Security tier minimum

For each `class=security` row in the phase, confirm `tier ∈ {standard, heavy}` (never `trivial`). For each row with `subclass ∈ {sql-injection, secret-in-code, unsafe-deserialize}` OR `severity == critical`, confirm `tier == heavy`. Tier violations = refusal.

## Pre-flight checks

1. `ai/align/plan.md` exists and has phase N defined.
2. `ai/align/ledger.md` exists and has rows with `phase: <N>`.
3. Phase N's first commit exists (`git rev-list --grep='align/<N>/' HEAD --max-count=1` returns ≥ 1).
4. No uncommitted changes (`git status --porcelain` empty).
5. `scripts/validate-align-artifacts.sh` is present and executable.

If any pre-flight fails → halt + report.

## Phase 1 — Understand (the ask)

Inputs:
- `ai/align/plan.md` — phase definitions.
- `ai/align/ledger.md` — finding state.
- `ai/align/halts/` — halt registry.
- `ai/align/impact/` — heavy-tier impact analyses.
- Git history since the phase base.

No optional flags — this is a strict gate.

## Phase 2 — Organize (decompose the work)

Run the 14 checks in parallel where independent. Grouping:
- **Read-only on git/ledger** (parallel): 1, 2, 5, 9, 10, 11, 12, 13, 14.
- **Diff-driven** (sequential): 3, 4 (need diff stat first).
- **Heavy I/O** (background): 6 (lint+tc+tests), 7 (coverage), 8 (frontend regressions if `PROJECT_KIND in frontend-*`).

Aggregate outputs into a verdict.

## Phase 3 — Retrieve (read the right context)

- `align-discipline.md` — the rule the checks enforce.
- `_extracted-codebase.md` — PROJECT_KIND for stack-conditional check 8.
- `scripts/validate-align-artifacts.sh` — the validator script that operationalises the checks.

## Phase 4 — Generate (produce the output)

Verdict has three states:

- **PASS** — all 10 checks green. Write 1-line history entry to `ai/align/gate-history.md`. Phase advances.
- **REFUSE** — any check failed. Surface failure + remediation. Phase stays in-progress.
- **REFUSE-HARD** — multiple critical checks failed (1, 2, 6, 7, 9 simultaneously). Indicates the phase was rushed or mis-scoped; recommends `/align-rollback`.

## Phase 5 — Update (persist changes to the knowledge base)

On PASS only:
- `ai/align/gate-history.md` — append one line: `<iso-timestamp> phase <N> PASS | <findings-fixed> findings | <commit-range>`.
- `ai/align/ledger.md` — update each fixed row's `status: verified` (advances from `fixed` to `verified`).
- `ai/index.md` — append-once entry pointing to the gate-history.

On REFUSE: NO writes. The gate is read-only when refusing.

## Phase 6 — Validate (verify correctness)

The gate's own correctness:
- All 10 checks defined have an explicit pass / fail / skip outcome.
- Skip outcomes (e.g., "frontend regression skipped because stack is backend") are documented in the verdict.
- The verdict is REFUSE on any explicit fail.
- The verdict is REFUSE-HARD on multiple critical fails.
- The verdict is PASS only when all checks are pass or skip-with-justification.

## Phase 7 — Improve (feed the learning loop)

- If check 3 (net-lines ≤ 0) fails 2+ phases in a row, surface "closure-verb discipline drift" — the team is reaching for new abstractions; queue ADR.
- If check 4 (no new symbols) fails, surface the specific new symbols added — these belong in `_extracted-idioms.md` if intentional (route to `/setup-project --refine`).
- If check 5 (scope creep) fails, the scan's `scope` fields were too narrow OR the porter expanded scope mid-fix; queue review of scan-time scoping.
- If check 7 (coverage drop) fails, the dead-code class is mis-tuned — branches the project's tests don't cover are surfacing as `dead-code` findings; queue ADR for "coverage-required for dead-code-flag".
- If check 8 (frontend regressions) fails frequently, the visual regression baseline is unstable; queue baseline-refresh policy.

## Output to user

```
Align gate — phase <N> — <PASS | REFUSE | REFUSE-HARD>

Phase: <theme>
Findings: <N> total (<F> fixed, <A> archived, <P> parked, <H> halted)
Commit range: <base>..<HEAD>

Checks:
  1. Ledger completeness          PASS  (<N> rows accounted for)
  2. Gap-count parity             PASS  (every row: gaps_closed == len(evidence))
  3. Net-lines on structural ≤ 0  PASS  (structural diff: +<X> / -<Y> = -<Z>)
  4. No new symbols (idiom-only)  PASS  (0 new exports detected; or N new exports all named in _extracted-idioms.md)
  5. No scope creep               PASS  (every commit's files ⊂ row.scope)
  6. Mechanical (lint+tc+tests)   PASS  (lint: 0 errs, tc: 0 errs, tests: <T>/<T>)
  7. Coverage non-decreasing      PASS  (<base>% → <head>%, +<delta>%)
  8. Frontend regressions         PASS  (a11y: <baseline>→<head>, visual: <N> diffs accepted, bundle: +<%>)
  9. Oracle unmodified            PASS  (no diff in _extracted-idioms.md / ai/conventions.md / ai/architecture.md)
 10. Per-tier artifacts           PASS  (trivial: <T>, standard: <S> with rationale, heavy: <H> with impact + approval)
 11. Functional adds cite idiom   PASS  (<F> functional rows; all cite resolving idioms)
 12. Security assertions present  PASS  (<S> security rows; all have co-committed assertions)
 13. Perf baseline + assertion    PASS  (<P> perf rows; all have baseline + assertion)
 14. Security tier minimum        PASS  (no security row at trivial; all critical at heavy)

Verdict: PASS  →  phase <N> advances; <F> rows flipped to status=verified.
History: ai/align/gate-history.md (line <K>)

Next:
  /align-phase <N+1>          (next phase)
  /align-fast <N+1>           (next phase one-shot)
  /align-final                (only if N is the last phase)
```

On REFUSE:

```
Align gate — phase <N> — REFUSE

Phase: <theme>
Findings: <N> total (<F> fixed, <A> archived, <P> parked, <H> halted)
Commit range: <base>..<HEAD>

Checks:
  1. Ledger completeness          PASS
  2. Gap-count parity             FAIL  ← row A007: gaps_closed=2, len(evidence)=3
                                          row A012: gaps_closed=0, len(evidence)=1 (status=halted)
  3. Net-lines ≤ 0                PASS  (+12 / -45 = -33)
  ...

Verdict: REFUSE  →  phase <N> stays in-progress.

Remediation:
  Row A007: re-run /align-phase <N> --start-from=A007 to close the remaining evidence site
            (the fix closed src/.../<leaf>:42 but missed src/.../<leaf>:67 — re-detect confirms)
  Row A012: halted (see ai/align/halts/A012.md). Resolve manually OR /align-park A012 <reason>.

Re-run /align-gate <N> after resolving.
```

## Mechanical halt — refuse to silently pass

The gate REFUSES on any check failure. It does NOT:
- Soften a fail to a warning.
- Skip a check because "the tool is unavailable" — that's a halt; the tool must be available or the gate REFUSES.
- Pass a phase with `halted` rows in the ledger — halt rows must be resolved (fixed, parked, or rolled back) before the gate can pass.
- Modify the ledger / source / oracle to "make the check pass" — gate is read-only when refusing.

## Hard rules

- **Read-only on REFUSE.** Zero writes when any check fails.
- **One history line on PASS.** No multi-line summaries; the verdict + commit-range are the record.
- **All 10 checks run.** Skip-with-justification is allowed (e.g., frontend regression skipped on backend stack); silent skip is a refusal.
- **Halted rows block the gate.** Resolve via `/align-park` (defer with reason) or fix manually before re-running.
- **No partial passes.** Either all 10 checks green → PASS, or any check red → REFUSE.

## Failure modes

- **Test suite times out** — gate doesn't soften; treat as fail. Configure the project's test-by-touched-files pattern OR allow longer timeout.
- **Visual regression service unavailable** — gate doesn't soften; treat as fail. Re-run when service is back.
- **Reviewer hasn't approved heavy row** — check 10 fails; gate REFUSES until approval lands in ledger row's `notes`.
- **Phase contains rows from prior runs (resumed)** — base commit is the resumed-from commit, not the original phase start; the validator uses `phase_base` from the ledger if present.
- **`gate-history.md` missing** — created on first PASS; not an error.

## Related

### Sibling commands in align pack
- `/align-phase <N>` — runs before this command; produces the artifacts.
- `/align-fast <N>` — runs this command automatically.
- `/align-park <id>` — resolves halted rows by parking them.
- `/align-rollback <N>` — undoes a phase if rethink needed.
- `/align-final` — final cross-phase sweep; this gate is the per-phase equivalent.

### Validator
- `scripts/validate-align-artifacts.sh` — **`[PLANNED — v1.1]`**. Will operationalise the 14 checks. Until it ships, this command runs the equivalent checks inline (agent-side enforcement). The procedures are self-sufficient in `align-discipline.md` so any tool that follows the rule produces the same enforcement floor. Treat v1.0 alignment as a supervised flow.

### Rules
- `.claude/rules/align-discipline.md` — the discipline this gate enforces.

### Patterns
- `ai/patterns/align-ledger.md` — schema for the ledger this gate validates.
