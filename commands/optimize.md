---
description: One command code optimization, stack-agnostic (frontend / backend / data / mobile), deep multi-agent. Architectural diagnosis FIRST (layer violations, god modules, missing abstractions, wrong-level responsibilities, cyclic dependencies, cross-cutting duplication), then tactical sweep (clean code, refactoring, SOLID, performance, dead code, dedup, over-abstraction) in parallel waves. Architectural fixes cascade — fixing the right layer dissolves dozens of tactical findings. Optional scope arg. Brief output.
kind: command
pack: orchestration
---

# /optimize [<scope>]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../templates/snippets/plan-flag.md). `/optimize <scope> --plan` runs the architectural diagnosis + tactical scan, writes the ranked fix-plan, and exits before any edit.

## What this does

**Single command. Make the codebase high-quality at the architectural AND tactical level.** Deep multi-agent diagnosis + foundation-first fixes + parallel tactical sweep. Whole project or scoped. **Stack-agnostic** — works on frontend (Vue / React / Svelte / Angular), backend (Node / Python / Go / Java / Ruby / .NET), data (SQL / migrations / pipelines), and mobile (iOS / Android / RN).

The agent:

1. **Diagnoses the bigger picture FIRST** — reads the codebase as a whole, builds dependency + responsibility maps, surfaces architectural smells. Decides which fixes are foundation-level (cascade impact across many findings) vs cosmetic.

   **Architectural detectors**:
   - **Layer violation** — UI doing DB queries; services importing UI primitives; core/ importing presentation; controllers doing business logic that belongs in services.
   - **Cyclic dependency** — module A → B → A loops.
   - **Bottleneck module** — every request flows through one module (single-point-of-N+1).
   - **God module** — ≥30 outward imports OR ≥500 LOC with mixed responsibilities.
   - **Anemic module** — only data, no behaviour (suggests merging into consumer or adding behaviour).
   - **Wrong-level responsibility** — fetching / validation / error handling / transformation at the wrong tier (e.g., component doing the work of a service).
   - **Cross-cutting duplication** — auth / logging / error handling / metrics / retries duplicated across modules instead of centralised.
   - **Missing abstraction** — ≥3 sites duplicating the same shape (begs for a shared primitive).

2. **Applies architectural foundations FIRST** — moves responsibility to the right layer, introduces shared abstractions, fixes layering, centralises cross-cutting concerns, splits god modules, decouples cycles. These are larger commits with bigger leverage.

3. **Re-detects tactical findings** — many findings dissolve automatically after architectural fixes (e.g., 47 N+1 queries become 22 after fetching moves to service layer; 5 dedup sites disappear once a shared primitive is introduced; 14 ad-hoc try/catch patches disappear once error middleware is centralised).

4. **Applies remaining tactical findings in parallel** for these classes:
   - **Clean code** — long functions, deep nesting, magic numbers, bad naming, redundant comments, comment-as-rename.
   - **Refactoring** — method extraction (≥30 lines OR cyclomatic ≥10 OR mixed responsibilities), conditional flattening (nesting ≥3 → guard clauses or polymorphism), parameter object (≥5 args, or 3+ args always travelling together), magic→constant, move-to-right-module, decompose long file (≥500 lines, mixed responsibilities), replace temp with query, replace loop with pipeline (manual `for` → `map`/`filter`/`reduce`), rename for clarity (single-letter / `data` / `tmp` / `info`), encapsulate exposed state.
   - **Clean architecture** — leftover layer violations, leaking abstractions, module/layer boundaries.
   - **SOLID** — dispatch via [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) (linked packs hold SRP/OCP/LSP/ISP/DIP closure vocabulary — do not restate glossaries here).
   - **Performance** — N+1 queries, sequential awaits where parallelism is safe, sync HTTP in hot paths, missing cache at known-cacheable sites, missing index where query shape demands one, `SELECT *` consumed by < 5 fields, in-app filtering pushable to database.
   - **Render / rebuild waste** (`frontend-*` / `mobile-*` only) — oversized state scope (state at screen/page root re-rendering the whole subtree), side-effects in the build/render body, missing const / memo / stable subtree, per-item allocations in list hot paths (inline closures / style literals), unvirtualized lists, animation invalidating the whole tree, store over-invalidation (whole-store subscription where a selector exists). Fingerprints per `PROJECT_KIND`: `mobile-*` → `mobile/rules/render-discipline.md` (Flutter / RN / Compose / SwiftUI tables + the 8 detectors); `frontend-*` → frontend pack equivalents. Closure verbs: `scope-state-down`, `move-to-lifecycle`, `extract-const-subtree`, `memoize`, `virtualize-list`, `scope-animation`, `select-store-slice`; logic-in-view findings route to `/align` (layer violation, not memoization). Every fix ships with a before/after rebuild-count or frame-time measurement — no speculative memoization (blanket memo on cold paths is itself an over-abstraction finding).
   - **Dead code** — unused exports, unreachable branches, dead variables.
   - **Duplicated logic** — same code in N files (dedupes to introduced or existing shared helpers).
   - **Over-abstraction** — wrapper with one consumer (inline), useless `options: {foo?:bool}` where every caller passes the same value.

