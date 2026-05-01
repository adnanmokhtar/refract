---
description: Final sweep — confirms every finding in the ledger is fixed and gate-verified across ALL phases. Runs the full audit one more time to catch regressions. Recommends next steps (continued cadence / dormant / re-scan). Read-mostly.
kind: command
pack: align
---

# /align-final

## The Premise (read this first)

**Final = the alignment effort is done.** Every phase has gate-PASSed; every finding is fixed or archived; the codebase has been swept. This command runs the full audit one more time, end-to-end, to confirm nothing regressed since the last phase landed. It's the equivalent of `/migration-final` for codebase alignment.

It does NOT introduce new findings. If new drift has accumulated since the last `/align-scan`, this command surfaces that as "next-cadence backlog" — the user re-runs `/align-scan` for the new sweep.

## When to use

- After the last phase's `/align-gate` PASSes — confirm the alignment effort is shippable end-to-end.
- Before declaring the alignment milestone done.
- Before resuming feature work post-alignment.

## When NOT to use

- Mid-alignment (any phase still has rows in `detected` / `in-progress` / `halted`).
- As a substitute for `/align-gate` — final validates the WHOLE effort; gate validates ONE phase.

## Pre-requisites

- `ai/align/ledger.md` exists.
- Every row in the ledger has `status ∈ {verified, archived-pre-existing, parked}` (no `detected` / `in-progress` / `halted` / `fixed`).
- Every phase has a gate-history entry (every phase has been gated).

If pre-requisites missing → halt + report which rows are still in-progress / which phases haven't gated.

## Phase 1 — Understand (the ask)

Inputs:
- `ai/align/ledger.md`.
- `ai/align/plan.md`.
- `ai/align/gate-history.md`.
- `ai/align/halts/`.
- `ai/align/runs/` (per-phase logs).
- Git history.
- `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md` (oracle).

Optional flags:
- `--re-audit` — re-dispatch the detector for **every** row across all phases (including `verified` ones). Catches rows whose fingerprint reappeared since the gate (drift / rot / false-verified). Re-detected rows that surface gaps flip to `halted` and are listed in the report's "Outstanding" section. Re-detected rows that stay clean stay `verified`. Mirrors `/migration-final --re-audit`. Use when you want fresh confidence that the entire alignment effort is still green.
- `--re-scan` — also run `/align-scan` (full scan) and compare new findings vs. ledger; surfaces any NEW drift that has accumulated since the original scan (different from `--re-audit`, which only re-checks existing ledger rows).
- `--strict` — fail on any cross-reference inconsistency (default: warn).

## Phase 2 — Organize (decompose the work)

Run these checks in order:

1. **Ledger completeness across all phases** — every row in the plan has `status ∈ {verified, archived-pre-existing, parked}`.
2. **Cross-phase gap-count parity** — every verified row has `gaps_closed == len(evidence)`.
3. **Cumulative diff sanity** — across all phase commits, structural net-lines ≤ 0; functional adds all cite idioms.
4. **Mechanical pass at HEAD** — lint + typecheck + full test suite + coverage.
5. **Frontend regression suite at HEAD** (if `PROJECT_KIND in frontend-*`) — full a11y + visual + bundle-size baseline.
6. **Security assertion suite at HEAD** — every security row's assertion still passes.
7. **Performance assertion suite at HEAD** — every perf row's assertion / observability still in expected range.
8. **Oracle unmodified across all phases** — `git diff <first-phase-base>..HEAD -- _extracted-idioms.md ai/conventions.md ai/architecture.md` is empty.
9. **No regressions detected by re-scan** (if `--re-scan` flag set) — `/align-scan` re-run + compare with ledger; new findings = next-cadence backlog.

## Phase 3 — Retrieve (read the right context)

- Full ledger.
- All halt files.
- All gate-history entries.
- Git log for the alignment branch range.
- (If `--re-scan`): run the full `/align-scan` and read its output.

## Phase 4 — Generate (produce the output)

