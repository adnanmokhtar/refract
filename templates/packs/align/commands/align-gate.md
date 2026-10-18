---
description: "Phase exit gate for align: 17 checks over phase N — ledger state, line-level scope, re-detect zero, one way per pattern, test lock, emitted names, ratchet, VC approval, mechanical green. Read-only except one history line."
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /align-gate <N>

## The Premise (read this first)

**Discipline pointer:** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) — SOLID / clean-code / functional-class vocabulary (single source of truth).

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

## The 17-check matrix

**Dispatch `@align-gate-auditor`.** It owns this matrix, composes the PASS/REFUSE verdict, and is the artifact that keeps two invocations of the gate from running the checks two different ways. It dispatches `@align-idiom-auditor` per functional row for checks 4, 16 and 17 (its oracle half) rather than re-deriving those judgments at phase scope. Where agent dispatch is unavailable, run the matrix inline — it is identical, and `align-discipline.md` is self-sufficient for rule-only tools.

The gate runs all 17 checks; the first failure sets the verdict to REFUSE and the rest still run, so one gate cycle shows every blocker. Two scripts carry most of it, run once each over the phase:

```bash
V=$(command -v validate-align-artifacts.sh || echo scripts/validate-align-artifacts.sh)
G=$(find .claude/skills -path '*/find-and-align/scripts/align-sweep-gate.py' 2>/dev/null | head -1)
TM=$(find .claude/skills -name token-map.py -path '*design-token-audit*' 2>/dev/null | head -1)
RUN=$(mktemp -d "${TMPDIR:-/tmp}/align-gate.XXXXXX"); export GIT_OPTIONAL_LOCKS=0
bash "$V" --phase="$N" --phase-base="$BASE" --strict > "$RUN/validate.txt" 2>&1; echo "validator exit $?"
TMPDIR="$RUN" python3 -I "$G" ladder --all --repo=. --base="$BASE" --ledger=ai/align/ledger.md ${TM:+--tokens="$TM"} \
  --json > "$RUN/ladder.json"; echo "sweep gate exit $? (0 PASS · 1 FAIL · 4 NOT RUN or pending-review)"
```

