---
name: align-ledger
description: "Pattern: Align ledger (state machine + record format for codebase-quality findings)"
kind: ai-pattern
pack: align
---

# Pattern: Align ledger (state machine + record format)

> **Hard rule:** Every detected finding has exactly one ledger row that transitions through the documented state machine; the ledger update is part of the same commit as the fix it records. Verbal status, "I'll update it later", and rows without `evidence:` / `closure_verb:` / `tier:` are forbidden. **The row shape below is the shape `scripts/validate-align-artifacts.sh` parses** — a row written any other way is not checked by anything, and a clean validator run over an unparseable ledger is the most dangerous output this pack can produce.

**When to apply**
- An align sweep spans more than ~10 findings or > 1 day of work — informal tracking will drift.
- Multiple agents / contributors will close findings concurrently — the ledger is the source of coordination.
- Phase gates require an audit trail (`/align-gate <N>` reads the ledger to refuse on blockers).

**When NOT to apply**
- A one-shot 2-finding spot fix via `/align-recheck <area>` — overhead exceeds value (the spot-fix mode tracks state in commit messages instead).
- A throwaway sweep against an experimental branch where outputs won't ship.

**Halt conditions / mandatory cites**
- Every finding row MUST cite source at `<path:line>` AND a closure verb from the closed 21-verb vocabulary in `align-discipline.md § Per-finding audit` halt #4. A verb outside that set is not an alignment fix.
- A row missing `tier:` or `closure_verb:` is a bug — reject the PR until filled.
- Hand-wave grep on `etc.`, `...`, `roughly`, `~N findings` is forbidden when claiming "phase done".
- `gaps_in != gaps_closed` halts the row at `find-and-align`'s RECORD step.
- If the ledger path or the oracle isn't extracted, halt before transitioning rows.
- A row whose id line does not match `- id: A<digits>` is invisible to the validator. If a scan emits zero parseable rows, that is a halt, not a pass.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Align` + `_extracted-idioms.md`.
>
> - **Ledger path**: `ai/align/ledger.md` (default; override only with strong reason).
> - **Finding inventory source**: `_extracted-idioms.md` + `ai/conventions.md` + `ai/architecture.md` (the gold-standard oracle).
> - **Update cadence**: on every commit that closes a finding; phase gate verifies aggregate state.
> - **Owner**: `<extracted>` (typically the engineering team owning the affected module; default = `_extracted-codebase.md § Owners`).

The ledger is the **single source of truth** for codebase-alignment state. It converts a multi-day quality sweep from vibes-based tracking into a checkable, queryable artifact. `/align-gate <N>` refuses the phase if the ledger is not fully updated.

## State machine

Ten states. Five on the main path, five to the side. `/align-scan` writes `detected`; `/align-plan` assigns a phase and writes `planned`; everything after that is a fix-loop or an audit transition.

```
  detected ──/align-plan──▶ planned ──/align-phase|/align-fast──▶ in-progress
                                                                      │
                        fix shipped; net-lines / idiom-citation pass   │
                                                                      ▼
                                                                   fixed
                                        re-detect green; CI green     │
                                                                      ▼
                       ┌── tier: heavy ──▶ pending-review ──approval──▶ verified   (terminal)
                       └── tier: trivial | standard ────────────────────▶

  side states (a row in any main-path state may transition to):

    halted                 an audit halt fired; ai/align/halts/<id>.md states the destination
                           → back to in-progress once cleared, or → parked

    parked                 /align-park <id> — deferred with a reason, a blocker category,
                           an unpark date, AND the prior status/phase it must return to
                           → /align-unpark <id> restores prior_status + prior_phase

    archived-pre-existing  re-detect returns 0 hits — the finding was a false positive.
                           Terminal. MUST carry no commit.

    archived-deprecated    won't-fix decision. Terminal. Requires `adr: ADR-NNN` and an
                           entry in ai/align/_history.md. There is no command for this
                           transition — it is a deliberate human decision, recorded by hand.