```markdown
# Alignment final report — <YYYY-MM-DD>

PROJECT_KIND: <kind>
Alignment branch range: <first-base>..<HEAD>
Total phases: <K>
Total findings: <N>

## Verdict: <PASS | PARTIAL | REGRESSION>

## Phase summary
| Phase | Theme | Findings | Fixed | Archived | Parked | Gate result | Date |
|---|---|---|---|---|---|---|---|
| 1 | mechanical cleanup | 12 | 12 | 0 | 0 | PASS | 2026-04-15 |
| 2 | security critical | 4 | 4 | 0 | 0 | PASS | 2026-04-16 |
| 3 | security standard | 10 | 10 | 0 | 0 | PASS | 2026-04-18 |
| 4 | silent-catch | 8 | 7 | 1 | 0 | PASS | 2026-04-19 |
| 5 | auth UI/UX | 15 | 15 | 0 | 0 | PASS | 2026-04-22 |
| 6 | perf hot-path | 8 | 8 | 0 | 0 | PASS | 2026-04-24 |
| ... | | | | | | | |

## Final checks
| Check | Result | Detail |
|---|---|---|
| Ledger completeness | PASS | <N> rows accounted for |
| Cross-phase gap-count parity | PASS | every verified row: gaps_closed == len(evidence) |
| Cumulative structural diff | PASS | structural: -<X> lines |
| Cumulative functional diff | PASS | functional: +<Y> lines (all cite idioms) |
| Mechanical at HEAD | PASS | lint + tc + tests + coverage all green |
| Frontend regression at HEAD | PASS | a11y, visual, bundle-size all green |
| Security assertions at HEAD | PASS | <S> security rows; all assertions still passing |
| Perf assertions at HEAD | PASS | <P> perf rows; all in expected range |
| Oracle unmodified | PASS | no diff in _extracted-idioms.md / ai/conventions.md / ai/architecture.md |
| Re-scan diff | (not run) — OR — PASS (no new findings) — OR — WARN (<X> new findings; queue for next cadence) |

## Aggregate impact
- Cumulative diff: +<added> / -<removed> = <net> lines
- Test count delta: +<test-added> tests
- Coverage delta: <pre>% → <head>%
- Bundle size delta (frontend): <pre>KB → <head>KB
- Security findings closed: <S> (critical: <Cf>, high: <Hf>, medium: <Mf>, low: <Lf>)
- Perf findings closed: <P> with measured uplift summarised in ai/align/perf-summary.md
- Reinvented wrappers replaced with shared: <R>
- Dead code removed: <D> exports
- Silent catches routed to error handler: <Sc>

## Outstanding (next cadence)
- Parked findings: <Pk> (each with rationale; revisit per /align-unpark when blockers clear)
- Re-scan new findings (if --re-scan): <Nf> (queue for next /align-scan + /align-plan)
- Recommended cadence for re-scan: <weekly | monthly | quarterly>

## Recommendations
- <recommendation 1, e.g.: "5 idiom gaps surfaced during alignment; queue /setup-project --refine">
- <recommendation 2, e.g.: "reinvented-wrapper class had 28 findings; queue ADR for pre-commit hook to enforce shared wrapper usage">
- <recommendation 3, e.g.: "next /align-scan in 4 weeks">

## Recommended next
- /align-status (continue periodic checks)
- /schedule align-scan +4w (queue next cadence)
- /align-park <id> for parked findings revisit
```

## Phase 5 — Update (persist changes)

- `ai/align/final-report-<YYYY-MM-DD>.md` — the report above.
- `ai/align/perf-summary.md` — aggregate perf measurements (one row per perf finding: V1 cost, V2 cost, delta).
- `ai/align/security-summary.md` — aggregate security findings closed (one row per security finding: subclass, severity, assertion path).
- `ai/index.md` — entry pointing to the final report.

NO ledger modification. NO source modification.

## Phase 6 — Validate (verify correctness)

- The verdict is `PASS` only when all 9 checks (or 10 with `--re-scan`) are PASS.
- The verdict is `PARTIAL` if any row is parked (pending re-evaluation) AND all other checks PASS.
- The verdict is `REGRESSION` if any check fails — surface the specific failure; recommend `/align-rollback <N>` if a phase introduced the regression.

## Phase 7 — Improve (feed the learning loop)

- Findings classes that surfaced >50 instances each = strong signal for hook / lint-rule enforcement; queue ADRs.
- Idiom gaps surfaced (rows that halted with "idiom not found") = strong signal for `/setup-project --refine`; queue.
- Phases that took > 5x estimated wall-clock = signal for re-scoping; queue post-mortem.
- If `--re-scan` shows a class regressed (a fixed silent-catch reappeared), queue ADR for "alignment cadence too long; tighten cadence".

## Output to user

```
Alignment final — <PASS | PARTIAL | REGRESSION>

Phases completed:        <K>
Findings closed:         <F> / <N>
Outstanding (parked):    <P>

Cumulative impact:
  Diff:                  +<X> / -<Y> = <net> lines
  Coverage:              <pre>% → <head>% (Δ +<delta>%)
  Security closed:       <S> (critical: <C>)
  Perf closed:           <P> (avg uplift: <X>%)
  Reinvented removed:    <R>
  Dead code removed:     <D>

Reports:
  ai/align/final-report-<date>.md
  ai/align/perf-summary.md
  ai/align/security-summary.md

Recommendations:
  - <top 1-3 recommendations>

Next:
  /schedule align-scan +<cadence>     (queue next sweep)
  /align-status                       (interim check-ins)
```

## Hard rules

- **Read-mostly.** Writes only the report files; never modifies ledger / source / oracle.
- **No new findings.** This command reports the past sweep + recommends the next cadence; it does NOT scan.
- **`PASS` requires all checks green.** Any single fail = not PASS.

## Failure modes

- **Some rows still in-progress** — refuse; route to `/align-status` for the in-progress list.
- **Some phases haven't gated** — refuse; route to `/align-gate <N>` for the un-gated phases.
- **Mechanical red at HEAD** — surface; phase regressions sometimes only surface in full-suite tests.
- **Re-scan finds previously-fixed fingerprint** — REGRESSION verdict; route to `/align-rollback <phase-of-regression>`.

## Related

### Sibling commands in align pack
- `/align-status` — interim read; this is the end-of-effort version.
- `/align-gate <N>` — per-phase verifier.
- `/align-rollback <N>` — undoes a regression-causing phase.
- `/align-park <id>` / `/align-unpark <id>` — manage parked findings.
- `/align-scan` — produces the next cadence's findings.

### Patterns
- `ai/patterns/align-ledger.md` — schema.
