---
description: Enforce conventions the project ALREADY has, project-wide or across several areas. Triggers — 'align the app to the design system', 'convention drift across the auth pages', 'some files do X, some do Y', 'stop reinventing the shared wrapper', and the same asks carrying a surface noun ('our buttons ignore the spacing tokens on the auth pages'). The test is the REMEDY, never which nouns appear — trigger when the fix is to apply something the project ALREADY documents — a token, an a11y rule, a naming rule, a layer boundary, an already-named shared helper — in place, leaving the wrapper as it is. Do NOT trigger when every instance of ONE surface type (tables / forms / headers / tabs / filters / buttons / validation) must instead end up behind ONE canonical shared implementation, including in some-files-do-X form ('some pages use the shared PageHeader and some roll their own'); the closed 21-verb set cannot reconcile a rolled-own instance INTO a canonical shape — that is /unify-surfaces. Do NOT trigger on API envelope, error-contract, endpoint-naming or pagination uniformity, nor to INTRODUCE finish that does not exist yet (a new token, a missing state, creative visual work) — that is /polish. Not perf or architecture (/optimize), not one narrow area (/align-recheck).
compatibility: Requires the align pack (opt-in; /setup-project --include=align) and a declared convention to enforce — a lint rule at error, a human-written line in ai/conventions.md, an ADR, a glossary, a token set or a named wrapper. Mechanical CI green and a clean tree, or --allow-dirty. Any stack. validate-align-artifacts.sh and align-sweep-gate.py are agent-invoked, not run automatically.
kind: command
pack: orchestration
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /align [<scope>]

> **Coverage ledger (mandatory)** — before printing any verdict, emit the ledger over the population this run resolved: see [`templates/snippets/coverage-ledger.md`](../templates/snippets/coverage-ledger.md). `no findings` and `did not look` print identically in a report that lists only findings, and the reader cannot tell them apart. Every unit lands in **Reviewed / N/A (with a reason) / Live, unreviewed / Blocked**, and the four counts are printed summing to the population.

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../templates/snippets/plan-flag.md). `/align <scope> --plan` runs the convention scan, writes the eight-header handoff plan, and exits before any edit — executable later via `/execute-plan <file>`. The write-and-stop behaviour is specified in § Phase 3.5 — Handoff.
>
> **Note — two distinct "plan" artifacts.** `--plan` writes a one-off **handoff doc** to `.claude/plans/align-<short-slug>-<YYYYMMDD-HHmm>.md` (the universal plan-flag location and naming, for review / `/execute-plan`). This is NOT the pack's executable `ai/align/plan.md` (the phased plan produced by `/align-plan` that `/align-fast <N>` consumes). The handoff doc carries the eight canonical headers and is a snapshot for an executor; `ai/align/plan.md` is the live, ledger-coupled plan and `/execute-plan` cannot read it.

## Requires the align pack

`/align` is the simple surface over the **align pack**, which is opt-in. Before anything else, check that `.claude/skills/align-detect/SKILL.md` and `.claude/skills/find-and-align/SKILL.md` exist. If either is missing, print exactly:

```
align pack not installed — /setup-project --include=align
```

and stop. Never fall back to a prose sweep: without the pack's detectors, oracle map and proof ladder there is no evidence that a row is a declared convention or that a fix changed nothing else.

## What this does

**Single command: audit the project's declared conventions, then close what the audit found.** Whole project or scoped.

1. **The audit** — `/align-scan` (the read-only audit) over the scope, unless `--from-audit <report>` hands it one already. It builds the oracle map (`convention-oracle` § 0: lint rules at `error`, human-written lines, ADRs, the glossary, tokens, named wrappers; generated lines are proposals), dispatches `align-detect` (the four align detectors `convention-oracle`, `wrapper-adoption-scan`, `naming-layout-scan`, `convention-ratchet-scan`, plus every installed owner detector), refutes each candidate, and writes `ai/audits/<date>-align.md` with a `## What to do next`.
2. **The fix** — `find-and-align` per row, in the report's order (MUST → SHOULD → OPTIONAL). Each row goes through the proof ladder before anything else reads the diff (`align-sweep-gate.py`, L0–L13), one commit per row.