5. **Behaviour-preserving** for architectural moves and tactical structural fixes (clean code, refactoring, dead code, dedup, over-abstraction). Tests must stay green; observable behaviour unchanged.

6. **Behaviour-changing where safe** for perf fixes (parallelize, batch, cache) — adds assertions in same commit.

Output: architectural fixes FIRST, then tactical findings, commits, diff stats, test status, perf wins (measured).

## When to use

- "Optimize the whole project." → `/optimize`
- "Optimize the orders module." → `/optimize the orders module`
- "Speed up the dashboard." → `/optimize the dashboard, focus on performance`
- "Clean up the auth flow." → `/optimize the auth flow`

## When NOT to use

- For UI/UX visual / design work → `/enhance-ui` or `/ui-sweep`.
- For V1→V2 port → `/migrate`.
- For convention drift specifically (without perf) → `/align`.
- For new features / bug fixes → `/add-feature` / `/fix-bug`.

## Args

- `<scope>` (optional) — natural-language description OR explicit path. If omitted: whole project.

Examples:
```
/optimize                                          # whole project
/optimize the orders module                        # one module
/optimize the dashboard, focus on performance      # scoped + intent hint
/optimize <modules-root>/orders/                   # explicit path
/optimize "everything except tests and migrations" # exclusion-by-description
```

## What happens internally (silent)

**Discipline:** MUST read [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) before generating code fixes (SOLID + clean-code single source of truth).

1. **Phase 0 — Architectural diagnosis** (the bigger picture, dispatched via `architectural-diagnosis` skill in code-quality pack). Builds project-wide maps:
   - Dependency graph (modules → modules; flags cycles, bottlenecks).
   - Responsibility map (what each module owns; flags god modules, anemic modules).
   - Layer audit (which module imports across layers; flags layer violations).
   - Cross-cutting scan (auth / logging / error / metrics — centralised or duplicated?).
   - Repetition analysis (≥3 sites of same shape → missing-abstraction candidate).
   Emits internal `ai/optimize/_architecture-decisions.md` listing foundation-level fixes (cascade impact) vs cosmetic (would be tactical anyway). NOT shown to user.

1.5. **Phase 0.5 — test-shield (coverage gate)** (dispatched via `test-shield` skill in code-quality pack). Before any behaviour-preserving fix touches a branch, measure coverage of the in-scope set; for each touched-but-uncovered branch, pin current behaviour with a characterization test (`/add-test`) BEFORE the fix, or mark the finding `blocked`. "Tests stay green" is only proof of preservation when a test exercises the touched branch. This baseline is what step 7's "coverage must not drop" compares against.

2. **Phase 1 — Apply foundations FIRST** (architectural closure verbs):
   `move-responsibility`, `introduce-abstraction`, `fix-layering`, `centralize-cross-cutting`, `split-god-module`, `decouple-cycle`, `merge-anemic-module`. Each foundation fix gets one commit. Re-runs typecheck + scoped tests after each.

3. **Phase 2 — Tactical scan** (after foundations land). Dispatches `detect-drift` skill (from align pack) with `--include-classes=dead-code,duplicated-logic,over-abstraction,performance,refactoring,clean-code,solid-violation` and re-runs against the now-restructured tree. Many earlier findings dissolve automatically.

