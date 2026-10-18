---
description: Final sweep — confirms every align row is verified, routed or accounted for across ALL phases, re-runs the gate's checks over the whole range to catch regressions, recommends the next cadence. Read-mostly.
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /align-final

## The Premise (read this first)

**Final = the alignment effort is done.** Every phase has gate-PASSed; every align row is verified or aged out; every owner row went to its owner's fix command; the codebase has been swept. This command re-runs the gate's checks over the whole range, end-to-end, to confirm nothing regressed since the last phase landed — a before-value resolved one way in phase 2 and another in phase 5 fails here and nowhere else. It's the equivalent of `/migration-final` for codebase alignment.

It does NOT introduce new rows. If new drift has accumulated since the last `/align-scan`, this command surfaces that as "next-cadence backlog" — the user re-runs `/align-scan` for the new sweep.

## When to use

- After the last phase's `/align-gate` PASSes — confirm the alignment effort is shippable end-to-end.
- Before declaring the alignment milestone done.
- Before resuming feature work post-alignment.

## When NOT to use

- Mid-alignment (any phase still has rows in `detected` / `planned` / `in-progress` / `halted` / `fixed`).
- As a substitute for `/align-gate` — final validates the WHOLE effort; gate validates ONE phase.

## Pre-requisites

- `ai/align/ledger.md` exists.
- Every row in the ledger has a closed or waiting status: `verified`, `archived-pre-existing`, `archived-deprecated`, `refuted`, `routed`, `parked`, `pending-approval` or `pending-ratification` (no `detected` / `planned` / `in-progress` / `halted` / `fixed` / `pending-review`).
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
- The oracle: `convention-oracle` § 0's map (`oracle-map.py --out=$RUN/oracle`), and the files its rows cite (`ai/conventions.md`, `ai/architecture.md`, `ai/modules.md`, ADRs, lint configs, `_extracted-idioms.md`).
- The audit the sweep started from: `ai/audits/<date>-align.md` (= `ai/align/scan-report.md` of that run).

Optional flags:
- `--re-audit` — re-run the recorded `detector_cmd` for **every** row across all phases (including `verified` ones). Catches rows whose fingerprint reappeared since the gate (drift / rot / false-verified). Re-detected rows that surface gaps are listed in the report's "Outstanding" section with the phase that closed them (this command writes no ledger state; `/align-replan --include-drifted` re-queues them). Re-detected rows that stay clean stay `verified`. Mirrors `/migration-final --re-audit`. Use when you want fresh confidence that the entire alignment effort is still green.
- `--re-scan` — also run `/align-scan` (the read-only audit; it writes a fresh `ai/audits/<date>-align.md`) and compare its Findings with the ledger; surfaces any NEW drift that has accumulated since the original scan (different from `--re-audit`, which only re-checks existing ledger rows).
- `--strict` — fail on any cross-reference inconsistency (default: warn).

## Phase 2 — Organize (decompose the work)

**Dispatch two agents before the checklist.** `@align-ledger-auditor` reconciles the whole sweep's state (ledger ↔ git ↔ halts ↔ impact files ↔ plan ↔ gate-history, in both directions) — it owns checks 1, 2 and 9 below and the Outstanding section's accuracy. `@align-gate-auditor` re-runs the `/align-gate` 17-check matrix at HEAD across the cumulative commit range — it owns checks 3 through 8. Under `--re-audit` the gate auditor runs per phase rather than once cumulatively, so a regression is attributed to the phase that caused it and `/align-rollback <N>` has a number to take.

```bash
RUN=$(mktemp -d "${TMPDIR:-/tmp}/align-final.XXXXXX"); export GIT_OPTIONAL_LOCKS=0
V=$(command -v validate-align-artifacts.sh || echo scripts/validate-align-artifacts.sh)
G=$(find .claude/skills -path '*/find-and-align/scripts/align-sweep-gate.py' 2>/dev/null | head -1)
TM=$(find .claude/skills -name token-map.py -path '*design-token-audit*' 2>/dev/null | head -1)
bash "$V" --all --strict > "$RUN/validate.txt" 2>&1; echo "validator exit $?"
TMPDIR="$RUN" python3 -I "$G" ladder --all --repo=. --base="$FIRST_BASE" --ledger=ai/align/ledger.md ${TM:+--tokens="$TM"} \
  --json > "$RUN/ladder-cumulative.json"; echo "sweep gate exit $? (0 PASS · 1 FAIL · 4 NOT RUN or pending-review)"
```