What align closes — **a declared convention not followed at a live site**:
- **Wrappers and imports** — a raw primitive where a declared wrapper exists (AL-11), a copy of a named helper (AL-13), a deep import past a package's public entry (AL-14), a wrapper missing a required prop or permission gate (AL-15), a forbidden library (AL-22).
- **Names and layout** — file and directory names (AL-16), identifiers (AL-17), glossary synonyms in internal names (AL-18), placement and module skeleton (AL-19).
- **Suppressions and ratchets** — a reasonless suppression of a convention rule (AL-29), a baseline that grew (AL-30), a package that dropped the shared config (AL-31), a declared same-version migration left half done (AL-32).
- **Owner classes, EQ rows only** — a literal equal to an existing token in every theme (AL-05, ui-ux detects it), a literal equal to an existing catalog value (AL-26, frontend detects it), a layer re-route through a public surface the oracle names (AL-20/21, code-quality detects it), a dropped a11y prop the wrapper already has (AL-28).

What align routes, with the audit id, and never closes: security (`/security-fix`), performance and data (`/perf-fix`, `/db-fix` when installed), error handling, dead code, diverged copies, SOLID and complexity (`/quality-fix`), new copy and catalog defects (`/frontend-fix`), a declared API contract (`/backend-fix`), API uniformity with no declared contract and any token or state that does not exist yet (`/polish`), a wrapper gap (`/unify-surfaces`), layer rework (`/optimize`), a wire-name rename (`/refactor` + ADR). A split nobody declared (AL-02) is reported for a human to ratify, never fixed.

## When to use

- "Align the whole project to the design system." → `/align`
- "Align the orders module." → `/align the orders module`
- "Fix convention drift across auth pages." → `/align the auth pages`
- "Close what the align audit found." → `/align --from-audit ai/audits/<date>-align.md`

## When NOT to use

- For visual / look enhancement → `/enhance-ui` or `/ui-sweep` (creative work).
- For V1→V2 port → `/migrate`.
- For performance, clean-code, SOLID or architecture work → `/optimize`, which *discovers* the smell and may design a new shape for it. Align applies only what the oracle already names; see the shared finding-class rows in [`templates/tool-adapters/_orchestration-sync.md`](../templates/tool-adapters/_orchestration-sync.md).
- For new features → `/add-feature`.
- **For introducing NEW finish → `/polish`.** This is the canonical split: **`/align` enforces EXISTING tokens / a11y / conventions**; **`/polish` introduces NEW finish** (new tokens, new states, new visual polish). If a fix would *add* a design token that doesn't exist yet, *introduce* a missing-state pattern, or do creative visual work, it is a `/polish` job. See the boundary table in [`templates/tool-adapters/_orchestration-sync.md`](../templates/tool-adapters/_orchestration-sync.md).

## Args

- `<scope>` (optional) — natural-language description OR explicit path. If omitted: whole project.
- `--from-audit <report>` — close the `## What to do next` list of an existing `/align-scan` report (`ai/audits/<date>-align.md`) instead of auditing first. The report's rows are re-verified, never trusted.

Examples:
```
/align                                  # whole project: audit, then fix
/align the orders module                # one module
/align <modules-root>/auth/             # explicit path
/align --from-audit ai/audits/2026-10-18-align.md
```

## What happens internally (silent)

**Discipline:** MUST read [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) before generating code fixes.