4. **Resolve scope** — semantic resolution of description to source paths.

5. **Plan internally** — group remaining tactical findings by class + dependency. Foundation patterns within tactical (e.g., introduce shared helper before deduping consumers). NO phase output to user.

6. **Multi-agent parallel fix** — dispatch one agent per finding cluster. Each agent: re-detect → apply fix → verify → commit. Closure verbs:
   - **Refactoring** (via `refactoring-sweep` skill): `extract-method`, `extract-class`, `extract-param-object`, `flatten-conditional`, `move-to-module`, `replace-magic-with-constant`, `replace-temp-with-query`, `replace-loop-with-pipeline`, `rename`, `encapsulate`.
   - **Tactical**: `remove`, `inline`, `dedupe`, `replace-with-shared`.
   - **Performance** — for data-layer and runtime hotspots, dispatch the specialist that owns the detector and APPLY its proposal in-band rather than reimplementing inline: `performance-optimizer` (hot-path CPU / allocation / async), `query-optimizer` + `database-optimizer` (index / query-plan / N+1). These DB agents are **propose-only**; `/optimize` is the applier — it takes their index/migration proposal, runs the before/after query-plan, applies, and commits. Closure verbs: `parallelize`, `batch`, `cache-with-explicit-ttl`, `add-index`, `project-columns`, `push-down-filter`.
   - **Render waste** (`frontend-*` / `mobile-*`): `scope-state-down`, `move-to-lifecycle`, `extract-const-subtree`, `memoize`, `virtualize-list`, `scope-animation`, `select-store-slice` (per `mobile/rules/render-discipline.md` § The 8 detectors; measured rebuild-count / frame-time delta required).

7. **Verify continuously** — lint + typecheck + scoped tests after each fix. Coverage must not drop. Behaviour-preserving for all structural fixes (architectural moves, refactoring, dead code, dedup, over-abstraction); perf fixes ship with assertions + before/after measurement.

8. **Self-resolve common questions** — closure verbs are mechanical. Agent doesn't ask permission per fix.

9. **Halt only on genuine blockers**:
   - Architectural move would change observable behaviour where it must be preserved (re-classify as refactor; user decides).
   - Idiom missing for a functional fix (e.g., user wants caching but project has no cache primitive — surfaces "add primitive first via /setup-project --refine").
   - Security-sensitive change beyond mechanical fix.
   - Cyclic dependency that requires multi-PR decoupling (surfaces a small plan).
   - Otherwise: just optimize.

10. **Skip findings that aren't load-bearing** — clean-code findings in test fixtures / one-time scripts skip; only ship-path code gets optimized.

11. **Boot-check (final)** — dispatch the `smoke-verify` skill (code-quality pack) after the last commit. A green suite doesn't prove the app starts; smoke-verify boots it per `PROJECT_KIND` (dev server / server + health probe / CLI / library import) and HALTS if it doesn't come up — catching DI / route-registration / import-cycle breaks no unit test covers. Skippable with `--no-boot-check` for pure libraries.

## Progress tracking (multi-day workflow)

Single source of truth: **`ai/optimize/progress.md`**.

### How it works

- **First run** → builds module inventory + writes progress file (all `pending`). Runs first module.
- **Subsequent runs** → reads progress file, picks next `pending` module (or use `<scope>` to override). Already-`done` modules skipped.
- **`/optimize --status`** → read-only progress; no work.

### Progress file shape

```markdown
# Optimize progress

Started: 2026-05-02
Codebase: <project-root>/src/

## Summary
- Total areas:   22 modules + shared/ + core/
- Done:           4
- In progress:    1
- Pending:       19
- Blocked:        0

## Areas

### profile [done] (2026-05-02, 12m)
- Files walked: 28
- Findings closed: 24 / 27
- Halts: 3 (idiom missing — needs /setup-project --refine)
- Commits: 24
- Diff: -344 lines
- Perf wins: listProfile() 200ms → 35ms p95

### notifications [done] (2026-05-02, 8m)
- Files walked: 14
- Findings closed: 18 / 18
- Commits: 18
- Diff: -127 lines

### orders [in-progress]
- Started: 2026-05-03 09:00
- Paused at: 18 of 32 files
- Reason: time-boxed

### inventory [pending]
### page-builder [pending]
... (19 more)
```

