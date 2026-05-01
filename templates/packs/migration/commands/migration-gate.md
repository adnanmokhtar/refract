---
description: Phase exit gate. Reads ledger + audits, confirms every feature in phase N is status=done with parity-test=passing. Refuses success on any failure. Read-only — never writes (except a one-line history entry).
kind: command
pack: migration
---

# /migration-gate <N>

## The Premise (read this first)

**Refuse on red. Phase exit is mechanical, not negotiated.** The gate runs the validator script, reads the ledger, reads the audits — and either passes or refuses. There is no "passed with caveats," no soft-pass, no "audit looks fine but the contract is missing 3 sections is okay." If any check in the tier-scoped matrix fails, the verdict is REFUSED and the next phase MUST NOT start. The gate writes nothing on REFUSED — only the one-line `_history.md` PASS entry on green.

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

**Tier-gated artifact verification**: for each feature in phase N, validate the artifact set required by the row's `tier:` field, NOT the heavy floor universally. See `migration-discipline.md` § Required artifacts per feature — tiered floor.

- **Heavy tier**: the full 13-check matrix below — contract (9 sections) + plan + ≥30 corpus + tolerance + perf-decisions + runbook + audit + ledger row + ADR (if intentional break).
- **Standard tier**: audit + 3-section contract (Inputs / Outputs / Known V1 bugs) + short plan + ≥10-fixture parity test + tolerance covering the 3-section contract's outputs + ledger row. Skip perf-decisions doc + runbook (folded into plan).
- **Trivial tier**: audit + ledger row + (optional) the actual code edit. Skip contract / plan / parity tests / perf-decisions / runbook.