Run these checks in order:

1. **Ledger completeness across all phases** — every row has a closed or waiting status (§ Pre-requisites); `pending-approval`, `pending-ratification`, `routed` and `parked` rows are listed by name in Outstanding, never counted as closed.
2. **Cross-phase gap-count parity** — every verified row has `gaps_closed == len(evidence)`.
3. **Cumulative diff sanity** — across all phase commits, structural net-lines ≤ 0; functional adds all cite idioms; no new symbol the oracle does not name (gate checks 3, 4, 16).
4. **Re-detect zero at HEAD** (V391) — every verified row's `detector_cmd` returns 0 at its evidence lines and its rule still matches ≥ 1 file (V399). A reappeared hit is a regression; a rule that matches 0 files is `NOT RUN`, not clean.
5. **One way per pattern across all phases** (V393, AL-33) — `consistency` over `<first-base>..HEAD`: one before-value resolved to one after-value in the whole sweep, unless the token map splits it by role.
6. **Tests, names and ratchet across the range** — no test, snapshot, fixture, lint-config, baseline or oracle file in any align commit; test and assertion counts at HEAD ≥ the first base (V408); every emitted token, import and export declared (V398); every baseline shrink-only (V395).
7. **Proof at HEAD** — EQ rows: the zero computed-style (or compiled-CSS) diff of the cumulative range, or `(static EQ)` with its probe listed; VC rows: each `approval: <name>@<iso>` written by a human outside the fix commit (V407); FN rows: their behaviour tests pass at HEAD (V401). Carve-out perf / data rows (applied here because the owner pack was absent): their measured baseline test passes at HEAD.
8. **Mechanical pass at HEAD** — lint + typecheck (`tsc --noEmit --incremental false`) + build + full test suite + coverage within tolerance + boot.
9. **Oracle unmodified, owners routed** — `git diff <first-base>..HEAD` touches no file an `oracle:` row cites (`ai/conventions.md`, `ai/architecture.md`, `ai/modules.md`, ADRs, lint configs, `_extracted-idioms.md`; validator `check_oracle_unmodified`); no security, performance, database or code-quality row is `verified` here instead of `routed` (`check_owner_routed`); every `routed` row carries no commit.
10. **No regressions detected by re-scan** (if `--re-scan` flag set) — `/align-scan` re-run + compare with ledger; new Findings = next-cadence backlog.

## Phase 3 — Retrieve (read the right context)

- Full ledger.
- All halt files.
- All gate-history entries.
- Git log for the alignment branch range.
- (If `--re-scan`): run `/align-scan` and read its `ai/audits/<date>-align.md`.

## Phase 4 — Generate (produce the output)