### Daily workflow

```
Day 1:  /optimize               # first run — picks first module
Day 2:  /optimize               # next pending module
Day 3:  /optimize --status      # check overall progress
        /optimize               # continue
...
```

Overrides:
```
/optimize the orders module     # specific area, skips ahead
/optimize --status              # progress report only
/optimize --resume              # pick up in-progress module
/optimize --reset profile       # re-run profile from scratch
/optimize --refresh             # RE-SCAN codebase, MERGE into existing progress.md
                                #   - If progress.md missing: builds it from scratch (same as first run)
                                #   - If progress.md exists:
                                #     * new areas (modules added since last scan) → appended as `pending`
                                #     * missing areas (modules removed/renamed) → marked `archived` (kept for history)
                                #     * existing rows (done / in-progress / blocked / pending) → preserved untouched
                                #   - Updates Summary counts to reflect new totals
                                #   - NO fix work performed; safe to run anytime
/optimize --ignore-ledger       # TRULY FRESH SCAN — act as if no optimize was ever done
                                #   - Backs up ai/optimize/* (ledger, decisions, progress) to *-<iso>.bak.md
                                #   - Re-discovers modules + dependency graph + responsibility map from source
                                #   - Re-runs Phase 0 (architectural diagnosis) from scratch
                                #   - Re-runs Phase 2 (tactical sweep) on every discovered module
                                #   - WRITES new ledger + architecture-decisions + final-report at end
                                #   - KEEPS ADR pre-check (intentional architectural decisions preserved)
                                #   - IMPLIES --re-audit semantics on every row
                                #   - Combinable with <scope>: /optimize the orders module --ignore-ledger
                                #   - Use when: absolute belt-and-braces; suspect original sweep was incomplete; project structure changed substantially
/optimize --re-audit            # IGNORE cached verdicts; re-detect EVERY area
                                #   - Discards `verified` / `done` rows in the optimize ledger (if any)
                                #   - Re-runs Phase 0 (architectural diagnosis) + Phase 2 (tactical) on every area
                                #   - Rows that re-verify clean stay `verified`; rows with reappearing fingerprints flip to `halted` and re-fix in same run
                                #   - Use when: project changed since last sweep OR detector improvements OR you suspect drift
                                #   - Combinable with <scope>: /optimize the orders module --re-audit
/optimize --restart             # WIPE progress, start over from the beginning
                                #   - Backs up current progress to ai/optimize/progress-<iso>.bak.md
                                #   - Resets every area to pending
                                #   - Begins with the first pending area
                                #   - Does NOT revert any commits already made (use git for that)
                                #   - For "ignore everything AND re-audit", combine: /optimize --restart --re-audit
```

## What you see (output)

Backend example (a REST API module):

```
Optimization complete

Scope:               the orders module (backend-nest)
Architectural fixes: 3
  Moved DB queries from controllers → OrderRepository (eliminated 22 N+1 patterns + 8 raw query duplicates)
  Introduced PaginationStrategy abstraction (eliminated 5 dedup sites)
  Centralized error-handling middleware (eliminated 14 ad-hoc try/catch patches)

Tactical findings closed: 18 (down from 67 — 49 dissolved by foundations)
  refactoring:           7 (extract-method ×4, flatten-conditional ×2, replace-magic ×1)
  performance:           4 (sequential awaits → parallel; SELECT * → projected)
  duplicated-logic:      3 (dedupe to introduced abstractions)
  dead-code:             4 (unused exports removed)

Commits:             21 (3 architectural + 18 tactical)
Diff:                +312 / -1894 = -1582 lines
Tests:               298/298 passing
Coverage:            84.1% → 84.5% (no regression)
Wall-clock:          18m 47s

Perf wins (measured):
  POST /orders p95: 410ms → 95ms (-77%)
  GET /orders/:id p95: 220ms → 38ms (-83%)

Skipped (test fixtures): 12 findings

Not validated:       load test at production RPS (no load-test env) — perf wins measured at dev concurrency
Risks:               PaginationStrategy touches every list endpoint — staging smoke pass recommended
Revert:              git revert <first-sha>..<last-sha>  (architectural commits land first — revert tactical-only range to keep foundations)

Next: /review-changes (independent pass before merge)  OR  /optimize the next module  OR  inspect commits via git log --oneline
```