Without a tier on the row, default to **trivial** (matches `migration-discipline.md`'s trivial-by-default rule). The gate validates only audit + ledger row in that case. If the row has known P0 / cross-repo blocker / contract break / write-path mutation findings AND no tier is set, the gate halts and asks the audit to set `tier: heavy` explicitly — it does NOT silently elevate.

Refusal language MUST name the tier in any error: "feature F0XX (tier: standard) missing required artifact: 3-section contract" — never refuse a trivial feature for missing a perf-decisions doc.

For each feature listed in phase N, run the **tier-scoped artifact verification** (full 13-check matrix below applies to heavy; standard + trivial subsets per the floor above):

### Ledger-level checks (5)
1. status = `done` OR `intentional-break` (with `ADR-NNNN` populated). **`status: halted` is BLOCKED** — a halted row is an incomplete port, not an advance-eligible one. Fix the halt, park the row (`/migration-park`), or accept an ADR before the phase can exit.
2. `gaps_in` and `gaps_closed` fields both present on the ledger row AND `gaps_in == gaps_closed`. A row where `gaps_in > gaps_closed` is **BLOCKED** even if `status: done` — it means at least one gap was silently skipped at RE-DETECT time. The validator's `check_gap_count_parity` enforces this.
3. parity_test = `passing`
4. ledger row required fields per state populated (per `migration-ledger.md` § Required fields per state)
5. cited ADR exists in `ai/decisions/` (when status = intentional-break)

### Artifact-existence checks (5)
5. `ai/migration/contracts/<feature>.md` exists
6. `ai/migration/plans/<feature>.md` exists
7. `<parity-test-root>/<feature>/` exists with `tolerance.yaml` and ≥30 corpus inputs (or record-replay setup file)
8. `ai/migration/perf-decisions/<feature>.md` exists
9. `ai/runbooks/migration-rollback-<feature>.md` exists AND `ai/migration/audits/<feature>.md` exists

### Content-quality checks (4)
10. Contract has all 9 sections populated; every `<path:line>` citation resolves (validator script runs this check)
11. tolerance.yaml covers every output field declared in the contract; every applied perf-decision has a measurement
12. Audit file enumerates per-axis comparison without `&...` / "etc." / "..." / `N+ filters` / `and so on` / `deferred to port-phase parity` / `by audit-by-inspection` hand-waves; for frontend features, the Frontend axes section is populated (form fields enumerated, UI affordances enumerated, templated query params enumerated)
13. **Audit provenance**: every audit MUST declare `auditor_agent_id: <Agent run ID>` (or `auditor_agent_id: rule-only-mode/<tool>/<UTC>` for rule-only tools) in YAML frontmatter. This proves the audit was produced by a `parity-auditor` agent dispatch (per `migration-phase.md § 4b`) and not echoed by an inline executor reading prior summaries (the F039 / Phase-6 trigger). Validator's `check_audit_provenance` enforces this.

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

The validator returns exit 0 if every check passes for every feature in phase N; non-zero with per-feature finding list otherwise. If the script is unavailable in the current tool environment, the executor MUST manually verify each check above against `migration-discipline.md` § "Per-feature audit — 11 hard halts" and § "Required artifacts per feature".

## Phase 4 — Generate (produce the output)

Build a gate report:

```markdown
# Phase <N> gate report — <YYYY-MM-DD>

Plan section: ai/migration/plan.md § Phase <N>
Features in phase: <Y>
Validator script result: PASS / FAIL (run-id <X>)

## Per-feature verification (14-check matrix)

| ID | Feature | status | gaps_in==gaps_closed | parity_test | contract | plan | corpus≥30 | tolerance | perf-decisions | runbook | audit | ADR | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F001 | auth-login | done | 8==8 ✓ | passing | ✓ 9-sections | ✓ | ✓ 47 | ✓ | ✓ measured | ✓ | ✓ | — | PASS |
| F002 | tenant-resolver | done | 5==5 ✓ | passing | ✓ | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ | — | PASS |
| F003 | shared-error-handler | failed | 4==4 ✓ | failing | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | **BLOCK (status=failed, parity failing)** |
| F004 | role-guards | halted | 6>5 ✗ | missing | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ MISSING | ✓ | — | **BLOCK (status=halted; gaps_in>gaps_closed; runbook missing)** |
| F005 | reports-orders | done | 12>10 ✗ | passing | ✗ 6/9 sections | ✓ | ✗ 12 inputs | ✓ | ✓ | ✓ | ✓ | — | **BLOCK (gaps_in>gaps_closed; contract incomplete + thin corpus)** |
| ... | | | | | | | | | | | | |

## Blocking issues (per check)

- F003: status=failed + parity_test failing. See ai/migration/audits/F003.md § Hard-halt findings. Fix the port; re-run /find-and-fix F003.
- F004: status=halted (1 open gap — gaps_in=6 gaps_closed=5); rollback runbook missing. Assign the deferred gap a destination (target phase, ADR, or /migration-park) before this phase can exit.
- F005: gaps_in=12 gaps_closed=10 (2 gaps silently skipped at RE-DETECT); contract has 6/9 sections (missing: Side effects, Caller assumptions, Known V1 bugs); corpus has 12 inputs (need ≥30 OR record-replay setup).

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
- If a specific feature failed multiple times before passing → log the pattern for `ai/failures/`.
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
- **`status: halted` BLOCKS the phase regardless of tier.** A halted row is an incomplete port — it MUST be resolved (fix the gaps, `/migration-park`, or accepted ADR) before the phase gate passes. The gate does not skip halted rows.
- **`gaps_in == gaps_closed` is a ledger integrity check.** It applies at ALL tiers, even trivial. If either field is missing or unequal, the row is BLOCKED. This catches RE-DETECT step bypasses that let partial fixes advance.
- **All checks are mandatory FOR THE ROW'S TIER.** Heavy = 14-check matrix in full. Standard = audit + 3-section contract + short plan + ≥10 fixtures + tolerance + ledger row. Trivial = audit + ledger row only (but gaps_in == gaps_closed still required). Content quality (citation resolution, tolerance covers outputs, audit enumerates without hand-waves) applies within the tier's required sections. See `migration-discipline.md` § Required artifacts per feature — tiered floor.
- **Audit-file presence is mandatory.** A `done` row without an audit file = data integrity failure → REFUSE. A blank or hand-waved audit file = data integrity failure → REFUSE.
- **Contract-completeness is mandatory.** A contract missing any of the 9 required sections, or with unresolved `<path:line>` citations, fails the gate even if the audit file says "parity-clean".
- **ADR existence is verified.** Cited `intentional-break: ADR-NNNN` must point to a real file in `ai/decisions/` with status: Accepted.
- **Validator script is the source of truth.** When `scripts/validate-migration-artifacts.sh` is available, its exit code IS the gate's verdict. When unavailable (rule-only tools), the executor manually verifies each check and records the verification.

## Related

- `/migration-phase <N>` — runs before this gate; produces what's audited.
- `/migration-final` — runs after all gates; the final sweep across phases.
- `/migration-rollback <N>` — use if this gate refuses and the phase needs reverting.
- `ai/migration/_history.md` — append-only log this command writes one line to on PASS.
