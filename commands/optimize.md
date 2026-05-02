---
description: One command code optimization. Deep multi-agent execution. Takes optional scope (whole project OR specific module/area). NO phases visible, NO terminology, NO mid-run questions. Internally runs scan + fix in parallel waves for performance + clean code + dedup + dead code + over-abstraction. Output is brief: findings closed, commits, diff stats, test status. The simple-surface alternative to /align-scan + /align-fast cycles for code quality.
kind: command
pack: orchestration
---

# /optimize [<scope>]

## What this does

**Single command. Make the codebase high-quality: clean code + clean architecture + SOLID.** Deep multi-agent scan + fix. Whole project or scoped.

The agent:
1. **Deep-scans the codebase** for every quality concern in one pass.
2. **Detects + fixes** all of these in parallel:
   - **Clean code** — long functions, deep nesting, magic numbers, bad naming, redundant comments, comment-as-rename.
   - **Clean architecture** — modules in the wrong layer, circular dependencies, components importing services directly when they should go through composables, services importing UI primitives, leaking abstractions.
   - **SOLID principles**:
     - **SRP** (Single Responsibility) — split god classes / multi-purpose modules into named-in-idioms responsibilities.
     - **OCP** (Open/Closed) — extend instead of modify closed modules.
     - **LSP** (Liskov Substitution) — fix subtype contract breaks (override changes pre/post-condition).
     - **ISP** (Interface Segregation) — split fat interfaces with unused members.
     - **DIP** (Dependency Inversion) — high-level modules depend on abstractions, not concretions.
   - **Performance** — N+1 queries, sequential awaits where parallelism is safe, sync HTTP in hot paths, missing cache at known-cacheable sites, missing index where query shape demands one, `SELECT *` consumed by < 5 fields, in-app filtering pushable to database.
   - **Dead code** — unused exports, unreachable branches, dead variables.
   - **Duplicated logic** — same code in N files (dedupes to existing shared helper).
   - **Over-abstraction** — wrapper with one consumer (inline), useless `options: {foo?:bool}` where every caller passes the same value.

3. **Behaviour-preserving for structural fixes** (clean code, dead code, dedup, over-abstraction). Tests must stay green.
4. **Behaviour-changing where safe** for perf fixes (parallelize, batch, cache) — adds assertions in same commit.

Output: what got optimized, commits, diff stats, test status, perf wins (measured).

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
/optimize src/modules/orders/                      # explicit path
/optimize "everything except tests and migrations" # exclusion-by-description
```

## What happens internally (silent)

1. **Scan** — runs the relevant detectors across the scope: dead-code, duplicated-logic, over-abstraction, performance (N+1, sequential awaits, missing cache, etc.), clean-code (long functions, magic numbers, naming), SOLID violations.
2. **Resolve scope** — semantic resolution of description to source paths.
3. **Plan internally** — group by class + dependency. Foundation patterns first (e.g., introduce a shared helper before deduping consumers). NO phase output to user.
4. **Multi-agent parallel fix** — dispatch one agent per finding cluster. Each agent: re-detect → apply fix → verify → commit.
5. **Verify continuously** — lint + typecheck + scoped tests after each fix. Coverage must not drop. Behaviour-preserving for all structural fixes; security/perf fixes ship with assertions.
6. **Self-resolve common questions** — closure verbs are mechanical (`remove`, `inline`, `dedupe`, `replace-with-shared`, `parallelize`, `batch`, `cache-with-explicit-ttl`). Agent doesn't ask for permission per fix.
7. **Halt only on genuine blockers**:
   - A fix would change observable behaviour where it must be preserved (re-classify as refactor; user decides).
   - Idiom missing for a functional fix (e.g., user wants caching but project has no cache primitive — surfaces "add primitive first via /setup-project --refine").
   - Security-sensitive change beyond mechanical fix.
   - Otherwise: just optimize.
8. **Skip findings that aren't load-bearing** — clean-code findings in test fixtures / one-time scripts skip; only ship-path code gets optimized.

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
Codebase: /Users/mac/Workspace/Projects/sahlcart/tenant-portal-v2/src/

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
/optimize --restart             # WIPE progress, start over from the beginning
                                #   - Backs up current progress to ai/optimize/progress-<iso>.bak.md
                                #   - Resets every area to pending
                                #   - Begins with the first pending area
                                #   - Does NOT revert any commits already made (use git for that)
```

## What you see (output)

```
Optimization complete

Scope:               the orders module
Findings closed:     34
  performance:        8 (N+1 queries → batched; 3 sequential awaits → parallel)
  duplicated-logic:   12 (dedupe to existing shared helpers)
  dead-code:          7 (unused exports removed)
  over-abstraction:   4 (single-consumer wrappers inlined)
  clean-code:         3 (long functions extracted to existing services)

Commits:             34 (one per finding)
Diff:                +89 / -612 = -523 lines
Tests:               124/124 passing
Coverage:            87.4% → 87.6% (no regression)
Wall-clock:          12m 47s

Perf wins (measured):
  listOrders(): 51 queries / 200ms p95 → 2 queries / 35ms p95 (-83%)
  getCustomer batch: 47 calls → 1 batched call

Skipped (clean-code in test fixtures): 23 findings (out of scope)

Next: /optimize the next module  OR  inspect commits via git log --oneline
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
- `--allow-dirty` — proceed with uncommitted changes.
- `--max-parallel=<N>` — cap concurrent dispatch (default: 5).
- `--focus=<list>` — narrow to specific concerns (e.g., `--focus=performance,dead-code`). Default: all classes.
- `--exclude=<scope>` — exclude areas (e.g., `--exclude=tests,migrations,_examples`).
- `--surface-blockers` — show all halted findings, not just the summary.

## Pre-requisites

- `_extracted-idioms.md` OR `codebase-profile.md` populated.
- Mechanical CI green.
- Working tree clean (or `--allow-dirty`).

## Hard rules (internal)

Applied silently per the discipline:
- Closure verbs from a closed vocabulary (no new abstractions invented).
- Net-lines ≤ 0 for structural fixes; functional fixes cite existing idioms.
- Behaviour preserved (lint, typecheck, scoped tests, coverage all green).
- Re-detect after each fix.
- One commit per finding.
- Security findings always ship with assertions (test added in same commit).
- Performance findings always ship with baseline + post-fix measurement.

User sees the result, not the policing.

## Failure modes

- **No findings detected** → outputs "Codebase already optimized for the requested classes; nothing to do."
- **Pre-flight red** → halts; surfaces what to fix.
- **All findings blocked** → halts; surfaces the blockers list.
- **Behaviour change risk** (e.g., a `parallelize` would race against shared state) → that finding skips with note; rest continue.

## Related (advanced)

For phase-by-phase control or class-specific runs, the existing detailed commands still exist:
- `/align-scan` — inventory only.
- `/align-fast <N>` — run one phase.
- `/align-recheck <scope>` — focused area.
- `/perf-audit` — perf-only deep audit.
- `/db-audit` — database-only.

`/optimize` dispatches these internally with sensible defaults.
