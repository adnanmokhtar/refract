---
description: Universal bug-fix workflow. Stack-aware (detects backend / frontend / mobile / fullstack from CLAUDE.md). Reproduce → diagnose → fix → verify → regression test → root-cause notes. The default fix-bug command for any project.
---

# /fix-bug

Universal bug-fix command. Use it whether the bug is in backend (a 500 error), frontend (a UI glitch), mobile (a crash), data (a wrong query), or cross-stack.

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## When to use / NOT to use

- USE: any bug — server error, wrong UI, broken flow, intermittent failure, perf regression.
- USE: regression — a previously-working feature stopped working.
- USE: customer-reported issue with reproducible signal.
- NOT: a feature request → use `/add-feature`.
- NOT: a refactor without a bug → use `/refactor` (code-quality).
- NOT: a perf optimization without a regression → use `/profile-perf` (performance).

## Phase 1 — Understand (the bug)

Capture from user / ticket:
- **Symptom**: what does the user see / experience?
- **Expected**: what should happen instead?
- **Reproducer**: smallest set of steps that triggers it. If not reproducible, that's a finding.
- **Frequency**: every time / sometimes / rare.
- **Environment**: production / staging / dev. Which version. Which device / browser. Which user / tenant.
- **First seen**: when did it start? (Helps bisect.)
- **Severity**: outage / data corruption / functional failure / cosmetic.

If user provides a stack trace, error message, log line, or screenshot, treat as primary evidence.

## Phase 2 — Organize (decompose)

Detect the bug class:

| Class | Signal | Stack |
|---|---|---|
| 5xx error | server returns 5xx | backend |
| 4xx error (client error reported as bug) | server returns 4xx but should accept | backend (validation) |
| Wrong response shape | server returns wrong structure | backend |
| Wrong response data | server returns wrong values | backend / data |
| UI doesn't render | frontend / mobile blank | frontend / mobile |
| UI renders wrong | frontend / mobile shows wrong | frontend / mobile |
| Form / input not working | frontend submit broken | frontend |
| Crash | mobile crash | mobile |
| Slow / timeout | performance | performance pack |
| Race condition / intermittent | timing-dependent | varies |
| Cross-tenant data leak | security | security pack — escalate |
| Auth / permission wrong | access control | security pack — escalate |

Stack detection from `CLAUDE.md` declares stack. The command dispatches to relevant agents (see Phase 4).

## Phase 3 — Retrieve

Read in order:
1. The reproducer steps + any attached evidence (logs, screenshots, traces).
2. `CLAUDE.md` — declared stack + anti-patterns.
3. `ai/architecture.md` — module boundaries.
4. `ai/_baseline/failures/` — has this class shipped before? Cite the failure entry if so.
5. The file(s) the symptom points to (controller / view / endpoint).
6. Recent commits to those files (`git log --oneline -10 <file>`) — bisect candidate.
7. Relevant patterns from `ai/patterns/`.
8. Related rules in `.claude/rules/`.

For backend: APM trace if available; database query log; recent migrations.

For frontend: browser console, network tab, recent UI commits.

For mobile: crash logs (Crashlytics / Bugsnag), recent native bridge changes.

## Phase 4 — Generate (the fix)

### 4a. Reproduce

Get the bug to fire deterministically. If you can't reproduce, you can't fix:
- Try the user's exact reproducer.
- Try with same env (staging / dev / prod-like).
- Try with same data shape (production-shaped, not synthetic).
- Try at the same scale (concurrency, N items in list, etc.).

If still not reproducible:
- Hypothesize: race condition / data shape / specific user / specific tenant.
- Add observability (log, metric, trace) to next occurrence.
- Document inability to reproduce as a finding; ship the observability.

### 4b. Diagnose

Trace the bug to its root cause:
- For backend: trace through controller → service → repo → DB. Where does the wrong value originate?
- For frontend: trace state → render path. Which prop / store value is wrong?
- For mobile: trace navigation / state / native bridge.

The bug-investigator agent does this systematically. Dispatch:

```
@bug-investigator reproduce + diagnose: <symptom>; reproducer: <steps>
```

Output: root-cause file path + line + explanation.

### 4c. Fix