Frontend example (any frontend stack — concrete primitive names depend on framework: composable / hook / store / service / etc.):

```
Optimization complete

Scope:               the orders module (frontend-*)
Architectural fixes: 2
  Moved data-fetching from page components → OrderService data-access primitive (eliminated 8 N+1 patterns)
  Introduced shared pagination primitive (eliminated 4 dedup sites + 2 inconsistent loaders)

Tactical findings closed: 14 (down from 36 — 22 dissolved by foundations)
  refactoring:           5 (extract-shared-primitive ×2, flatten-conditional ×2, rename ×1)
  duplicated-logic:      4 (dedupe to introduced shared primitive)
  dead-code:             3 (unused exports + dead branches)
  over-abstraction:      2 (single-consumer wrappers inlined)

Commits:             16 (2 architectural + 14 tactical)
Diff:                +189 / -847 = -658 lines
Tests:               124/124 passing
Bundle delta:        -2.1% (smaller)
Wall-clock:          11m 23s

Skipped (test fixtures): 7 findings
```

Data-layer example (migrations + queries):

```
Optimization complete

Scope:               the analytics schema (data)
Architectural fixes: 1
  Split AnalyticsRepository (god class, 38 methods) → 4 responsibility-aligned repos (Events / Sessions / Funnels / Cohorts)

Tactical findings closed: 11
  performance:           5 (added 3 covering indexes; replaced 2 N+1 join patterns; pushed 1 in-app filter to DB)
  refactoring:           3 (extract-method ×2, replace-magic-with-constant ×1)
  dead-code:             3 (unused materialized view + 2 unused columns)

Commits:             12
Perf wins (measured):
  funnel_query_p95: 4.2s → 280ms (-93%)
  cohort_export_p95: 18s → 4s (-78%)

Not validated:       none — full suite + EXPLAIN ANALYZE on prod-sized snapshot ran
Risks:               dropped columns are in last night's backup until <date> — restore window closes then
Revert:              git revert <first-sha>..<last-sha>  (index migrations are reversible; see down() in each)
```

## What you DON'T see

- "Phase 3 of 7"
- "Tier promotion needed"
- "Halt: gap-count parity 7/8 — re-run"
- "Ledger updated to status: verified"
- "Per-tier artifact set incomplete"

All internal. Just results.

## Optional flags

- `--dry-run` — show what would be optimized, no edits.
- `--strict` — forwarded to **`validate-optimize-artifacts.sh`**: Phase 0 must reference `_extracted-idioms.md`; **`ai/optimize/ledger.md`** required for full per-row gates.
- `--quiet` — forwarded to **`validate-optimize-artifacts.sh`** (`-q`) when invoking the validator from hooks / CI.
- `--allow-dirty` — proceed with uncommitted changes.
- `--max-parallel=<N>` — cap concurrent dispatch (default: 5).
- `--focus=<list>` — narrow to specific concerns (e.g., `--focus=performance,dead-code`). Default: all classes.
- `--exclude=<scope>` — exclude areas (e.g., `--exclude=tests,migrations,_examples`).
- `--surface-blockers` — show all halted findings, not just the summary.

## Pre-requisites

- `_extracted-idioms.md` OR `codebase-profile.md` populated.
- Mechanical CI green.
- Working tree clean (or `--allow-dirty`).

## Final report contract

Every run that produces `ai/optimize/final-report.md` MUST end with an **`## Actionable next steps`** section per `~/.claude/templates/snippets/actionable-next-steps.md`. Every deferred / out-of-scope / "consider doing this" finding gets one paste-ready follow-up command — comment line (WHAT + WHY + scope) + exact command + sorted by leverage. The validator's `check_actionable_next_steps` halts when the section is missing OR when a deferral is described in prose without a corresponding paste-ready command line. Routes deferrals to receivers (`/refactor` for god files with `--focus=<refactoring-sweep verb>`, `/polish` for visual deferrals, `/add-test` / `/add-adr` / `/add-ci` for follow-ups).