```

**Illegal transitions** (`@align-ledger-auditor` reconciliation 2 refuses these):
- `detected → fixed` with no `in-progress` and no commit — a status written by hand.
- `halted → verified` without an intervening `fixed`.
- `pending-review → verified` with `reviewer_approval` empty.
- `parked → fixed` without an `/align-unpark` entry in `ai/align/_history.md`.
- `archived-pre-existing` carrying a commit.
- Any transition into `archived-deprecated` without an `adr:` field.

## Record format

Every row is a YAML list item in `ai/align/ledger.md`. **The `- id: A<NNN>` list form is required** — it is what `discover_findings()` in `scripts/validate-align-artifacts.sh` matches, and a blank line ends the row.

```yaml
- id: A047
  class: security                  # one of the 11 universal classes, or `stack-specific`
  subclass: sql-injection          # optional; required where the class has sub-classes
  severity: critical               # security rows only: low | medium | high | critical
  scope: [<source-root>/reports/orders.<ext>]      # every file the fix may touch
  evidence:
    - <source-root>/reports/orders.<ext>:88        # each entry MUST resolve at HEAD
  closure_verb: parameterize                       # one of the closed 21
  idiom_cited: <source-root>/db/query.<ext>:14     # functional verbs that add lines
  shared_equivalent: <path>                        # replace-with-shared / dedupe rows
  tier: heavy                                      # trivial | standard | heavy
  tier_reason: "critical security — SQL injection on a production endpoint; auto-promoted"
  status: verified
  phase: 2
  detected_at: 2026-05-01T19:46:00Z
  gaps_in: 1
  gaps_closed: 1                                   # MUST equal gaps_in before `fixed`
  commit: <sha>                                    # the commit that closed this row
  impact_analysis_path: ai/align/impact/A047.md    # heavy rows
  reviewer_approval: <name>@<iso>                  # heavy rows, at pending-review → verified
  notes: |
    Replaced the interpolated WHERE clause with the project's parameterized-query
    primitive. Behaviour preserved for well-formed input; malformed input now rejects.
```

**Required fields per state** (cumulative — each state also carries everything the previous one required):

| State | Adds |
|---|---|
| `detected` | `id`, `class`, `scope`, `evidence`, `tier`, `tier_reason`, `detected_at`; `subclass` + `severity` for security |
| `planned` | `phase` |
| `in-progress` | `closure_verb`; `idiom_cited` for functional verbs that add lines; `shared_equivalent` for `replace-with-shared` / `dedupe` |
| `fixed` | `gaps_in`, `gaps_closed` (equal), `commit` |
| `pending-review` | `impact_analysis_path` (heavy rows only) |
| `verified` | `reviewer_approval` for heavy rows; re-detect green; CI green at `commit` |
| `halted` | `notes:` MUST cite the destination (re-run verb / `/setup-project --refine` / park) + `ai/align/halts/<id>.md` |
| `parked` | `parked_at`, `parked_reason`, `parked_blocker`, `parked_unpark_after`, **`prior_status`, `prior_phase`** |
| `archived-pre-existing` | nothing; MUST carry no `commit` |
| `archived-deprecated` | `adr: ADR-NNN` |

**`prior_status` and `prior_phase` are not optional on a parked row.** They are what `/align-unpark` restores; a parked row without them cannot be revived and is a permanent park wearing a temporary label. `/align-park` captures both at the moment it validates the transition.

## Automation hooks

| Command | Reads | Writes |
|---|---|---|
| `/align-scan` | source + oracle | fresh rows at `detected` |
| `/align-plan`, `/align-replan` | all rows | `phase`, `status: planned` |
| `/align-phase`, `/align-fast` | `phase: <N>` rows | `in-progress` → `fixed`, `gaps_*`, `commit` |
| `/align-gate <N>` | `phase: <N>` rows | nothing on REFUSE; one line to `gate-history.md` on PASS |
| `/align-park` / `/align-unpark` | one row | `parked` + `prior_*` / restore from `prior_*` |
| `/align-promote-tier` | one row | `tier`, `tier_history` |
| `/align-status`, `/align-final` | all rows | nothing (read-only) |

## Reporting views

By class · by tier · by phase · blocked (`halted` + `parked`) · security-only (`class: security`, ordered by `severity`) · perf-only. `/align-status` renders these; `@align-ledger-auditor` reconciles them against git, `halts/`, `impact/` and `plan.md`.

## Drift detection

The ledger and the repository can disagree, and the ledger is not automatically right:
- A row says `fixed` but no commit in range carries its id → **The Stale Ledger**; halt.
- A commit carries a row id that no row matches → orphan commit; halt.
- Three commits carry one row id → one-finding-per-commit violated → **The Bundled Phase**.
- A `parked` row of `class: security` older than its SLA → escalate; parking does not stop a security clock.

## See also

- `align-discipline.md` — closure-verb vocabulary, tier floor, the 11 per-finding halts.
- `align-guardrails.md` (sibling pattern) — the eight realism guards and the named anti-patterns this ledger's drift checks cite.
- `migration-ledger.md` (sibling pattern, migration pack) — the V1→V2 port equivalent: same tiering and audit shape, but its oracle is a second codebase, so it carries shadow / canary / cutover states this ledger has no analogue for.
- `find-and-align` skill — the per-finding fix loop that drives state transitions.
- `/align-gate <N>` — phase exit verifier; reads this ledger.
