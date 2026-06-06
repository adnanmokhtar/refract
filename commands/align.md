---
description: One command convention alignment. Deep multi-agent execution. Takes optional scope (whole project OR specific area). NO phases visible, NO terminology, NO mid-run questions. Internally runs scan + fix in parallel waves for drift, reinvented wrappers, silent catches, design-token drift, a11y, i18n, and other convention violations. Output is brief: findings closed, commits, diff stats, test status. The simple-surface alternative to /align-scan + /align-fast cycles for convention drift.
kind: command
pack: orchestration
---

# /align [<scope>]

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
- **Design-token drift** — hardcoded colors / spacing where tokens exist.
- **i18n key drift** — hardcoded user-visible strings.
- **a11y violations** — missing alt, focus states, contrast issues.
- **Allowlist violations** — state stores outside the project's allowed list; routes outside the configured router; etc.

This is **structure enforcement** — no creative work, no new abstractions, just "make the code follow the project's stated structure."

## When to use

- "Align the whole project to the design system." → `/align`
- "Align the orders module." → `/align the orders module`
- "Fix convention drift across auth pages." → `/align the auth pages`

## When NOT to use

- For visual / look enhancement → `/enhance-ui` or `/ui-sweep` (creative work).
- For V1→V2 port → `/migrate`.
- For performance / clean-code optimization → `/optimize`.
- For new features → `/add-feature`.

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
4. **Multi-agent parallel fix** — dispatch one agent per finding cluster. Closure verbs are mechanical — **only** from the closed **21-verb** set (5 structural + 16 functional) in [`templates/packs/align/rules/align-discipline.md`](../templates/packs/align/rules/align-discipline.md) § Closure-verb vocabulary / procedures (examples: `replace-with-shared`, `remove`, `dedupe`, `add-gate`, `escape`).
5. **Verify continuously** — lint + typecheck + scoped tests + (frontend) a11y check + bundle-size after each fix.
6. **Self-resolve common questions** — convention is the truth. Project's idiom inventory (`_extracted-idioms.md` / `codebase-profile.md`) is the oracle. No "is this the right pattern" prompts.
7. **Halt only on genuine blockers**:
   - Idiom missing for a fix (project has no shared button when fix needs one — surfaces "/setup-project --refine to add primitive first").
   - Visual regression baseline drift > threshold (frontend; surfaces "review snapshots").
   - Behavior change risk (re-classify as refactor; user decides).

## Progress tracking (multi-day workflow)

Single source of truth: **`ai/align/progress.md`**.

### How it works

- **First run** → builds module inventory + writes progress file (all `pending`). Runs first module.
- **Subsequent runs** → reads progress file, picks next `pending` module (or use `<scope>` arg). Already-`done` modules skipped automatically.
- **`/align --status`** → read-only progress report; no work done.

### Progress file shape

```markdown
# Align progress

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

Every run that produces `ai/align/final-report.md` MUST end with an **`## Actionable next steps`** section per `~/.claude/templates/snippets/actionable-next-steps.md`. Every deferred / out-of-scope / `halted` row gets one paste-ready follow-up command — comment line (WHAT + WHY + scope) + exact command + sorted by leverage. Routes deferrals to receivers (`/refactor` for code-structure deferrals, `/polish` for visual deferrals, `/add-test` / `/add-adr` for follow-ups, `/align-recheck <area>` for re-detection). The validator's `check_actionable_next_steps` halts when the section is missing OR when a deferral is described without a paste-ready command line.

## Hard rules (internal)

Applied silently per the discipline:
- **Validator gate is mandatory.** After scan produces `ai/align/scan-report.md` AND after every per-finding fix lands, the agent MUST run `~/.claude/scripts/validate-align-artifacts.sh`. The validator's `check_scan_report_evidence` halts the run if the scan-report doesn't show per-detector run evidence (≥1 of the 12 universal classes scanned with explicit module count) AND oracle citation. A failed validator forces the scan to be re-emitted with evidence. This catches the Trusted-Summary recurrence where align claims "12 detectors run" without evidence any actually executed.
- **Final report MUST end with paste-ready next steps.** *(Mechanical — `validate-align-artifacts.sh § check_actionable_next_steps`.)* Per `actionable-next-steps.md` snippet contract; halts the gate when missing or when deferrals are described without commands.
- Convention is the truth — no questioning the project's idioms.
- Closure verbs from the closed vocabulary; no new abstractions invented.
- Net-lines ≤ 0 for structural alignments.
- Behaviour preserved (no convention enforcement changes user-observable output, except where security gates are added).
- Re-detect after each fix; gap-count parity.
- One commit per finding.
- (Frontend) a11y / bundle-size do not regress.

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