| # | Check | Source | Refusal condition |
|---|---|---|---|
| 1 | Ledger completeness | agent: every `phase: <N>` row's `status` | any `detected`, `planned`, `in-progress` or `halted` row. `routed`, `pending-approval`, `pending-ratification` and `parked` are listed by name and do not block; `pending-review` blocks (check 16) |
| 2 | Gap-count parity | ledger | a `fixed` row with `gaps_closed ≠ len(evidence)` |
| 3 | Net-lines ≤ 0 on structural rows | validator `check_net_lines_structural` | added > removed across a structural row's commits |
| 4 | No new symbols | validator `check_no_new_symbols` + `@align-idiom-auditor` | a new public symbol no oracle names |
| 5 | **Line-level scope** (V392, AL-34) | sweep gate `scope`; validator `check_scope_boundary` over **every** commit of the row | a removed line that is neither an evidence line nor the verb's footprint; an evidence line left unchanged; a file outside `scope` |
| 6 | **Re-detect zero** (V391, V-00) | sweep gate `redetect` (the row's `detector_cmd`) | a hit at an evidence line, or a new hit in a touched file |
| 7 | **One way per pattern** (V393, AL-33) | sweep gate `consistency` across the phase | one normalised before-value resolved to two after-values, unless they split by role |
| 8 | **Tests locked** (V408, V-06) | sweep gate `lock-paths` + `lock-count` | a test, spec, snapshot, fixture, lint-config, baseline or oracle file in a row commit; test or assertion count at HEAD below base; coverage down more than the tolerance (check 15) |
| 9 | **Emitted names exist** (V398, V-08) | sweep gate `names` | a token, import path or export the diff introduced that the declared set does not hold |
| 10 | **Value round-trip** (V397, V-07) | sweep gate `roundtrip` (`token-map.py`, ui-ux pack) | an EQ token row whose new token does not equal the old literal in every theme and the same property family. `NOT RUN` with EQ token rows present (no ui-ux pack) refuses: those rows cannot be EQ |
| 11 | **Non-vacuous** (V399, V-09) | sweep gate `vacuous` | a rule a row relies on matched 0 files, or its canary was not flagged |
| 12 | **Ratchet shrink-only** (V395, V-04) | sweep gate `ratchet` | a baseline file grew, a suppression was added, a lint severity loosened (AL-30) |
| 13 | **Proof class and approval** (V394/V396, V407) | validator `check_proof_class`, `check_vc_approval`; agent reads the L10 evidence | a fixed row with no `proof_class`; a VC row without `approval: <name>@<iso>`, or with an approval written in the fix commit; an EQ row with neither a zero-diff record nor the `(static EQ)` flag and its probe |
| 14 | Mechanical pass + boot | agent: project lint, `tsc --noEmit --incremental false`, build, tests, `smoke-verify` at HEAD | any non-zero exit; a boot that fails |
| 15 | Coverage within tolerance | sweep gate `lock-count` (coverage from the run JSON or `coverage-summary.json`) + agent | a drop beyond the project tolerance (default 0.5 pp, `ai/conventions.md § Coverage`); a drop > 5 pp is a hard fail |
| 16 | Per-tier artifacts + idiom citation | validator `check_added_lines_cite_idioms` + agent | standard row without a 20–200-char rationale; heavy row without `impact_analysis_path` and `reviewer_approval`; a functional add with no resolving `idiom_cited` |
| 17 | **Oracle cited, unmodified; owner rows routed** | validator `check_oracle_cited`, `check_oracle_unmodified`, `check_owner_routed` | a row whose `oracle:` is absent or whose quote no longer resolves; an oracle file in the phase diff; a security, performance, database or code-quality row closed (`fixed`/`verified`) in align instead of `routed` (the measured-baseline perf carve-out excepted) |

A sweep-gate step that prints `NOT RUN` for rows it applies to is a **refusal** for that check, never a pass: the gate cannot certify what it did not run. A step structurally inapplicable to the phase (no token rows for check 10, no baseline file for check 12) prints `SKIP — <reason>`.

**What the matrix no longer holds.** The old checks 12 (security assertion), 13 (perf baseline) and 14 (security tier) graded security and perf fixes made inside align. Those rows are now routed to `/security-fix`, `/perf-fix` and `/db-fix`, which carry their own failing-first proofs, so check 17 refuses a phase that closed one here. The visual "diffs reviewed and accepted" line of the old check 8 is replaced by check 13: a visual change passes only with a named human approval.

## Pre-flight checks

1. `ai/align/plan.md` exists and has phase N defined.
2. `ai/align/ledger.md` exists and has rows with `phase: <N>`.
3. Phase N's first commit exists (`git rev-list --grep='align/<N>/' HEAD --max-count=1` returns ≥ 1).
4. No uncommitted changes (`git status --porcelain` empty).
5. `scripts/validate-align-artifacts.sh` and `find-and-align`'s `align-sweep-gate.py` are present.

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

Run the 17 checks in parallel where independent. Grouping:
- **Ledger and validator** (parallel): 1, 2, 3, 4, 13, 16, 17.
- **Sweep gate, one `ladder --all` run**: 5–12.
- **Heavy I/O** (background): 14 (lint + types + build + tests + boot), 15 (coverage).

Aggregate outputs into a verdict.

## Phase 3 — Retrieve (read the right context)

- `align-discipline.md` — the rule the checks enforce.
- `_extracted-codebase.md` — PROJECT_KIND, which picks check 14's lint, type, build and boot commands for the stack.
- `scripts/validate-align-artifacts.sh` — the validator script that operationalises the checks.

## Phase 4 — Generate (produce the output)

Verdict has three states:

- **PASS** — all 17 checks green (or `SKIP` with a structural reason). Write 1-line history entry to `ai/align/gate-history.md`. Phase advances.
- **REFUSE** — any check failed. Surface failure + remediation. Phase stays in-progress.
- **REFUSE-HARD** — several critical checks failed at once (any two of 5, 6, 7, 8, 14). Indicates the phase was rushed or mis-scoped; recommends `/align-rollback`.

## Phase 5 — Update (persist changes to the knowledge base)

On PASS only:
- `ai/align/gate-history.md` — append one line: `<iso-timestamp> phase <N> PASS | <findings-fixed> findings | <commit-range>`.
- `ai/align/ledger.md` — update each fixed row's `status: verified` (advances from `fixed` to `verified`).
- `ai/index.md` — append-once entry pointing to the gate-history.

On REFUSE: NO writes. The gate is read-only when refusing.

## Phase 6 — Validate (verify correctness)

The gate's own correctness:
- All 17 checks have an explicit pass / fail / skip outcome; every `NOT RUN` on an applicable row is a fail.
- Skip outcomes (e.g., "frontend regression skipped because stack is backend") are documented in the verdict.
- The verdict is REFUSE on any explicit fail.
- The verdict is REFUSE-HARD on multiple critical fails.
- The verdict is PASS only when all checks are pass or skip-with-justification.

## Phase 7 — Improve (feed the learning loop)

- If check 3 (net-lines ≤ 0) fails 2+ phases in a row, surface "closure-verb discipline drift" — the team is reaching for new abstractions; queue ADR.
- If check 4 (no new symbols) fails, surface the specific new symbols added — these belong in `_extracted-idioms.md` if intentional (route to `/setup-project --refine`).
- If check 5 (scope creep) fails, the scan's `scope` fields were too narrow OR the porter expanded scope mid-fix; queue review of scan-time scoping.
- If check 7 (one way per pattern) fails, the token map is not context-keyed for that value; the decision belongs to a human, recorded in the oracle.
- If check 13 fails on VC rows repeatedly, the scan is classifying nearest-token snaps as EQ; check the `token-map.py` lookups (precedents/align § 7, § 27).

## Output to user

```
Align gate — phase <N> — <PASS | REFUSE | REFUSE-HARD>

Phase: <theme>
Findings: <N> total (<F> fixed, <A> archived, <P> parked, <H> halted)
Commit range: <base>..<HEAD>

Checks:
  1. Ledger completeness          PASS  (<F> fixed · <R> routed · <V> pending-approval · <G> pending-ratification · 0 open)
  2. Gap-count parity             PASS  (every row: gaps_closed == len(evidence))
  3. Net-lines on structural ≤ 0  PASS  (structural diff: +<X> / -<Y> = -<Z>)
  4. No new symbols               PASS  (0 new exports)
  5. Line-level scope             PASS  (<H> hunks; every removed line an evidence line or footprint)
  6. Re-detect zero               PASS  (<F> rows: 0 at evidence lines, 0 new in touched files)
  7. One way per pattern          PASS  (<K> before-keys, 1 after each)
  8. Tests locked                 PASS  (no test/snapshot/config file; tests 412 → 412, assertions 1,030 → 1,030)
  9. Emitted names                PASS  (<T> tokens, <I> imports declared)
 10. Value round-trip             PASS  (<E> EQ token rows, light + dark)
 11. Non-vacuous                  PASS  (every rule matched ≥ 1 file)
 12. Ratchet shrink-only          SKIP  (no baseline file in the repo)
 13. Proof class + approval       PASS  (EQ <E> zero-diff · FN <F> behaviour tests · VC 1 approved ana@2026-10-18)
 14. Mechanical + boot            PASS  (lint 0 · tc 0 · tests 412 · boot pass)
 15. Coverage                     PASS  (81.4% → 81.2%, tolerance 0.5 pp)
 16. Per-tier + idiom citation    PASS  (trivial <T> · standard <S> with rationale · heavy 0)
 17. Oracle + owner routing       PASS  (every quote resolves · oracle files untouched · 3 owner rows routed, 0 closed here)

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
  1. Ledger completeness          FAIL  ← row A012: status=halted
  2. Gap-count parity             FAIL  ← row A007: gaps_closed=2, len(evidence)=3
  7. One way per pattern          FAIL  ← '#d92d20' → var(--color-danger) (A021) and var(--color-error) (A024)
 13. Proof class + approval       FAIL  ← A031 proof_class VC, approval empty
  ...

Verdict: REFUSE  →  phase <N> stays in-progress.

Remediation:
  Row A007: re-run /align-phase <N> --start-from=A007 to close the remaining evidence site
            (the fix closed src/.../<leaf>:42 but missed src/.../<leaf>:67 — re-detect confirms)
  Row A012: halted (see ai/align/halts/A012.md). Resolve manually OR /align-park A012 <reason>.
  Rows A021/A024: pick the token the oracle's role column names; revert the other row and re-run it.
  Row A031: a human approves the visual diff (approval: <name>@<iso>) or the row goes to /polish.

Re-run /align-gate <N> after resolving.
```

## Mechanical halt — refuse to silently pass

The gate REFUSES on any check failure. It does NOT:
- Soften a fail to a warning.
- Skip a check because "the tool is unavailable" — that's a refusal; a sweep-gate step that is `NOT RUN` on applicable rows refuses its check.
- Accept a visual diff without a named human approval in the ledger.
- Pass a phase with `halted` rows in the ledger — halt rows must be resolved (fixed, parked, or rolled back) before the gate can pass.
- Modify the ledger / source / oracle to "make the check pass" — gate is read-only when refusing.

## Hard rules

- **Read-only on REFUSE.** Zero writes when any check fails.
- **One history line on PASS.** No multi-line summaries; the verdict + commit-range are the record.
- **All 17 checks run.** Skip-with-justification is allowed only when the check is structurally inapplicable (no token rows, no baseline file); silent skip is a refusal.
- **Halted rows block the gate.** Resolve via `/align-park` (defer with reason) or fix manually before re-running.
- **No partial passes.** Either all 17 checks green → PASS, or any check red → REFUSE.

## Failure modes

- **Test suite times out** — gate doesn't soften; treat as fail. Configure the project's test-by-touched-files pattern OR allow longer timeout.
- **No visual-diff harness** — EQ rows carry `(static EQ)` with their probe and pass check 13 only with that flag; VC rows cannot pass without a diff and an approval.
- **Reviewer hasn't approved heavy row** — check 16 fails; gate REFUSES until approval lands in ledger row's `notes`.
- **Phase contains rows from prior runs (resumed)** — base commit is the resumed-from commit, not the original phase start; the validator uses `phase_base` from the ledger if present.
- **`gate-history.md` missing** — created on first PASS; not an error.

## Related

### Sibling commands in align pack
- `/align-phase <N>` — runs before this command; produces the artifacts.
- `/align-fast <N>` — runs this command automatically.
- `/align-park <id>` — resolves halted rows by parking them.
- `/align-rollback <N>` — undoes a phase if rethink needed.
- `/align-final` — final cross-phase sweep; this gate is the per-phase equivalent.

### Agents
- `.claude/agents/align-gate-auditor.md` — owns the 17-check matrix and the PASS/REFUSE verdict; read-only on REFUSE, one history line on PASS.
- `.claude/agents/align-idiom-auditor.md` — supplies the per-row verdicts behind checks 4 (no new symbols), 16 (idiom citation) and 17 (oracle unmodified).
- `.claude/agents/align-ledger-auditor.md` — check 1 (ledger completeness) is the phase-scoped slice of its cross-phase reconciliation; dispatch it when check 1 fails and you need to know whether the drift is local to this phase.

### Validator and sweep gate
- `scripts/validate-align-artifacts.sh` — checks 2, 3, 4, 5 (file level, every row commit), 13, 16 (idiom citation), 17, plus the run-level scan evidence, progress reconciliation and actionable-next-steps checks.
- `find-and-align`'s `scripts/align-sweep-gate.py` — checks 5 (line level), 6, 7, 8, 9, 10, 11, 12 and the coverage half of 15.
- **Agent-side, no script:** 1 (ledger completeness), 14 (mechanical + boot), the zero-diff evidence in 13, and the tier artifacts in 16. `@align-gate-auditor` labels them `(agent-side)`.

### Rules
- `.claude/rules/align-discipline.md` — the discipline this gate enforces.

### Patterns
- `ai/patterns/align-ledger.md` — schema for the ledger this gate validates.