```markdown
# Alignment final report — <YYYY-MM-DD>

PROJECT_KIND: <kind>
Alignment branch range: <first-base>..<HEAD>
Total phases: <K>
Total rows: <N> (align-closed <A> · routed <R> · refuted <F> · aged out <O>)

## Verdict: <PASS | PARTIAL | REGRESSION>

## Phase summary
| Phase | Theme | AL classes | Rows | Verified | Aged out | Parked | Gate result | Date |
|---|---|---|---|---|---|---|---|---|
| 1 | regressions and suppressions | AL-30, AL-29 | 6 | 6 | 0 | 0 | PASS | 2026-04-15 |
| 2 | gates and required props | AL-15 | 3 | 3 | 0 | 0 | PASS | 2026-04-16 |
| 3 | imports through the wrapper | AL-11, AL-14, AL-22 | 12 | 11 | 1 | 0 | PASS | 2026-04-18 |
| 4 | auth pages UI swaps | AL-05, AL-12, AL-26 | 10 | 10 | 0 | 0 | PASS | 2026-04-22 |
| 5 | names and layout | AL-16, AL-17, AL-19 | 9 | 8 | 0 | 1 | PASS | 2026-04-24 |

## Final checks
| Check | Result | Detail |
|---|---|---|
| 1 Ledger completeness | PASS | <N> rows accounted for; <V> pending-approval, <G> pending-ratification listed below |
| 2 Cross-phase gap-count parity | PASS | every verified row: gaps_closed == len(evidence) |
| 3 Cumulative diff | PASS | structural: -<X> lines; functional: +<Y> lines (all cite idioms); 0 new symbols |
| 4 Re-detect zero at HEAD | PASS | <V> rows: 0 hits at evidence lines; every rule matched ≥ 1 file |
| 5 One way per pattern | PASS | <K> before-keys across <P> phases, 1 after each |
| 6 Tests, names, ratchet | PASS | no locked file in any align commit; tests 412 → 412; names declared; baselines shrink-only |
| 7 Proof at HEAD | PASS | EQ <E> zero-diff · (static EQ) <S> with probes · VC <C> approved · FN <F> tests green |
| 8 Mechanical at HEAD | PASS | lint + tc + build + tests + coverage + boot all green |
| 9 Oracle unmodified, owners routed | PASS | no oracle file in <first-base>..HEAD; <R> owner rows routed, 0 closed here |
| 10 Re-scan diff | (not run) — OR — PASS (no new Findings) — OR — WARN (<X> new Findings; queue for next cadence) |

## Aggregate impact
- Cumulative diff: +<added> / -<removed> = <net> lines
- Test count delta: <base> → <head> tests (never down)
- Coverage delta: <pre>% → <head>%
- By AL class: AL-11 <n> raw imports re-routed · AL-14 <n> deep imports · AL-15 <n> gates added · AL-16/17 <n> renames · AL-30 <n> baselines restored …
- By proof class: EQ <E> · FN <F> · VC <C> (each with its approver)
- Routed to owners: <R> rows (`/frontend-fix` <a>, `/backend-fix` <b>, `/quality-fix` <c>, `/polish` <d>, …) — closed or open in the owner's ledger, not here
- Enforcement added: <T> T2 rules now T1 at error (AL-03) with shrink-only baselines

## Outstanding (next cadence)
- Parked rows: <Pk> (each with rationale; revisit per /align-unpark when blockers clear)
- Pending approval: <V> VC rows awaiting a named human (never auto-accepted)
- Pending ratification: <G> T2g rules, one line each (`/setup-project --refine` after a human confirms)
- AL-02 splits and AL-04 doc advisories from the audit: <S> (a human decides; 0 ledger rows)
- Re-scan new Findings (if --re-scan): <Nf> (queue for next /align-scan + /align-plan)
- Recommended cadence for re-scan: <weekly | monthly | quarterly>

## Recommendations
- <recommendation 1, e.g.: "5 idiom gaps surfaced during alignment; queue /setup-project --refine">
- <recommendation 2, e.g.: "AL-11 had 28 rows and no T1 rule; queue a no-restricted-imports path + a shrink-only baseline (AL-03)">
- <recommendation 3, e.g.: "next /align-scan --changed origin/main on every PR; full /align-scan in 4 weeks">

## Recommended next
- /align-status (continue periodic checks)
- /schedule align-scan +4w (queue next cadence)
- /align-unpark <id> for parked rows whose blockers cleared
```

## Phase 5 — Update (persist changes)

