---
description: Enforce conventions the project ALREADY has, project-wide or across several areas. Triggers — 'align the app to the design system', 'convention drift across the auth pages', 'some files do X, some do Y', 'stop reinventing the shared wrapper', and the same asks with a surface noun in them ('our buttons ignore the spacing tokens on the auth pages'). The test is the REMEDY, never which nouns appear — trigger when the fix is to apply something the project ALREADY documents (a token, an a11y rule, a naming rule, a layer boundary, an already-named shared helper) in place, with the wrapper left as it is. Do NOT trigger when the fix is that every instance of ONE surface type (tables / forms / headers / tabs / filters / buttons / validation) must end up going through ONE canonical shared implementation that gets extracted, extended or migrated onto — one shared wrapper for six of those categories, and for validation the one 3-part pipeline (validator composable + error primitives + API-error mapper) — including in some-files-do-X form such as 'some pages use the shared PageHeader and some roll their own', where the rolled-own headers have to be reconciled INTO the canonical shape and the closed 21-verb set cannot do that — its halt 10 refuses a fix that introduces a new shared helper and its halt 5 refuses net-positive lines on a structural finding; that is /unify-surfaces. Do NOT trigger on API envelope, error-contract, endpoint-naming or pagination uniformity — the closed 21-verb set has no envelope verb, and its rename verb only APPLIES a naming convention the project already documents rather than choosing one for an API surface, so /polish owns those. Do NOT trigger to INTRODUCE finish that does not exist yet (a new token, a missing state, creative visual work) — that is /polish. Not perf or architecture (/optimize), not one narrow area (/align-recheck).
compatibility: Requires _extracted-idioms.md or codebase-profile.md populated as the convention oracle — with neither there is nothing to enforce against. Mechanical CI green and a clean tree, or --allow-dirty. Any stack. Net structural lines are held at or below zero, so nothing new is invented. validate-align-artifacts.sh is agent-invoked, not run automatically.
kind: command
pack: orchestration
---

# /align [<scope>]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../templates/snippets/plan-flag.md). `/align <scope> --plan` runs the convention scan, writes the eight-header handoff plan, and exits before any edit — executable later via `/execute-plan <file>`. The write-and-stop behaviour is specified in § Phase 3.5 — Handoff.
>
> **Note — two distinct "plan" artifacts.** `--plan` writes a one-off **handoff doc** to `.claude/plans/align-<short-slug>-<YYYYMMDD-HHmm>.md` (the universal plan-flag location and naming, for review / `/execute-plan`). This is NOT the pack's executable `ai/align/plan.md` (the phased plan produced by `/align-plan` that `/align-fast <N>` consumes). The handoff doc carries the eight canonical headers and is a snapshot for an executor; `ai/align/plan.md` is the live, ledger-coupled plan and `/execute-plan` cannot read it.

## What this does

**Single command. Detect where the code doesn't follow the project's structure + fix it.** Deep multi-agent scan + fix. Whole project or scoped.

The agent:
1. **Reads the project's structure rules** from `_extracted-idioms.md` / `codebase-profile.md` / `ai/conventions.md` / `ai/architecture.md` / `.claude/rules/*`. This is the truth about how THIS project is supposed to look.
2. **Scans every file** for violations of those rules.
3. **Fixes violations in parallel** by routing each one to the right closure verb (replace-with-shared, remove, dedupe, etc.).