1. **Audit or read the audit.** Without `--from-audit`, run `/align-scan` over the resolved scope; it writes the report and the ledger rows. With it, read the named report. Either way, the input is the report's `## What to do next`; nothing is fixed that is not on it.
2. **Resolve scope** — semantic resolution of the description to paths.
3. **Order** — MUST FIX → SHOULD FIX → OPTIONAL; within a tier, the widest V393 group first (one decision per group: `#d92d20 → --color-danger` everywhere).
4. **Fix in parallel, one sub-agent per row (`Task`)**, each running `find-and-align` on its row: ROUTE (owner rows move to `routed`, no commit) → DETECT (re-run the row's `detector_cmd`; L0 oracle quote) → DECIDE (the proof class) → FIX (rule first where expressible; only the matched expression; tests read-only) → VERIFY (the ladder) → RECORD. Rows whose `scope` overlaps run serially. Closure verbs come **only** from the closed **21-verb** set in [`templates/packs/align/rules/align-discipline.md`](../templates/packs/align/rules/align-discipline.md); align uses the structural five and `rename`, `add-gate` (with the declared gate), `extract-to-shared` and `inline-magic-to-named-const` into idioms the oracle names. The security, perf and validation verbs stay in the set for the owners' carve-outs only.
5. **Proof by class** (`find-and-align` Step 3):
   - **EQ** (exact equivalence: the token round-trips in every theme within one property family with one candidate; the wrapper's defaults reproduce the props; the literal equals a catalog value) — proven by a **zero** computed-style or compiled-CSS diff (V394/V396), or `[report-with-fix] (static EQ)` with the runtime probe written out when no harness exists.
   - **VC** (a visible change: a snap to the nearest token, a wrapper with different defaults) — proven only by a visual diff at `maxDiffPixels: 0` **and** `approval: <name>@<iso>` written by a human. The row stops at `pending-approval` until then. **A visual diff is never auto-accepted** — not for a token swap, not with an allowance configured.
   - **FN** (a functional verb adding a declared idiom, `add-gate` with the declared `<Can>`) — proven by a behaviour test as the role that must not see it (V401).
6. **Sweep gates over the run** — `align-sweep-gate.py ladder` per row and across the run: every removed line is an evidence line or verb footprint (AL-34), one before-value maps to one after-value (AL-33), every emitted token, import and export exists (V398), tests and snapshots untouched (V408), baselines only shrink (V395).
7. **Boot-check (final)** — dispatch the `smoke-verify` skill (code-quality pack) after the last commit. A green scoped suite does not prove the app still starts: `replace-with-shared` re-points an import, `dedupe` deletes the copy a module was resolving, `remove` can take an export something registers by side effect. Skippable with `--no-boot-check` for pure libraries. **Recorded as `boot-check: pass` or `boot-check: skipped(<reason>)`**, and a skip also goes under `Not validated:`.
8. **Self-resolve common questions** — the oracle is the truth; a T2g (generated) line is not, and its rows wait at `pending-ratification` for one human confirmation per rule.
9. **Halt only on genuine blockers**:
   - An idiom the fix needs that no oracle names → that row halts; "/setup-project --refine to add the primitive first".
   - A wrapper gap (the raw call does something the wrapper does not expose) → that row routes to `/unify-surfaces`.
   - A VC row with no approval → `pending-approval`; the rest continue.
   - Behaviour change risk → re-classify as `/refactor`; the user decides.

## Phase 3.5 — Handoff (`--plan` only)

`--plan` is **not** a louder `--dry-run`. It runs steps 1–3 (scan → resolve scope → plan internally) above, makes **no edit**, and writes a plan file that `/execute-plan` — or any other tool, or a human — can implement later.

1. **Read-only phases only.** No fix agent is dispatched, no commit is made, `ai/align/ledger.md` is not advanced and `ai/align/progress.md` is not re-projected.
2. **Expand the internal plan into the canonical handoff format.** All **eight** headers are mandatory — `## Goal` / `## Context` / `## Inputs` / `## Outputs` / `## Constraints` / `## Steps` / `## Verification` / `## Status` — plus the `Plan ID`. `/execute-plan` halts on a file missing any one of them ([`templates/repo-baseline/.claude/commands/execute-plan.md`](../templates/repo-baseline/.claude/commands/execute-plan.md) § Mechanical halt), so an eight-header file is the contract, not a nicety. `## Approach` and `## Known unknowns` are accepted optional extras.
3. **Map this command's own vocabulary onto those headers.** Each finding row becomes one `## Steps` entry with its AL id, closure verb and proof class; the files it touches become `## Outputs`; "closure verbs only from the closed 21-verb set", "tests read-only" and "VC rows need a human approval" become `## Constraints`; the ladder (`align-sweep-gate.py ladder`) plus the project's lint / typecheck / scoped-test commands become `## Verification`; the oracle lines the rows cite become `## Inputs`.
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
- By class: AL-11(9), AL-05(5), AL-28(2), AL-26(2); routed: 4
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
Audit:               ai/audits/2026-10-18-align.md (verdict before: ALIGNED-UNVERIFIED (3))
Rows closed:         18
  AL-11 raw primitive:   9  EQ  (raw <Button> from the UI library → AppButton; defaults reproduce the props)
  AL-05 token = value:   5  EQ  (#d92d20 → var(--color-danger); zero computed-style diff, light + dark)
  AL-26 copy = key:      2  EQ  ("Save" → t('common.save'); key present in en, ar)
  AL-15 gate:            2  FN  (delete action wrapped in <Can action="orders.delete">; render test as viewer)
Pending approval:    1  VC  (AL-06 padding 13px → --space-3: visual diff in ai/align/runs/…/A031, needs approval)
Pending ratification:1  (ai/conventions.md:41 "Store files end in .store.ts" is generated — confirm it)
Routed:              4  (2 → /quality-fix silent catch · 1 → /frontend-fix new copy · 1 → /unify-surfaces wrapper gap)

Commits:             18 (one per row)
Sweep gates:         scope PASS · consistency PASS (7 keys, 1 after each) · names PASS · lock PASS · ratchet PASS
Tests:               124/124 passing (count 124 → 124)
boot-check:          pass

Not validated:       computed-style diff on /orders/print (no route fixture) — static EQ only for A044
Risks:               none identified — every closed row is EQ or FN with its proof
Revert:              git revert <first-sha>..<last-sha>  (one commit per row — revert individually if needed)

Next: approve A031 or send it to /polish · confirm ai/conventions.md:41 · /align-scan to confirm the verdict · /learn-from-task
```

## What you DON'T see

- "Phase 3 — auth domain UI/UX"
- "L4 scope PASS (3 removed lines = evidence)"
- "Tier promotion required"
- "Ledger row F042 status: verified"
- "/align-gate 4 to advance"

All internal. Just results.

## Optional flags

- `--plan` — **handoff mode**: run the read-only phases, write the eight-header plan file to `.claude/plans/`, print the Plan ID, exit before any edit (see § Phase 3.5 — Handoff). Distinct from `--dry-run`, which previews to the terminal and writes no file at all.
- `--from-audit <report>` — close an existing audit's `## What to do next` (see § Args).
- `--dry-run` — run the audit and DECIDE only; print each row's proof class and closer, no edits.
- `--strict` — forwarded to **`validate-align-artifacts.sh`**: treat warnings as failures where applicable.
- `--quiet` — forwarded to **`validate-align-artifacts.sh`** (`--quiet`) when invoking the validator from hooks / CI.
- `--allow-dirty` — proceed with uncommitted changes.
- `--max-parallel=<N>` — cap concurrent dispatch (default: 5).
- `--focus=<list>` — narrow to AL classes (e.g., `--focus=AL-05,AL-11`); legacy names are mapped (`align-detect` § The legacy class map).
- `--exclude=<scope>` — exclude areas.
- `--surface-blockers` — show halted findings explicitly.

## Pre-requisites

- The align pack installed (§ Requires the align pack).
- At least one declared convention: a lint rule at `error`, a human-written line in `ai/conventions.md`, an ADR, a glossary or a named wrapper. With none, the audit prints every align class `N/A (no declared convention)` and there is nothing to fix.
- Mechanical CI green.
- Working tree clean (or `--allow-dirty`, which never commits a dirty file outside a row's scope).

## Final report contract

Every run that produces `ai/align/final-report.md` MUST end with an **`## Actionable next steps`** section per `~/.claude/templates/snippets/actionable-next-steps.md`. Every deferred / out-of-scope / `halted` row gets one paste-ready follow-up command — comment line (WHAT + WHY + scope) + exact command + sorted by leverage. Routes deferrals to receivers (`/refactor` for code-structure deferrals, `/polish` for visual deferrals, `/add-test` / `/add-adr` for follow-ups, `/align-recheck <area>` for re-detection). The validator's `check_actionable_next_steps` reports a failure when the section is missing OR when a deferral is described without a paste-ready command line — surfaced only when the agent runs `validate-align-artifacts.sh` (agent-side discipline; the run does not invoke it automatically).

## Hard rules (internal)

Applied silently per the discipline:
- **Honesty clause in the summary block is mandatory.** The three lines `Not validated:` / `Risks:` / `Revert:` appear before `Next:` in every run summary — name what did NOT run (or `none — <what fully ran>`), residual risks (or `none identified`), and the exact revert command for this run's commit range. Omitting the negative space is the Trusted Summary failure mode applied to the run report.
- **Validator run is agent-side discipline (not an automated gate).** After scan produces `ai/align/scan-report.md` AND after every per-finding fix lands, the agent SHOULD run `~/.claude/scripts/validate-align-artifacts.sh` and act on its result — the parallel execution engine does NOT invoke the validator, so nothing halts the run automatically. The validator's `check_scan_report_evidence` reports a failure when the scan-report lacks a status line for any of AL-01…AL-34 (`checked` / `N/A` / `blocked` / `NOT RUN` / `Live` / `routed`) or the oracle line; on a reported failure the agent re-emits the audit before advancing. This catches the Trusted-Summary recurrence where a scan claims coverage without evidence — but only when the agent actually runs the script.
- **Final report MUST end with paste-ready next steps.** *(Checked by `validate-align-artifacts.sh § check_actionable_next_steps` — agent-side; surfaced only when the agent runs the validator.)* Per `actionable-next-steps.md` snippet contract; reports a failure when missing or when deferrals are described without commands.
- Convention is the truth — no questioning the project's idioms. *(AGENT-enforced.)*
- Refute before fixing; the posting bar before reporting. *(AGENT-enforced — `refute-before-report.md`, `posting-bar.md`.)* The detector that flagged a drift row never clears it.
- Closure verbs from the closed vocabulary; no new abstractions invented. *(SCRIPT-enforced — `check_closure_verb_in_vocab` / `check_no_new_symbols`.)*
- Net-lines ≤ 0 for structural alignments. *(SCRIPT-enforced — `check_net_lines_structural`.)*
- Every row cites an oracle that resolves, carries a proof class, and a VC row carries a human approval. *(SCRIPT-enforced — `check_oracle_cited`, `check_proof_class`, `check_vc_approval`.)*
- Behaviour preserved: an EQ row changes nothing a user sees (zero diff); a VC row changes it only with an approval; an FN row adds only the declared idiom. *(AGENT-enforced — the ladder's L10a / L10b.)*
- Re-detect after each fix; gap-count parity; changed lines ⊆ hit lines; one way per pattern. *(SCRIPT-enforced by `align-sweep-gate.py` — `redetect`, `scope`, `consistency`; run per row by `find-and-align`.)*
- One commit per finding. *(AGENT-enforced; SCRIPT side-effect — `check_scope_boundary` / `check_net_lines_structural` resolve per-row commits by the `align/<phase>/<id>:` message convention.)*
- (Frontend) a11y / bundle-size do not regress. *(AGENT-enforced — frontend-regression checks need runtime tooling, not deterministic in the validator.)*

> **Check-matrix enforcement split (don't be misled by "the validator covers it").** Not every check above is mechanical. **SCRIPT-enforced** (deterministic, in `validate-align-artifacts.sh`): evidence-resolves, no-handwaves, closure-verb-vocab, no-new-symbols, structural-net-lines, scope-boundary (every row commit), oracle-cited, proof-class, vc-approval, idiom-citation, oracle-unmodified, scope-code-smells, scan-report-evidence (all 34 AL rows), progress/ledger-reconciliation, actionable-next-steps; and in `align-sweep-gate.py`: re-detect-to-zero, line-level scope, one-way-per-pattern, emitted names, value round-trip, test lock, ratchet, non-vacuous. **AGENT-enforced only** (runtime tooling — a rule-only tool must run these by hand): the computed-style or visual diff (L10a / L10b), test-coverage-nondecreasing, the boot-check. Rule-only adapters (Aider / Codex / Gemini) MUST NOT assume the script covers the agent-side checks.

User sees results, not the policing.

## Failure modes

- **Align pack not installed** → one line, `align pack not installed — /setup-project --include=align`, and stop.
- **No findings** → the audit's verdict line (ALIGNED, or ALIGNED-UNVERIFIED with what was not looked at); nothing to fix.
- **Idiom missing** → halts the affected row; surfaces "/setup-project --refine" to add the missing primitive; rest continue.
- **A VC row without approval** → `pending-approval`, with the diff images; rest continue.
- **A sweep gate FAIL** (two tokens for one hex, an out-of-scope hunk, a snapshot edit) → the row reverts and halts with the ladder line; rest continue.
- **Behavior change risk** → that row skips with a note; rest continue.

## Related (advanced)

For phase-by-phase or class-specific control, existing detailed commands still exist:
- `/align-scan` — the read-only audit this command runs first.
- `/align-fast <N>` — run one phase.
- `/align-recheck <scope>` — focused area.
- `/ui-sweep` — UI/UX specialist (deeper than this for visual / layout / design quality).
- `/design-review` — read-only design audit.

`/align` is the simple-surface entry point. Power users can drop down to detailed commands.
