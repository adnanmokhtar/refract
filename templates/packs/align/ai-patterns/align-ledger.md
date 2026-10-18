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
- Every finding row MUST cite source at `<path:line>`, the **oracle** that declares the convention (`oracle:` with its quote or rule id, and `oracle_tier:`), and a closure verb from the closed 21-verb vocabulary in `align-discipline.md § Per-finding audit` halt #4. A verb outside that set is not an alignment fix; a row whose quote does not resolve is AL-01 and is dropped, never written.
- A row missing `tier:` or `closure_verb:` is a bug — reject the PR until filled.
- Hand-wave grep on `etc.`, `...`, `roughly`, `~N findings` is forbidden when claiming "phase done".
- `gaps_in != gaps_closed` halts the row at `find-and-align`'s RECORD step.
- If the ledger path or the oracle isn't extracted, halt before transitioning rows.
- A row whose id line does not match `- id: A<digits>` is invisible to the validator. If a scan emits zero parseable rows, that is a halt, not a pass.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Align` + `_extracted-idioms.md`.
>
> - **Ledger path**: `ai/align/ledger.md` (default; override only with strong reason).
> - **Finding inventory source**: the oracle map `convention-oracle` § 0 builds (lint configs at `error`, human-written lines, ADRs, the glossary, tokens, named wrappers), with the inventory fallback `_extracted-idioms.md` → `codebase-profile.md` → `ai/conventions.md`.
> - **Update cadence**: on every commit that closes a finding; phase gate verifies aggregate state.
> - **Owner**: `<extracted>` (typically the engineering team owning the affected module; default = `_extracted-codebase.md § Owners`).

The ledger is the **single source of truth** for codebase-alignment state. It converts a multi-day quality sweep from vibes-based tracking into a checkable, queryable artifact. `/align-gate <N>` refuses the phase if the ledger is not fully updated.

## State machine

Fourteen states: five on the main path, nine to the side. `/align-scan` writes `detected`; `/align-plan` assigns a phase and writes `planned`; everything after that is a fix-loop or an audit transition.

```
  detected ──/align-plan──▶ planned ──/align-phase|/align-fast|/align --from-audit──▶ in-progress
                                                                      │
                     find-and-align ladder L0–L13 PASS (or PASS-flagged)│
                                                                      ▼
                                                                   fixed
                                        re-detect green; CI green     │
                                                                      ▼
                       ┌── tier: heavy ──▶ pending-review ──approval──▶ verified   (terminal)
                       └── tier: trivial | standard ────────────────────▶

  side states (a row in any main-path state may transition to):

    halted                 a ladder step or an audit halt fired; ai/align/halts/<id>.md states the
                           destination → back to in-progress once cleared, or → parked

    routed                 the row's closer is another pack's fix command (/security-fix, /perf-fix,
                           /db-fix, /quality-fix, /frontend-fix, /backend-fix) or /polish, /unify-surfaces,
                           /optimize, /refactor. `routed:` names it and the audit id. Terminal for align;
                           MUST carry no commit

    pending-approval       proof_class VC with no `approval:` (a visible change). No commit until a named
                           human fills `approval: <name>@<iso>`; then → in-progress. An agent never fills it

    pending-ratification   the oracle is T2g (generated). One probe per rule ("confirm ai/conventions.md:<n>");
                           after a human ratifies the line outside the generated markers → detected (re-verify)

    parked                 /align-park <id> — deferred with a reason, a blocker category,
                           an unpark date, AND the prior status/phase it must return to
                           → /align-unpark <id> restores prior_status + prior_phase

    refuted                the verifier refuted the candidate (refute-before-report § 5): `bucket: refuted`,
                           `refuted_gate:` and a one-line reason. Terminal. MUST carry no commit. Never
                           written as archived-pre-existing

    archived-pre-existing  AGED OUT ONLY: re-detect ran, its rule matched files, and found 0 hits —
                           someone else fixed it. Terminal. MUST carry no commit. Not for a false
                           positive (that is `refuted`) and not when the detector matched 0 files

    archived-deprecated    won't-fix decision. Terminal. Requires `adr: ADR-NNN` and an
                           entry in ai/align/_history.md. There is no command for this
                           transition — it is a deliberate human decision, recorded by hand.