Detects + fixes:
- **Layer violations** — components importing services directly (must route through the project's data-access layer); services importing UI-framework primitives (must stay framework-agnostic); core/ importing UI; circular dependencies.
- **Module-shape violations** — feature module missing required directories; cross-module imports that should go through the project's shared/ layer; modules using global state when local would do.
- **Naming convention violations** — files / classes / types / locale keys not matching the project's pattern (per `_extracted-idioms.md § Naming`).
- **Reinvented wrappers** — custom code where a shared component / util / hook exists in the project's gold-standard inventory.
- **Silent catches** — empty error-swallow blocks not routed through the project's error handler.
- **Happy-path-only I/O** — network / DB / queue / file call sites with no error path at all (no catch, no error-return check, no timeout, no failure state surfaced) — the absent-error-path sibling of silent catches. Fix: route through the project's wrapped I/O primitive.
- **Forbidden imports** — HTTP clients constructed outside the project's API-core module; cross-import V1↔V2; unauthorized libraries.
- **Default-true wrapper props left implicit** — wrapper components rendered without explicit `show-*="false"` / `can-*="false"` when affordance should be hidden.
- **Permission-gate drops** — actions rendered without the project's permission-gate primitive.
- **Lifecycle hook misuse** — cached children that fetch data using only the mount hook (need the mount-AND-reactivate hook pair, per the project's framework conventions).
- **Design-token drift** — hardcoded colors / spacing where a token **already exists** → `replace-with-shared` (swap the literal for the existing token). *Enforce-existing only.* Introducing a NEW token (no equivalent exists yet) is creative finish → `/polish`.
- **i18n key drift** — hardcoded user-visible strings where the project's i18n primitive already exists → route through it. *Enforce-existing only.*
- **a11y violations** — restoring the project's **existing** a11y convention where a site dropped it (missing alt, missing focus state already standard elsewhere, contrast that violates a defined token). *Enforce-existing only.* Designing a NEW a11y pattern the project doesn't yet have → `/polish`.
- **Allowlist violations** — state stores outside the project's allowed list; routes outside the configured router; etc.

This is **structure enforcement** — no creative work, no new abstractions, just "make the code follow the project's stated structure."

## When to use

- "Align the whole project to the design system." → `/align`
- "Align the orders module." → `/align the orders module`
- "Fix convention drift across auth pages." → `/align the auth pages`

## When NOT to use

- For visual / look enhancement → `/enhance-ui` or `/ui-sweep` (creative work).
- For V1→V2 port → `/migrate`.
- For performance / clean-code / SOLID work → `/optimize`, which *discovers* the smell and may design a new shape for it. **Carve-out (the same enforce-existing rule that governs tokens, a11y, layer, perf and security):** `/align` may close a clean-code or SOLID finding **only** where the target idiom is already named in `_extracted-idioms.md` — move the long function into the shared helper that exists (`extract-to-shared`), snap the magic number to the constant module that exists (`inline-magic-to-named-const`), apply the documented naming convention (`rename`), split a class along responsibilities the idioms already name (`split-extract`). Inventing the helper, the module, the convention or the abstraction is out of lane; hand back to `/optimize`. See the shared finding-class rows in [`templates/tool-adapters/_orchestration-sync.md`](../templates/tool-adapters/_orchestration-sync.md).
- For new features → `/add-feature`.
- **For introducing NEW finish → `/polish`.** This is the canonical split: **`/align` enforces EXISTING tokens / a11y / conventions** (mechanical drift → shared primitive, via `replace-with-shared`); **`/polish` introduces NEW finish** (new tokens, new states, new visual polish). If a fix would *add* a design token that doesn't exist yet, *introduce* a missing-state pattern, or do creative visual work, it is a `/polish` job, not an `/align` job. See the boundary table in [`templates/tool-adapters/_orchestration-sync.md`](../templates/tool-adapters/_orchestration-sync.md).

## Args

- `<scope>` (optional) — natural-language description OR explicit path. If omitted: whole project.

Examples:
```
/align                                  # whole project
/align the orders module                # one module
/align the sidebar                      # one component
/align <modules-root>/auth/             # explicit path
/align "auth pages including login"     # multi-page scope
```

## What happens internally (silent)

**Discipline:** MUST read [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) before generating code fixes.

1. **Scan** — runs convention detectors: drift (vs `ai/conventions.md` / `ai/architecture.md`), reinvented-wrapper, silent-catch, unhandled-io (happy-path-only I/O call sites). Plus stack-conditional UI/UX detectors for `frontend-*` (a11y, design-token-drift, i18n-key-drift, raw-library-component, lifecycle-hook-wrong, default-true-prop, permission-gate-drop).
2. **Resolve scope** — semantic resolution.
3. **Plan internally** — group by class + page/domain (UI/UX findings group by page; structural by class).
4. **Multi-agent parallel fix** — dispatch one agent per finding cluster. Closure verbs are mechanical — **only** from the closed **21-verb** set in [`templates/packs/align/rules/align-discipline.md`](../templates/packs/align/rules/align-discipline.md) § Closure-verb vocabulary / procedures. The set partitions as:
   - **5 structural** (entropy-reducing — net-lines ≤ 0): `remove`, `inline`, `dedupe`, `rename-comment-out`, `replace-with-shared`.
   - **16 functional** (correctness-improving — small + line budget when added lines cite an idiom): `add-gate`, `parameterize`, `escape`, `move-to-secrets`, `add-validator`, `parallelize`, `batch`, `project-columns`, `add-index`, `cache-with-explicit-ttl`, `extract-to-shared`, `split-extract`, `inline-magic-to-named-const`, `inline-filter-to-query`, `bump-dep`, `rename`.
   - This partition matches `validate-align-artifacts.sh` (`STRUCTURAL_VERBS` / `FUNCTIONAL_VERBS`) and `align-discipline.md` exactly.
5. **Verify continuously** — lint + typecheck + scoped tests + (frontend) a11y check + bundle-size after each fix.
6. **Self-resolve common questions** — convention is the truth. Project's idiom inventory (`_extracted-idioms.md` / `codebase-profile.md`) is the oracle. No "is this the right pattern" prompts.
7. **Halt only on genuine blockers**:
   - Idiom missing for a fix (project has no shared button when fix needs one — surfaces "/setup-project --refine to add primitive first").
   - Visual regression baseline drift > threshold (frontend; surfaces "review snapshots").
   - Behavior change risk (re-classify as refactor; user decides).

## Phase 3.5 — Handoff (`--plan` only)

`--plan` is **not** a louder `--dry-run`. It runs steps 1–3 (scan → resolve scope → plan internally) above, makes **no edit**, and writes a plan file that `/execute-plan` — or any other tool, or a human — can implement later.

1. **Read-only phases only.** No fix agent is dispatched, no commit is made, `ai/align/ledger.md` is not advanced and `ai/align/progress.md` is not re-projected.
2. **Expand the internal plan into the canonical handoff format.** All **eight** headers are mandatory — `## Goal` / `## Context` / `## Inputs` / `## Outputs` / `## Constraints` / `## Steps` / `## Verification` / `## Status` — plus the `Plan ID`. `/execute-plan` halts on a file missing any one of them ([`templates/repo-baseline/.claude/commands/execute-plan.md`](../templates/repo-baseline/.claude/commands/execute-plan.md) § Mechanical halt), so an eight-header file is the contract, not a nicety. `## Approach` and `## Known unknowns` are accepted optional extras.
3. **Map this command's own vocabulary onto those headers.** Each detected finding becomes one `## Steps` entry with its closure verb; the files it touches become `## Outputs`; "closure verbs only from the closed 21-verb set" and "net structural lines ≤ 0" become `## Constraints`; the project's lint / typecheck / scoped-test commands (plus the a11y check on `frontend-*`) become `## Verification`; the oracle files that defined the conventions become `## Inputs`.
4. **Write** to `.claude/plans/align-<short-slug>-<YYYYMMDD-HHmm>.md`, **print** path + Plan ID + a one-line summary, and **exit before Phase 4 (Generate)** — nothing edited, nothing committed, no changelog entry.

Full flag contract: [`templates/snippets/plan-flag.md`](../templates/snippets/plan-flag.md). Field-by-field format: [`templates/canonical-command-template.md`](../templates/canonical-command-template.md) § "Phase 3.5 — Handoff".

## Progress tracking (multi-day workflow)

**Single source of truth: `ai/align/ledger.md`** (finding-level, validated by `validate-align-artifacts.sh`). `ai/align/progress.md` is a derived, human-readable *module roll-up* — a convenience view, NOT an independent source of truth. It MUST be kept reconciled with the ledger; the ledger wins on every disagreement.

> **Why this matters.** A run that marks a module `done` in `progress.md` while the ledger still holds non-terminal rows (`detected` / `in-progress` / `halted`) for that module is a **false-complete** — the headline says clean, the validated ledger says otherwise. `progress.md` is therefore always projected FROM the ledger, never asserted independently. The validator enforces this: when both files exist, a module marked `done` in `progress.md` MUST have zero non-terminal ledger rows in its scope (see `validate-align-artifacts.sh § check_progress_ledger_reconciliation`).

### How it works

- **First run** → builds module inventory in the ledger, then projects the `progress.md` roll-up (all `pending`). Runs first module.
- **Subsequent runs** → reads the ledger, picks the next module whose ledger rows are not all terminal (or use `<scope>` arg). Modules whose every ledger row is terminal (`verified` / `archived-*` / `parked`) are skipped automatically; `progress.md` is re-projected to match.
- **`/align --status`** → read-only progress report **derived from `ai/align/ledger.md`** (terminal-vs-non-terminal row counts per module), reconciled against `progress.md`. If the two disagree, `--status` reports the ledger truth and flags the drift ("progress.md stale — re-projecting from ledger"). No work done.

### Progress file shape (derived roll-up — projected from the ledger)

```markdown
# Align progress  (derived from ai/align/ledger.md — do not hand-edit)

Started: 2026-05-02
Codebase: <project-root>/src/

## Summary
- Total areas:   22 modules + shared/ + core/
- Done:           3
- In progress:    1
- Pending:       20
- Blocked:        0

## Areas

### profile [done] (2026-05-02, 8m)
- Files walked: 28
- Findings closed: 22 / 22
- By class: reinvented-wrapper(9), silent-catch(4), design-token-drift(5), a11y-violation(2), i18n-key-drift(2)
- Commits: 22
- Diff: -64 lines

### notifications [done] (2026-05-02, 5m)
- ...

### orders [in-progress]
- Started: 2026-05-03 10:00
- Paused at: 15 of 28 files

### inventory [pending]
... (more)
```

### Daily workflow

```
Day 1:  /align                  # first pending module
Day 2:  /align                  # next pending
Day 3:  /align --status         # progress report
        /align                  # continue
...
```

Overrides:
```
/align the orders module        # specific area
/align --status                 # progress report only
/align --resume                 # pick up in-progress
/align --reset profile          # re-run from scratch
/align --refresh                # RE-SCAN codebase, MERGE into existing progress.md
                                #   - If progress.md missing: builds it from scratch (same as first run)
                                #   - If progress.md exists:
                                #     * new areas (modules added since last scan) → appended as `pending`
                                #     * missing areas (modules removed/renamed) → marked `archived` (kept for history)
                                #     * existing rows (done / in-progress / blocked / pending) → preserved untouched
                                #   - Updates Summary counts to reflect new totals
                                #   - NO fix work performed; safe to run anytime
/align --ignore-ledger          # TRULY FRESH SCAN — act as if no align was ever done
                                #   - Backs up ai/align/* (ledger, findings, scan-report, plan, progress) to *-<iso>.bak.md
                                #   - Re-discovers idiom inventory from source
                                #   - Re-runs all detectors against current state
                                #   - Re-creates the scan report + plan + ledger from scratch
                                #   - KEEPS ADR pre-check (intentional convention exemptions preserved)
                                #   - IMPLIES --re-audit semantics on every row
                                #   - Combinable with <scope>: /align the orders module --ignore-ledger
                                #   - Use when: idioms changed materially OR you suspect previous align was incomplete
/align --re-audit               # IGNORE cached verdicts; re-detect EVERY area
                                #   - Discards `verified` / `done` rows in ai/align/ledger.md
                                #   - Re-dispatches the per-finding loop on every row
                                #   - Rows that re-verify clean stay `verified`; rows with reappearing fingerprints flip to `halted` and re-fix in same run
                                #   - Use when: codebase changed since last sweep OR detector improvements OR you suspect drift
                                #   - Combinable with <scope>: /align the orders module --re-audit
/align --restart                # WIPE progress, start over from the beginning
                                #   - Backs up current progress to ai/align/progress-<iso>.bak.md
                                #   - Resets every area to pending
                                #   - Begins with the first pending area
                                #   - Does NOT revert any commits already made (use git for that)
                                #   - For "ignore ledger AND re-audit", combine: /align --restart --re-audit
```

## What you see (output)

```
Align complete

Scope:               the orders module
Findings closed:     22
  reinvented-wrapper:  9 (raw <Button> from primevue → AppButton)
  silent-catch:        4 (routed through handleApiError)
  design-token-drift:  5 (hardcoded #3b82f6 → $primary; spacing 12px → $space-md)
  a11y-violation:      2 (missing focus state, missing alt)
  i18n-key-drift:      2 (hardcoded "Save" / "Cancel" → t() calls)

Commits:             22 (one per finding)
Diff:                +14 / -78 = -64 lines
Tests:               124/124 passing
a11y score:          92 → 95
Bundle delta:        -0.3% (smaller)
Wall-clock:          8m 14s

Skipped (intentional V2 design — has accepted ADR): 3 findings

Not validated:       visual regression on non-target routes (no snapshot baseline) — review token changes visually
Risks:               none identified — all closures are convention-mechanical
Revert:              git revert <first-sha>..<last-sha>  (one commit per finding — revert individually if needed)

Next: /align the next module  OR  inspect commits via git log --oneline
```

## What you DON'T see

- "Phase 3 — auth domain UI/UX"
- "Halt: idiom missing for X"
- "Tier promotion required"
- "Ledger row F042 status: verified"
- "/align-gate 4 to advance"

All internal. Just results.

## Optional flags

- `--plan` — **handoff mode**: run the read-only phases, write the eight-header plan file to `.claude/plans/`, print the Plan ID, exit before any edit (see § Phase 3.5 — Handoff). Distinct from `--dry-run`, which previews to the terminal and writes no file at all.
- `--dry-run` — show what would be aligned, no edits.
- `--strict` — forwarded to **`validate-align-artifacts.sh`**: treat warnings as failures where applicable.
- `--quiet` — forwarded to **`validate-align-artifacts.sh`** (`--quiet`) when invoking the validator from hooks / CI.
- `--allow-dirty` — proceed with uncommitted changes.
- `--max-parallel=<N>` — cap concurrent dispatch (default: 5).
- `--focus=<list>` — narrow to specific drift classes (e.g., `--focus=design-token-drift,a11y-violation`).
- `--exclude=<scope>` — exclude areas.
- `--surface-blockers` — show halted findings explicitly.

## Pre-requisites

- `_extracted-idioms.md` OR `codebase-profile.md` populated (the convention oracle).
- Mechanical CI green.
- Working tree clean (or `--allow-dirty`).

## Final report contract

Every run that produces `ai/align/final-report.md` MUST end with an **`## Actionable next steps`** section per `~/.claude/templates/snippets/actionable-next-steps.md`. Every deferred / out-of-scope / `halted` row gets one paste-ready follow-up command — comment line (WHAT + WHY + scope) + exact command + sorted by leverage. Routes deferrals to receivers (`/refactor` for code-structure deferrals, `/polish` for visual deferrals, `/add-test` / `/add-adr` for follow-ups, `/align-recheck <area>` for re-detection). The validator's `check_actionable_next_steps` reports a failure when the section is missing OR when a deferral is described without a paste-ready command line — surfaced only when the agent runs `validate-align-artifacts.sh` (agent-side discipline; the run does not invoke it automatically).

## Hard rules (internal)

Applied silently per the discipline:
- **Honesty clause in the summary block is mandatory.** The three lines `Not validated:` / `Risks:` / `Revert:` appear before `Next:` in every run summary — name what did NOT run (or `none — <what fully ran>`), residual risks (or `none identified`), and the exact revert command for this run's commit range. Omitting the negative space is the Trusted Summary failure mode applied to the run report.
- **Validator run is agent-side discipline (not an automated gate).** After scan produces `ai/align/scan-report.md` AND after every per-finding fix lands, the agent SHOULD run `~/.claude/scripts/validate-align-artifacts.sh` and act on its result — the parallel execution engine does NOT invoke the validator, so nothing halts the run automatically. The validator's `check_scan_report_evidence` reports a failure when the scan-report doesn't show per-detector run evidence (≥1 of the 12 universal classes scanned with explicit module count) AND oracle citation; on a reported failure the agent should re-emit the scan with evidence before advancing. This catches the Trusted-Summary recurrence where align claims "12 detectors run" without evidence any actually executed — but only when the agent actually runs the script.
- **Final report MUST end with paste-ready next steps.** *(Checked by `validate-align-artifacts.sh § check_actionable_next_steps` — agent-side; surfaced only when the agent runs the validator.)* Per `actionable-next-steps.md` snippet contract; reports a failure when missing or when deferrals are described without commands.
- Convention is the truth — no questioning the project's idioms. *(AGENT-enforced.)*
- Closure verbs from the closed vocabulary; no new abstractions invented. *(SCRIPT-enforced — `check_closure_verb_in_vocab` / `check_no_new_symbols`.)*
- Net-lines ≤ 0 for structural alignments. *(SCRIPT-enforced — `check_net_lines_structural`.)*
- Behaviour preserved (no convention enforcement changes user-observable output, except where security gates are added). *(AGENT-enforced.)*
- Re-detect after each fix; gap-count parity. *(AGENT-enforced — re-detect-to-zero / fingerprint-still-present run the detectors live; the script cannot re-run detectors.)*
- One commit per finding. *(AGENT-enforced; SCRIPT side-effect — `check_scope_boundary` / `check_net_lines_structural` resolve per-row commits by the `align/<phase>/<id>:` message convention.)*
- (Frontend) a11y / bundle-size do not regress. *(AGENT-enforced — frontend-regression checks need runtime tooling, not deterministic in the validator.)*

> **Check-matrix enforcement split (don't be misled by "the validator covers it").** Not every check above is mechanical. **SCRIPT-enforced** (deterministic, in `validate-align-artifacts.sh`): evidence-resolves, no-handwaves, closure-verb-vocab, no-new-symbols, structural-net-lines, scope-boundary, security-tier-minimum, security-assertion, perf-baseline, idiom-citation, oracle-unmodified, scope-code-smells, scan-report-evidence, progress/ledger-reconciliation, actionable-next-steps. **AGENT-enforced only** (runtime tooling — a rule-only tool must run these by hand): re-detect-to-zero, fingerprint-still-present, test-coverage-nondecreasing, frontend-regression (a11y / visual / bundle). Rule-only adapters (Aider / Codex / Gemini) MUST NOT assume the script covers the agent-side checks.

User sees results, not the policing.

## Failure modes

- **No findings** → "Codebase already aligned to conventions; nothing to do."
- **Idiom missing** → halts the affected fix; surfaces "/setup-project --refine" to add the missing primitive; rest continue.
- **Behavior change risk** → that finding skips with note; rest continue.

## Related (advanced)

For phase-by-phase or class-specific control, existing detailed commands still exist:
- `/align-scan` — inventory only.
- `/align-fast <N>` — run one phase.
- `/align-recheck <scope>` — focused area.
- `/ui-sweep` — UI/UX specialist (deeper than this for visual / layout / design quality).
- `/design-review` — read-only design audit.

`/align` is the simple-surface entry point. Power users can drop down to detailed commands.