## Hard rules (internal)

Applied silently per the discipline:
- **Validator gate is mandatory.** *(Mechanical — `validate-optimize-artifacts.sh`: Phase 0 blocks + citations + hand-waves + oracle; ledger + `--strict`.)* After Phase 0 produces `ai/optimize/_architecture-decisions.md`, the agent MUST run `~/.claude/scripts/validate-optimize-artifacts.sh`. The validator halts if the four evidence blocks (Dependency map / Responsibility map / Layer attribution / Detector run) are missing or empty, if detectors report zero modules scanned, if any `### F-A-*` lacks `<path:line>`, or if hand-waves are present (see `validate-optimize-artifacts.sh`: `check_phase_0_blocks_nonempty`, `check_per_finding_citations_phase0`, `check_no_handwaves_file`). **`--strict`** also requires the idioms oracle to be referenced and requires `ai/optimize/ledger.md` for per-row gates. A failed validator forces the diagnosis to be re-emitted. Without this gate, Phase 0 can produce a summary diagnosis instead of an actual scan — the F039 anti-Trusted-Summary recurrence applied to /optimize.
- **Final report MUST end with paste-ready next steps.** *(Mechanical — `validate-optimize-artifacts.sh § check_actionable_next_steps`.)* Per `actionable-next-steps.md` snippet contract; halts the gate when missing or when deferrals are described without commands.
- **Honesty clause in the summary block is mandatory.** The three lines `Not validated:` / `Risks:` / `Revert:` close every run summary. The agent MUST name validation that did NOT run (load tests, prod-sized data, environments unavailable) or state `none — <what fully ran>`. `Tests: N/N passing` alone hides the negative space — the same failure mode as the Trusted Summary. `Revert:` gives the exact git command for this run's commit range.
- **Architectural diagnosis ALWAYS runs first**. *(Agent-side orchestration.)* Tactical fixes are skipped on findings that would dissolve under a foundation fix; agent picks the foundation.
- **Foundation-first ordering**: architectural commits land before tactical commits. The architecture-decisions document records the order + rationale. *(Agent-side.)*
- Closure verbs from a closed vocabulary (no new abstractions invented; `introduce-abstraction` only applies when ≥3 sites duplicate the same shape). *(Agent-side.)*
- Net-lines ≤ 0 for tactical structural fixes; refactoring class allowed small +/- but cites why; architectural fixes net-lines budgeted (move-responsibility may +N then -2N when consumer code shrinks). *(Structural rows: mechanical when `--phase-base` + git commits match `<id>:` / `optimize/<id>:` — else warn-only.)*
- Behaviour preserved (lint, typecheck, scoped tests, coverage all green) for ALL structural + refactoring + dead-code + dedup + over-abstraction fixes. *(Agent-side verification.)*
- Re-detect after each fix; gap-count parity (`gaps_in == gaps_closed`) before the row advances. *(Mechanical for terminal ledger statuses when ledger exists.)*
- One commit per finding (architectural or tactical). *(Agent-side.)*
- Security findings always ship with assertions (test added in same commit). *(Agent-side.)*
- Performance findings always ship with baseline + post-fix measurement. *(Agent-side.)*

User sees the result, not the policing.

## Failure modes

- **No findings detected** → outputs "Codebase already optimized for the requested classes; nothing to do."
- **Pre-flight red** → halts; surfaces what to fix.
- **All findings blocked** → halts; surfaces the blockers list.
- **Behaviour change risk** (e.g., a `parallelize` would race against shared state) → that finding skips with note; rest continue.

## Related (advanced)

For specialist or class-specific runs, the existing detailed surfaces still exist:
- `/perf-audit` — perf-only deep audit (performance pack).
- `/profile-perf` — runtime profile capture (performance pack).
- `/simplify` — code simplification command (code-quality pack).
- `/check-health` — read-only quality + boundary audit (code-quality pack).
- `architectural-diagnosis` skill — layer-violation / god-module detection.
- `refactoring-sweep` skill — tactical close-out (clean code / SOLID / dedup).
- `dead-branch-scan` skill — dead-code detection.
- `/db-audit` — database-only.

`/optimize` dispatches these internally with sensible defaults.