```

**Illegal transitions** (`@align-ledger-auditor` reconciliation 2 refuses these):
- `detected → fixed` with no `in-progress` and no commit — a status written by hand.
- `halted → verified` without an intervening `fixed`.
- `pending-review → verified` with `reviewer_approval` empty.
- `pending-approval → in-progress` (or `fixed`) with `approval` empty, or with an approval an agent wrote.
- `pending-ratification → in-progress` while the oracle line is still inside the generated markers.
- `parked → fixed` without an `/align-unpark` entry in `ai/align/_history.md`.
- `archived-pre-existing`, `refuted` or `routed` carrying a commit.
- `refuted → archived-pre-existing`: a refutation is not an age-out.
- Any transition into `archived-deprecated` without an `adr:` field.

## Record format

Every row is a YAML list item in `ai/align/ledger.md`. **The `- id: A<NNN>` list form is required** — it is what `discover_findings()` in `scripts/validate-align-artifacts.sh` matches, and a blank line ends the row.

```yaml
- id: A047
  al_class: AL-11                  # AL-01 … AL-34 (align-detect § The class ledger)
  class: reinvented-wrapper        # legacy name, still read; the validator maps it (§ Legacy class names)
  oracle: 'eslint.config.mjs:14 "no-restricted-imports: ky → use @acme/http"'   # <path>:<line> "<quote>" | <tool>:<rule-id>
  oracle_tier: T1                  # T1 | T2 (human-written) | T2g (generated → pending-ratification)
  owner: align                     # align | ui-ux | code-quality | frontend | backend | security | performance | database
  scope: [apps/web/src/features/orders/api.ts]     # every file the fix may touch
  evidence:
    - apps/web/src/features/orders/api.ts:3        # each entry MUST resolve at HEAD
  closure_verb: replace-with-shared                # one of the closed 21
  shared_equivalent: packages/http/src/index.ts    # replace-with-shared / dedupe rows
  idiom_cited: packages/http/src/index.ts:1        # functional verbs that add lines
  proof_class: EQ                                  # EQ (zero diff) | VC (approved visual diff) | FN (behaviour test)
  approval: ""                                     # VC rows: <name>@<iso>, written by a human only
  detector: wrapper-adoption-scan §1
  detector_cmd: "rg -n --pcre2 \"from\\s+['\\\"]ky['\\\"]\" apps/web/src"   # re-run verbatim at L5 (V391)
  routed: ""                                       # owner rows: the closer command + audit id
  tier: standard                                   # trivial | standard | heavy
  tier_reason: "1 file; T1 rule; EQ swap through the wrapper's defaults"
  status: verified
  phase: 2
  detected_at: 2026-10-18T09:12:00Z
  gaps_in: 1
  gaps_closed: 1                                   # MUST equal gaps_in before `fixed`
  commit: <sha>                                    # the commit that closed this row
  proof: "V400 V391 V392 — ai/align/runs/ladder-A047.json"
  notes: |
    ky import re-routed through @acme/http; the wrapper's defaults reproduce the call's options.
```

A routed owner row keeps the same shape with `owner:` set, `routed: /frontend-fix ai/audits/<date>-align.md#F-07` and `status: routed`. A refuted candidate written for the record carries `status: refuted`, `bucket: refuted`, `refuted_gate:` and `notes:` with the one-line reason.

**Required fields per state** (cumulative — each state also carries everything the previous one required):

| State | Adds |
|---|---|
| `detected` | `id`, `al_class` (or a legacy `class`), `oracle`, `oracle_tier`, `owner`, `scope`, `evidence`, `detector_cmd`, `tier`, `tier_reason`, `detected_at` |
| `planned` | `phase` |
| `in-progress` | `closure_verb`, `proof_class`; `idiom_cited` for functional verbs that add lines; `shared_equivalent` for `replace-with-shared` / `dedupe`; `approval` for a VC row |
| `fixed` | `gaps_in`, `gaps_closed` (equal), `commit`, `proof` (the V-numbers that passed and the ladder file) |
| `pending-review` | `impact_analysis_path` (heavy rows only) |
| `verified` | `reviewer_approval` for heavy rows; re-detect green; CI green at `commit` |
| `halted` | `notes:` MUST cite the destination (re-run verb / `/setup-project --refine` / park) + `ai/align/halts/<id>.md` |
| `parked` | `parked_at`, `parked_reason`, `parked_blocker`, `parked_unpark_after`, **`prior_status`, `prior_phase`** |
| `routed` | `routed: <command> <audit id>`, `owner`; MUST carry no `commit` |
| `pending-approval` | `proof_class: VC`, the diff images path in `notes`; `approval` empty until a human fills it |
| `pending-ratification` | `oracle_tier: T2g`, the ratification probe in `notes` |
| `refuted` | `bucket: refuted`, `refuted_gate`, a one-line reason in `notes`; MUST carry no `commit` |
| `archived-pre-existing` | the re-detect line (`matched N files · 0 hits`); MUST carry no `commit` |
| `archived-deprecated` | `adr: ADR-NNN` |

