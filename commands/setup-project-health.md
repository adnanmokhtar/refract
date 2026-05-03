---
description: Report the health of /setup-project artifacts in the current repo. Drift, staleness, budget breaches, dead files, missing ADRs. Read-only — never writes.
kind: command
pack: orchestration
version: 1.0.0
related-commands:
  - /setup-project — generate or refresh setup
  - /setup-project-adapters — re-sync tool adapters
  - /learn-from-task — Phase 6 manual entry point
---

# /setup-project-health

## The Premise (read first, internalize, do not deviate)

**Read-only health audit. Cite real artifacts. No vague "looks healthy" verdicts.** Every check produces a concrete metric (count, age in days, file path, line number, sha) — or the check did not run. "Appears fine" / "looks healthy" / "in good shape" are forbidden phrases; they are the failure mode this command exists to prevent.

**The agent's job is exactly this:**
1. Run each numbered check; record `ok | warn | fail | n/a` with the underlying metric (the number, the file, the age).
2. Cite the source rule (from `templates/idempotency.md` / `templates/governance/hard-rules.md` / Phase 6 budgets) for every threshold used. Heuristics without source = not allowed.
3. Never write — not even logs. The contract is read-only.
4. Produce a deterministic table: same repo state → same report (modulo timestamps).

## Mechanical halt (refuse to ship hand-wave verdicts)

1. **Ban hand-wave grep**: a check status MUST cite the metric that produced it. The strings `looks fine`, `looks healthy`, `appears healthy`, `in good shape`, `seems ok`, `roughly`, `probably fine` are forbidden in the output. If the check has no metric, status is `n/a` with the reason ("git not available", "no `ai/` directory yet"), not a soft pass.
2. **No threshold without source**: every `ok / warn / fail` boundary MUST cite the rule it came from (e.g. `> 300 lines → fail` cites `templates/idempotency.md` budget). Unsourced thresholds → drop the check, don't fabricate a number.
3. **No write side-effects**: if the agent finds it needs to write to fix something, it stops, surfaces the fix as a *Recommended action*, exits. The user runs `/setup-project --refresh` (or similar). This command never mutates.
4. **Determinism check**: if two consecutive runs on the same git SHA produce different verdicts (modulo timestamps), the check is non-deterministic and must be removed or pinned.

A read-only reporter that tells you whether the setup is **alive** or **rotting**.

Phase 6 (continuous learning) only matters if you can measure it. This command answers: is the knowledge layer staying in sync with reality?

## When to run

- Before opening a major PR — make sure conventions reflect the current code.
- Weekly, scheduled — see `/schedule` to wire it as a routine.
- When `/setup-project` says "no work to do" but you suspect drift.
- After a long branch lands — many files changed, conventions may be stale.

## What it checks

Every check returns one of: `ok`, `warn`, `fail`, `n/a`.

### 1. Digest freshness

```
ai/_session-digest.md             age <= 7 days  → ok
                                  age <= 30 days → warn
                                  age >  30 days → fail
ai/_convention-cheatsheet.md      same thresholds
ai/_decision-index.md             rebuilds on every ADR; mismatch with ADR count → fail
```

### 2. ADR coverage

```
ADR count                                     → reported
ADRs created in last 90 days                  → reported
ADRs referenced in CLAUDE.md / conventions    → reported as ratio
Decisions made in commit messages WITHOUT ADR → flag (possible undocumented decision)
```

Heuristic for "decision made without ADR": commit messages matching `(decided|switching to|moving away from|chose|adopted)` against files in `src/` over the last 30 days, where no ADR was added in the same window. Surface as `warn`, not `fail` — the user decides if it warrants an ADR.

### 3. Convention drift

For each rule in `ai/conventions.md` that asserts a code-level fact (file naming, suffix matrix, base-class usage), spot-check the rule against the current codebase via grep. A rule with zero matches in 90+ days → `warn` (probably stale or wrong).

### 4. Budget status

From `templates/idempotency.md` and Phase 6 budgets:

```
ai/                       file count        → fail if > 50
ai/<file>                 line count        → fail if > 300 for non-ADR files
CLAUDE.md                 line count        → fail if > 200
ai/_session-digest.md     line count        → fail if > 300
.claude/rules/            file count        → warn if > 30
```

Budgets exist because every file in `ai/` competes for context. Without a ceiling, the knowledge layer becomes the next monolith.

### 5. Dead-file detection

A file under `ai/` is "dead" if:

- No `git log --follow` activity in 180 days, AND
- Not referenced by `@ai/...` in CLAUDE.md, conventions, or any rule.

Dead files are `warn` — never auto-deleted. The user decides.

### 6. Tool-adapter parity (if adapters present)

For each adapter under `.opencode/`, `.cursor/`, `.aider*/`, etc., verify the per-adapter completeness contract from `commands/setup-project-adapters.md` (Phase 4.8.0). A missing artifact type = `fail`.

### 7. Idempotency markers

```
Files under managed paths missing markers   → fail
Markers with mismatched start/end IDs       → fail
Markers from a future version (v > current) → warn
```

A managed file without markers cannot be safely re-run. This is the single most important check for refactor safety.

### 8. Setup version drift

Compare the `setup-project: vN` marker stamped into the repo vs the current command version. Mismatch → suggest `/setup-project --upgrade`.

## Output format

```markdown
# Setup health: <one of: healthy / drifting / stale / broken>

| Check                    | Status | Detail                                |
|--------------------------|--------|---------------------------------------|
| Digest freshness         | ok     | _session-digest.md updated 2 days ago |
| ADR coverage             | warn   | 4 commits suggest decisions, 0 ADRs   |
| Convention drift         | ok     | 23/23 rules still match code          |
| Budget                   | warn   | ai/conventions.md = 312 lines (>300)  |
| Dead-file detection      | ok     | none                                  |
| Tool-adapter parity      | n/a    | no adapters configured                |
| Idempotency markers      | ok     | 47/47 managed files marked            |
| Setup version            | ok     | repo v2.0.0 == current v2.0.0         |

## Recommended actions

1. Add ADRs for the 4 flagged commits OR mark them as non-architectural in this run's history log:
   - <sha-1>: switched session storage to Redis
   - <sha-2>: moved auth middleware to FastAPI dependency
   - …

2. Trim `ai/conventions.md`:
   - Promote duplicates into a single rule.
   - Move stale rules to ai/_archive/conventions-2026-Q1.md.
```

## Exit codes

- `0` — all checks `ok` or `warn`. Repo is healthy or recovering.
- `1` — at least one `fail`. Repo needs attention before next setup re-run.
- `2` — usage error.

## What this command does NOT do

- It NEVER writes. Not even logs. Read-only by contract.
- It does NOT auto-fix drift. The point is to surface, not to silently mutate.
- It does NOT call out to networked services. All checks are local.

## Implementation notes

- All filesystem checks must be runnable in <5 seconds on a 50k-LOC repo.
- Heuristics MUST cite the source rule from `templates/idempotency.md` or `templates/governance/hard-rules.md` so the user can challenge them.
- Output is deterministic: same repo state → same report (modulo timestamps).

## Why this command exists

The promise of `/setup-project` is "set up once, learn forever." Without measurement, "learn forever" is faith-based. This command makes the learning loop falsifiable.

If three repos run `/setup-project-health` and all return `stale`, the answer isn't "tell users to run health more often" — it's "Phase 6 is broken, fix the loop." That feedback channel did not exist before M3.