The fix should be:
- **Minimal** — change only what's necessary.
- **Targeted** — at the root cause, not a workaround.
- **Reversible** — should be safe to revert if the fix has unintended consequences.
- **Anchored** to existing conventions (don't introduce new patterns to fix one bug).

If the fix requires a new pattern → flag for ADR before merging.

### 4d. Verify

Three layers of verification:
1. **The reproducer no longer fires the bug.** (Deterministic.)
2. **A regression test exists** that catches this bug class. Add if missing.
3. **No new regressions in surrounding tests.** Run full test suite.

For UI bugs: visual verification (screenshot or video).
For mobile bugs: verify on iOS + Android.
For backend bugs: verify with production-shaped data.

Dispatch reviewers:
- `@code-reviewer` — fix quality + convention adherence.
- `@bug-investigator` — verify the diagnosis was correct.
- `@security-auditor` if the bug class touches auth / tenant / data integrity.

## Phase 5 — Update

- `ai/_baseline/failures/<NNNN>-<slug>.md` — append-only failure entry. Captures: what we tried, why it failed (if previous attempts), root cause, what we did, don't-retry conditions.
- `ai/dynamic/changelog.md` — entry for the bug fix.
- `ai/patterns/<name>.md` — IF a new pattern was extracted to prevent recurrence (rare; usually the existing convention covered it).
- `ai/decisions/<NNNN>-*.md` — IF the fix required an architectural choice.

## Phase 6 — Validate

- The reproducer is now green.
- Regression test added.
- Full test suite passes.
- No new lint / type errors.
- Cross-stack: if the fix touched multiple layers, both verified.

## Phase 7 — Improve

- If similar bug shipped before AND no regression test prevented it → root-cause the gap (test framework deficiency? coverage gap? pattern not enforced?).
- If the bug class is recurring → propose a rule / pattern preventing it.
- If diagnosis was hard (took > 2 hours) → propose better observability (log / metric / trace) so next time is faster.

## Output format

```
## /fix-bug — <one-line description>

Symptom:        <description>
Stack:          <detected from CLAUDE.md>
Reproducer:     <steps>
Severity:       <outage / data / functional / cosmetic>

Root cause:
- File: <path>:<line>
- Cause: <one-line description>
- First introduced: <commit-sha> by <author> on <date> (if bisected)

Fix:
- Files modified: <list>
- Approach: <one-line description>
- Tests added: <list>

Verification:
- Reproducer: PASSING (was failing)
- Regression test: added
- Full test suite: PASSING
- Manual: <verified on iOS + Android / browser X / staging>

Knowledge updates:
- ai/_baseline/failures/<file> — root cause documented
- ai/dynamic/changelog.md — entry added
- ADR <NNNN> (if applicable)

Open follow-ups:
- <thing flagged>
```

## Hard rules

- **Reproduce first, fix second.** A fix without a reproducer is a hypothesis.
- **Root cause, not symptom.** Don't paper over with try/catch + log.
- **Regression test before merge.** Bug fixed without a test = bug returns.
- **Failure-catalog entry.** Future you (or your colleague) shouldn't repeat the diagnosis.
- **Cross-stack verification when applicable.** A backend fix that needs a frontend change isn't done.
- **Surgical scope.** Don't bundle "while I'm here, let me clean up X" into a bug fix PR.

## Failure modes

- "Fix" was actually a workaround — bug returns when conditions slightly change.
- Fix introduced a NEW bug in adjacent code.
- Fix worked in dev / not in production due to environment difference (config, scale, data).
- Regression test only covers the exact reproducer; doesn't generalize to the bug class.
- Diagnosed wrong root cause; fix masks the symptom but real issue lurks.
- Fix in one layer; bug surfaces again because root is in adjacent layer (e.g., backend-fixed but frontend retry triggers it again).
- Failure-catalog entry too vague ("auth bug" instead of "JWT signature verification failed when issuer rotated keys mid-session").

## Related

- `@bug-investigator` agent — the diagnosis specialist (auto-dispatched by Phase 4b).
- `@code-reviewer` — fix-quality reviewer (auto-dispatched by Phase 4d).
- Stack-specific `/fix-bug` commands in pack equivalents (backend has its own enriched version; this is the universal baseline).
- `/profile-perf` — when the "bug" is actually slowness.
- `ai/patterns/api-contract.md`, `error-handling.md`, etc. — patterns the fix should respect.
- `ai/_baseline/failures/_index.md` — read this first; the bug class may already be cataloged.