**`prior_status` and `prior_phase` are not optional on a parked row.** They are what `/align-unpark` restores; a parked row without them cannot be revived and is a permanent park wearing a temporary label. `/align-park` captures both at the moment it validates the transition.

## Legacy class names

Rows written before the AL ids carry `class:` only. The validator and every reader map them (`align-detect` § The legacy class map): `reinvented-wrapper` / `raw-library-component` → AL-11 · `drift` → AL-16 unless the row names its AL id · `stack-specific` / `design-token-drift` → AL-05 · `i18n-key-drift` → AL-26 · `permission-gate-drop` / `default-true-prop` → AL-15 · `a11y-violation` → AL-28. The classes `silent-catch`, `unhandled-io`, `dead-code`, `duplicated-logic`, `over-abstraction`, `solid-violation`, `clean-code`, `performance` and `security` are **owner** classes: an open row carrying one is re-written as `status: routed` to its owner's fix command, never closed here. `duplicated-surface-styles` was never a class: re-read it as AL-11 or AL-12, or route it to `/unify-surfaces`.

## Automation hooks

| Command | Reads | Writes |
|---|---|---|
| `/align-scan` | source + oracle map | fresh rows at `detected`; T2g groups at `pending-ratification`; refuted candidates in the report |
| `/align --from-audit` | an audit report's `## What to do next` | `in-progress` → `fixed` / `routed` / `pending-approval` |
| `/align-plan`, `/align-replan` | all rows | `phase`, `status: planned` |
| `/align-phase`, `/align-fast` | `phase: <N>` rows | `in-progress` → `fixed`, `gaps_*`, `commit` |
| `/align-gate <N>` | `phase: <N>` rows | nothing on REFUSE; one line to `gate-history.md` on PASS |
| `/align-park` / `/align-unpark` | one row | `parked` + `prior_*` / restore from `prior_*` |
| `/align-promote-tier` | one row | `tier`, `tier_history` |
| `/align-status`, `/align-final` | all rows | nothing (read-only) |

## Reporting views

By AL class · by owner · by tier · by phase · by proof class · blocked (`halted` + `parked` + `pending-approval` + `pending-ratification`) · routed (by closer command). `/align-status` renders these; `@align-ledger-auditor` reconciles them against git, `halts/`, `impact/` and `plan.md`.

## Drift detection

The ledger and the repository can disagree, and the ledger is not automatically right:
- A row says `fixed` but no commit in range carries its id → **The Stale Ledger**; halt.
- A commit carries a row id that no row matches → orphan commit; halt.
- Three commits carry one row id → one-finding-per-commit violated → **The Bundled Phase**.
- A row with `routed:` set but `status` still open, or a `routed` row carrying a commit → the closure happened in the wrong command.
- A `pending-approval` row whose `approval:` was filled in the same commit as the fix → an agent signed its own visible change.

## See also

- `align-discipline.md` — closure-verb vocabulary, tier floor, the per-finding halts, EQ / VC / FN.
- `align-guardrails.md` (sibling pattern) — the eight realism guards and the named anti-patterns this ledger's drift checks cite.
- `migration-ledger.md` (sibling pattern, migration pack) — the V1→V2 port equivalent: same tiering and audit shape, but its oracle is a second codebase, so it carries shadow / canary / cutover states this ledger has no analogue for.
- `find-and-align` skill — the per-finding fix loop that drives state transitions.
- `/align-gate <N>` — phase exit verifier; reads this ledger.
