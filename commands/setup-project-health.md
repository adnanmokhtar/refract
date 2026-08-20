---
description: Read-only report on whether this repo's /setup-project artifacts have drifted or gone stale. Dead files, budget breaches, missing ADRs, unconfirmed claims. Trigger on 'is my setup stale', 'check setup health', 'are the conventions still in sync with the code', 'why does /setup-project say there is no work to do'. Do NOT trigger on any ask to FIX drift (/setup-project --refresh) or when the caller expects a write of any kind. It grades setup artifacts, not product code — that is /audit.
compatibility: Read-only by contract — never writes, not even logs, and makes no network calls, so every check is local. Requires a repo already processed by /setup-project; with no .claude/ present there is nothing to grade. Exit codes are contractual — 0 for ok or warn, 1 for any fail, 2 for usage error.
kind: command
pack: orchestration
version: 1.2.0
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

For each adapter under `.opencode/`, `.cursor/`, `.aider*/`, etc., verify the per-adapter completeness contract from `commands/setup-project-adapters.md` (**Phase B — Per-adapter completeness contract**, § "Per-adapter minimum output"). A missing artifact type = `fail`.

### 7. Idempotency markers

```
Files under managed paths missing markers   → fail
Markers with mismatched start/end IDs       → fail
Markers from a future version (v > current) → warn
```

A managed file without markers cannot be safely re-run. This is the single most important check for refactor safety.

### 8. Setup version drift

Compare the `setup-project: vN` marker stamped into the repo vs the current command version. Mismatch → suggest `/setup-project --upgrade`.

### 9. Oracle approval + provenance

The extraction artifacts (`.claude/_extracted-idioms.md`, `.claude/_extracted-codebase.md`) are the oracle every Phase 4 generator and migration/align audit trusts. Source rule: `templates/phases/phase-2-profile.md § Oracle approval` + `§ Provenance discipline`.

```
file missing                                → n/a   (extraction never ran — e.g. --lightweight setup)
approved_by: empty                          → warn  "oracle never human-reviewed"
approved_hash ≠ recomputed body hash        → warn  "oracle changed since approval by <name>@<date>"
[unconfirmed] / [UNKNOWN] claim count       → reported; > 0 → warn (list each claim)
[inferred:] / [INFERRED] claim count        → reported (informational — no warn)
```

Body hash recompute: `grep -v '^approved_' <file> | shasum -a 256 | cut -c1-12`. Count both marker spellings (`_extracted-business.md` uses `[CONFIDENT]/[INFERRED]/[UNKNOWN]`; the others use `[found:]/[inferred:]/[unconfirmed]`).

Approval is advisory by design — this check emits `warn`, never `fail`. When it warns, the *Recommended actions* section prints the paste-ready stamp command:

```bash
# after reading .claude/_extracted-idioms.md and confirming it matches reality:
HASH=$(grep -v '^approved_' .claude/_extracted-idioms.md | shasum -a 256 | cut -c1-12)
sed -i '' "s/^approved_by:.*/approved_by: <your-name>@$(date -u +%Y-%m-%dT%H:%MZ)/; s/^approved_hash:.*/approved_hash: $HASH/" .claude/_extracted-idioms.md
```

(The stamp command is the ONE write in this command's orbit — and it is run by the USER, not the agent. The read-only contract of this command itself is unchanged.)

### 10. Plan seam (Phase 3.5 — `--plan` / verify-plan / execute-plan)

The spec→plan→build seam ships in every repo's baseline. Without it, `--plan` is a dead flag and the "Opus plans, Sonnet executes" handoff silently doesn't exist. Source rule: `commands/setup-project-adapters.md § "--plan flag translation (Phase 3.5)"` + `repo-baseline/.claude/commands/{verify-plan,execute-plan}.md`.

```
.claude/commands/verify-plan.md present                          → ok; missing → fail
.claude/commands/execute-plan.md present                         → ok; missing → fail
.claude/plans/ directory OR .claude/plans/README.md present      → ok; missing → warn (plan format undocumented)
Each selected adapter has its `--plan` translation                → ok; any selected adapter missing it → fail
```

Per-adapter `--plan` translation check (only for adapters actually selected, read from `.claude/codebase-profile.md`'s adapter list — the same map in `setup-project-adapters.md § "--plan flag translation"`):

- `opencode` → the command's `prompt` in `.opencode/commands/*.md` (or `opencode.json` `commands` block) branches on `--plan`.
- `cursor` → `.cursor/commands/command-*.mdc` (or the skills-first `.cursor/skills/*/SKILL.md`) carries a "Plan mode" section.
- `aider` → `CONVENTIONS.md` has a "Plan mode" section AND `.aider.conf.yml` `read:` includes `.claude/plans/README.md`.
- `continue` / `cline` / `windsurf` / `copilot` → the translated command prompt branches on `--plan`.
- `codex` → `.agents/skills/*/SKILL.md` body branches on `--plan`; `AGENTS.md` notes "supports `--plan`".
- `gemini` → `.gemini/commands/*.toml` `prompt` branches on `{{args}}` containing `--plan`.

`claude-code` is native (Phase 3.5 runs as written) → always `ok`. A selected non-Claude adapter whose commands don't honor `--plan` = `fail` (the flag is dead in that tool). No adapters selected → the per-adapter sub-check is `n/a`; the verify-plan/execute-plan presence sub-checks still run.

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
| Oracle approval          | warn   | _extracted-idioms.md never human-reviewed; 2 [unconfirmed] claims |
| Plan seam                | fail   | execute-plan.md present; cursor missing `--plan` translation |

## Recommended actions

1. Add ADRs for the 4 flagged commits OR mark them as non-architectural in this run's history log:
   - <sha-1>: switched session storage to Redis
   - <sha-2>: moved auth middleware to FastAPI / Express / Django-style dependency injection
   - …

2. Trim `ai/conventions.md`:
   - Promote duplicates into a single rule.
   - Move stale rules to ai/_archive/conventions-2026-Q1.md.

3. Review + stamp the oracle (2 [unconfirmed] claims need answers first):
   - "Payment retry policy [unconfirmed]" — _extracted-codebase.md § Cross-cutting concerns
   - "Tenant cache TTL [unconfirmed]" — _extracted-idioms.md § Conventions
   Then run the stamp command from check 9.
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