- `ai/align/final-report-<YYYY-MM-DD>.md` — the report above (the routed rows and the carve-out perf / data rows with their measured baselines are tables inside it; security, performance and data results live in their owners' reports).
- `ai/index.md` — entry pointing to the final report.

NO ledger modification. NO source modification.

## Phase 6 — Validate (verify correctness)

- The verdict is `PASS` only when all 9 checks (or 10 with `--re-scan`) are PASS **and no row is parked, pending-approval or pending-ratification**. A check that printed `NOT RUN` on rows it applies to is not PASS.
- The verdict is `REGRESSION` if any check fails — surface the specific failure; recommend `/align-rollback <N>` if a phase introduced the regression.
- Otherwise the verdict is `PARTIAL`, **and `PARTIAL` is never reported bare.** It always carries the parked breakdown below.

### `PARTIAL` must be qualified — a parked permission gate is not a parked file rename

A single undifferentiated `PARTIAL` is how a dropped permission gate leaves a sweep looking the same as a misnamed file. The verdict line names the worst open row, and the breakdown enumerates every parked and pending row grouped by severity, worst first:

```
PARTIAL — 6 open rows, worst: AL-15 gate (HIGH), parked 34 days

  PARKED — HIGH (1)                                        <-- these block a PASS forever
    A047  AL-15  <Button variant="danger"> outside <Can action="orders.delete">  34d  blocker: idiom-missing
          SLA: escalated (aged from parked_sla_from, threshold 24h)
          override: "<who signed it, and until when>"

  PENDING APPROVAL — VC (2)
    A112  AL-06  13px → --space-3 snap (nearest)   8d   awaiting a named approver
    A118  AL-11  wrapper defaults differ (VC)      8d   awaiting a named approver

  PARKED — MEDIUM / LOW (3)
    A051  AL-14  deep import   6d    A078  AL-13  helper copy  6d
    A091  AL-16  file name     40d   <-- past unpark_after; decide or deprecate

  1 row is UNREVIVABLE (no prior_status): A091 → /align-unpark --list-unrevivable
```

Rules for this block:
- **Group by severity, HIGH → MEDIUM → LOW, with the pending-approval and pending-ratification rows as their own groups**, and within each group by age descending. Owner rows are not here: they are `routed`, and their state is the owner's.
- **Every parked HIGH row prints its SLA state**, aged from `parked_sla_from`. A parked HIGH row (a permission, tenant or auth gate) past threshold makes the verdict `PARTIAL (escalated)`, which reads differently in a report title and is meant to.
- **A parked row missing `prior_status` / `prior_phase` is reported as `UNREVIVABLE`**, not merely parked — no command can restore it, so it is closer to an undocumented won't-fix than to a deferral.
- **Never collapse the count.** "6 parked findings" with no classes is the Trusted Summary applied to your own report.

## Phase 7 — Improve (feed the learning loop)

- AL classes that surfaced >50 rows each with no T1 rule = strong signal for lint-rule enforcement plus a shrink-only baseline (an AL-03 row); queue ADRs.
- Idiom gaps surfaced (rows that halted `missing-idiom`) = strong signal for `/setup-project --refine`; queue.
- A high `pending-ratification` count = the oracle is mostly generated (T2g); ratification before the next sweep.
- Phases that took > 5x estimated wall-clock = signal for re-scoping; queue post-mortem.
- If `--re-scan` shows a class regressed (a re-routed raw import reappeared), queue ADR for "alignment cadence too long, or the rule is not at error in CI".

## Output to user

```
Alignment final — <PASS | PARTIAL | REGRESSION>

Phases completed:        <K>
Align rows verified:     <F> / <A>
Routed to owners:        <R>
Outstanding:             <P> parked · <V> pending-approval · <G> pending-ratification

Cumulative impact:
  Diff:                  +<X> / -<Y> = <net> lines
  Coverage:              <pre>% → <head>% (Δ <delta> pp)
  Proof:                 EQ <E> · FN <Fn> · VC <C> approved
  Enforcement added:     <T> rules now at error (AL-03)

Reports:
  ai/align/final-report-<date>.md

Recommendations:
  - <top 1-3 recommendations>

Next:
  /schedule align-scan +<cadence>     (queue next sweep)
  /align-status                       (interim check-ins)
```

## Hard rules

- **Read-mostly.** Writes only the report files; never modifies ledger / source / oracle.
- **No new rows.** This command reports the past sweep + recommends the next cadence; it does not scan unless `--re-scan` is passed, and then the audit's Findings are backlog, not ledger rows written here.
- **Never counts an owner's row as align's.** Routed rows are reported as routed; their closure is the owner's.
- **`PASS` requires all checks green.** Any single fail = not PASS.

## Failure modes

- **Some rows still in-progress** — refuse; route to `/align-status` for the in-progress list.
- **Some phases haven't gated** — refuse; route to `/align-gate <N>` for the un-gated phases.
- **Mechanical red at HEAD** — surface; phase regressions sometimes only surface in full-suite tests.
- **Re-scan finds previously-fixed fingerprint** — REGRESSION verdict; route to `/align-rollback <phase-of-regression>`.

## Related

### Agents
- `.claude/agents/align-ledger-auditor.md` — cross-phase state reconciliation; owns checks 1, 2 and 9 and the Outstanding list.
- `.claude/agents/align-gate-auditor.md` — the 17-check matrix re-run at HEAD; owns checks 3–8. Per-phase under `--re-audit` so regressions get a phase number.

### Sibling commands in align pack
- `/align-status` — interim read; this is the end-of-effort version.
- `/align-gate <N>` — per-phase verifier.
- `/align-rollback <N>` — undoes a regression-causing phase.
- `/align-park <id>` / `/align-unpark <id>` — manage parked findings.
- `/align-scan` — the audit that produces the next cadence's rows.

### Skills
- `.claude/skills/find-and-align/SKILL.md` — `scripts/align-sweep-gate.py` (checks 4–7 over the cumulative range).
- `.claude/skills/convention-oracle/SKILL.md` — the oracle map check 9 reads.

### Patterns
- `ai/patterns/align-ledger.md` — schema.
