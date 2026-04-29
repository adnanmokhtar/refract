---
description: Phase exit gate. Reads ledger + audits, confirms every feature in phase N is status=done with parity-test=passing. Refuses success on any failure. Read-only — never writes (except a one-line history entry).
kind: command
pack: migration
---

# /migration-gate <N>

The phase exit verifier. Run after `/migration-phase <N>`. Refuses pass on any blocking issue. The next phase MUST NOT start until this is green.

## Pre-requisites

- Argument N is a valid phase from `ai/migration/plan.md`.
- `/migration-phase <N>` has been run.

## Phase 1 — Understand (the ask)

Inputs:
- `<N>` — phase number (required).
- `ai/migration/plan.md` — phase definition (which features are in phase N).
- `ai/migration/ledger.md` — feature status.
- `ai/migration/audits/` — per-feature audit files.

## Phase 2 — Organize (decompose the work)

For each feature listed in phase N, run the **12-check artifact verification**:

### Ledger-level checks (4)
1. status = `done` OR `intentional-break` (with `ADR-NNNN` populated)
2. parity_test = `passing`
3. ledger row required fields per state populated (per `migration-ledger.md` § Required fields per state)
4. cited ADR exists in `ai/decisions/` (when status = intentional-break)

### Artifact-existence checks (5)
5. `ai/migration/contracts/<feature>.md` exists
6. `ai/migration/plans/<feature>.md` exists
7. `<parity-test-root>/<feature>/` exists with `tolerance.yaml` and ≥30 corpus inputs (or record-replay setup file)
8. `ai/migration/perf-decisions/<feature>.md` exists
9. `ai/runbooks/migration-rollback-<feature>.md` exists AND `ai/migration/audits/<feature>.md` exists

### Content-quality checks (3)
10. Contract has all 9 sections populated; every `<path:line>` citation resolves (validator script runs this check)
11. tolerance.yaml covers every output field declared in the contract; every applied perf-decision has a measurement
12. Audit file enumerates per-axis comparison without `&...` / "etc." / "..." hand-waves; for frontend features, the Frontend axes section is populated (form fields enumerated, UI affordances enumerated, templated query params enumerated)

A feature failing any check is **BLOCKED**. The phase REFUSES until every blocked feature is resolved (re-port, ADR, deprecate, park, or restart `/migration-phase <N> --feature=<id>`).

## Phase 3 — Retrieve (read the right context)

- `ai/migration/plan.md` (phase N section).
- `ai/migration/ledger.md` (full).
- `ai/migration/contracts/<feature>.md` for every feature in phase N.
- `ai/migration/plans/<feature>.md` for every feature in phase N.
- `ai/migration/audits/<feature>.md` for every feature in phase N.
- `ai/migration/audits/phase-<N>.md` (phase summary).
- `ai/migration/perf-decisions/<feature>.md` for every feature in phase N.
- `ai/runbooks/migration-rollback-<feature>.md` for every feature in phase N.
- `<parity-test-root>/<feature>/tolerance.yaml` for every feature.
- `<parity-test-root>/<feature>/inputs/` directory listing (count entries).
- ADRs cited as `intentional-break` justification.

**Run validator script** (universal, runs from any tool):

```bash
~/.claude/scripts/validate-migration-artifacts.sh --phase=<N> --strict
```

The validator returns exit 0 if every check passes for every feature in phase N; non-zero with per-feature finding list otherwise. If the script is unavailable in the current tool environment, the executor MUST manually verify each check above against `migration-discipline.md` § "Per-feature audit — 10 hard halts" and § "Required artifacts per feature".

## Phase 4 — Generate (produce the output)

Build a gate report:

```markdown
# Phase <N> gate report — <YYYY-MM-DD>

Plan section: ai/migration/plan.md § Phase <N>
Features in phase: <Y>
Validator script result: PASS / FAIL (run-id <X>)

## Per-feature verification (12-check matrix)

| ID | Feature | status | parity_test | contract | plan | corpus≥30 | tolerance | perf-decisions | runbook | audit | ADR | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F001 | auth-login | done | passing | ✓ 9-sections | ✓ | ✓ 47 | ✓ | ✓ measured | ✓ | ✓ | — | PASS |
| F002 | tenant-resolver | done | passing | ✓ | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ | — | PASS |
| F003 | shared-error-handler | failed | failing | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | **BLOCK** |
| F004 | role-guards | done | passing | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ MISSING | ✓ | — | **BLOCK (runbook missing)** |
| F005 | reports-orders | done | passing | ✗ 6/9 sections | ✓ | ✗ 12 inputs | ✓ | ✓ | ✓ | ✓ | — | **BLOCK (contract incomplete + thin corpus)** |
| ... | | | | | | | | | | | | |

## Blocking issues (per check)

- F003: parity_test failing. See ai/migration/audits/F003.md § Hard-halt findings.
- F004: rollback runbook ai/runbooks/migration-rollback-F004.md does not exist.
- F005: contract has 6/9 sections (missing: Side effects, Caller assumptions, Known V1 bugs); corpus has 12 inputs (need ≥30 OR record-replay setup).

## Verdict

**REFUSED** — 3 blocking issues across 3 features. Fix and re-run /migration-phase <N>, then re-run /migration-gate <N>.
```

OR if everything passes:

```markdown
## Verdict

**PASS** — phase <N> meets exit criteria. Safe to start phase <N+1>.

Append-once entry written to ai/migration/_history.md:
  <YYYY-MM-DD> | phase <N> | passed | <Y> features | duration: <X> days
```

## Phase 5 — Update (persist changes to the knowledge base)

ONLY on PASS:
- `ai/migration/_history.md` — append one line. (Append-only audit trail of phase completions.)
- `ai/migration/ledger.md` — set per-row `phase_passed_at` timestamp (managed-block update).

On REFUSED → no writes.

## Phase 6 — Validate (verify correctness)

This phase IS the verification — nothing further.

## Phase 7 — Improve (feed the learning loop)

- If gate passes after >2 retries → flag the phase complexity for future estimates.
- If a specific feature failed multiple times before passing → log the pattern for `ai/_baseline/failures/`.
- If `intentional-break` ADRs cluster around one domain → that's an architectural signal worth a follow-up review.

## Output to user

On PASS:
```
Phase <N>: PASS
  Features: <Y>
  All status=done OR intentional-break (with ADR)
  All parity tests passing
  All audits present

Next: /migration-phase <N+1>
```

On REFUSED:
```
Phase <N>: REFUSED — <count> blocking issues.

  <list of failing features with reason + remediation pointer>

Fix the blockers; re-run /migration-phase <N>; then re-run /migration-gate <N>.
```

## Hard rules

- **Read-only on REFUSED.** Never modifies ledger or any artifact when refusing.
- **One row per success.** `_history.md` is append-only; no edits to past entries.
- **No partial passes.** A phase with ANY blocking issue REFUSES. There is no "passed with caveats" — fix it or document an `intentional-break` ADR.
- **All 12 checks are mandatory.** File presence is necessary but NOT sufficient. Content quality (9 contract sections, citation resolution, ≥30 corpus, tolerance covers outputs, perf measurements present, audit enumerates without hand-waves) is verified.
- **Audit-file presence is mandatory.** A `done` row without an audit file = data integrity failure → REFUSE. A blank or hand-waved audit file = data integrity failure → REFUSE.
- **Contract-completeness is mandatory.** A contract missing any of the 9 required sections, or with unresolved `<path:line>` citations, fails the gate even if the audit file says "parity-clean".
- **ADR existence is verified.** Cited `intentional-break: ADR-NNNN` must point to a real file in `ai/decisions/` with status: Accepted.
- **Validator script is the source of truth.** When `scripts/validate-migration-artifacts.sh` is available, its exit code IS the gate's verdict. When unavailable (rule-only tools), the executor manually verifies each check and records the verification.

## Related

- `/migration-phase <N>` — runs before this gate; produces what's audited.
- `/migration-final` — runs after all gates; the final sweep across phases.
- `/migration-rollback <N>` — use if this gate refuses and the phase needs reverting.
- `ai/migration/_history.md` — append-only log this command writes one line to on PASS.
