---
description: Universal bug-fix workflow. Stack-aware (detects backend / frontend / mobile / fullstack from CLAUDE.md). Reproduce → diagnose → failing test FIRST → fix → verify → root-cause notes (TDD). The default fix-bug command for any project.
---

# /fix-bug

> **This is the universal-minimum baseline.** It is the subset every project inherits. Pack equivalents (e.g. `templates/packs/backend/commands/fix-bug.md`) are **enriched supersets** that add ceremony (telemetry-gap check, signal-aware reviewer cascade, postmortems) on top of — never instead of — this baseline. Both share the two non-negotiable invariants in [`templates/snippets/fix-bug-core.md`](../../../snippets/fix-bug-core.md): **failing-test-first** and the **similar-bugs ledger**. If this file ever contradicts that snippet, the snippet wins.
>
> **`--plan`**: this command honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/fix-bug <desc> --plan` diagnoses + plans, writes the plan file, and exits before any edit.

## The Premise (read this first, internalize, do not deviate)

**The bug is real. The fix is small. The pattern almost always exists elsewhere.**

A reported bug is a sample, not the population. The same root cause that broke site A almost always broke siblings B, C, D — different files, different routes, same expression, same omission. Shipping a fix for site A only is the failure mode that produces "we already fixed this" reports next month.

**The agent's job is exactly this:**
1. Find the **root cause**, not the symptom — the smallest expression / line / branch that produces the bad behavior.
2. Write a **failing test FIRST** that reproduces the root cause, then apply the **minimum fix** at that site — change only what makes the failing test pass.
3. **Grep the codebase** for the same root-cause pattern (the literal expression, not a vague concept).
4. Fix **all N occurrences** in the same diff — or explicitly account for each hit (intentional / follow-up).

**The agent does NOT:**
- Ship a fix that ignores siblings of the same pattern. **One bug, one diff, all sites.**
- Refactor adjacent code that wasn't part of the bug — even if it "looks bad." Drift goes to `ai/dynamic/drift-log.md`, not into this PR.
- Draft an ADR for a trivial fix. ADRs document new defensive patterns; a 1-line null check is not a new pattern.
- Ask the user "are these really the same bug?" — apply the literal-expression test: same buggy expression = same bug.

**The agent ONLY asks the user when:**
- The fix needs another repo (cross-repo blocker).
- Root cause sits in a shared utility / library where one fix changes behavior for many callers (ripple risk).
- The bug reveals an entirely missing test class (the right answer is "add the class," which is scope expansion the user must approve).

That's it. Three escalation triggers. Everything else — sibling-scan, fix-all-N, verify with the project's existing tests — is silent and one diff. Default is **trivial-tier**: just fix it.

## Closure-verb table (bug complexity → ceremony)

| Tier | Trigger | Required artifacts | Skipped |
|---|---|---|---|
| **Trivial** (default) | 1 site, 1-line fix, root cause obvious from the report | Failing test → fix → test passes | Plan, ADR, investigation doc, similar-bugs scan (only because there's one site by definition) |
| **Standard** | ≥2 sites of the same pattern OR fix touches ≥3 lines OR root cause requires reading 2+ files to understand | Code edit + similar-bugs scan with `N_found == N_fixed + N_explained + N_followup` accounting + 1-paragraph "what was wrong" note in PR description | ADR (unless introducing a new defensive pattern), separate investigation doc |
| **Heavy** | Library-level pattern, race condition, security/privacy/data-loss implication, schema migration | Code edit + ADR (new defensive pattern) + investigation doc + reviewer dispatch (whatever review agent the project's pack provides) | — |

Trivial is default. Heavy investigation-then-plan-then-fix-then-ADR ceremony is opt-in for genuinely heavy bugs only. Most fixes are 1-line.

## Similar-bugs scan (mechanical halt — applies at standard + heavy)

After the reported-site fix is applied:

1. **Grep the codebase** for the literal root-cause pattern (the actual buggy expression — `if (user)` not `null check`; `.map(x => x.toLowerCase())` not `case insensitivity`).
2. **Count hits.** Each hit is one of three:
   - **Fixed** — same fix applied in this PR.
   - **Explained** — 1-line note in PR: "this hit is intentionally different because X" (e.g., this site has a non-null guarantee from upstream).
   - **Follow-up** — separate ticket created, ID referenced in PR. Used when fixing all hits would make this PR too large.
3. **Mechanical halt:** PR refuses merge if `N_found != N_fixed + N_explained + N_followup`. Every hit is accounted for; no silent skips.

**Trivial-tier exception:** by definition, trivial-tier fixes have only one site. The moment a 2nd hit appears, the row auto-promotes to standard-tier and the scan becomes mandatory.

## Phases applied

Trivial-tier collapses Phases 5 (Update) and 7 (Improve) into one-line entries. Heavy-tier ceremony (all 7 phases) is opt-in.

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve), with **Phase 4 = TDD (failing test FIRST, then fix)** — described below for the heavy-tier case.

## When to use / NOT to use

- USE: any bug — server error, wrong UI, broken flow, intermittent failure, perf regression.
- USE: regression — a previously-working feature stopped working.
- USE: customer-reported issue with reproducible signal.
- NOT: a feature request → use `/add-feature`.
- NOT: a refactor without a bug → use `/refactor` (code-quality).
- NOT: a perf optimization without a regression → use `/profile-perf` (performance).

## Phase 1 — Understand (the bug)

### Intent gate (mandatory pre-step)

Parse the user's description for keywords that indicate a different command is the right choice. `/fix-bug` is for INCORRECT BEHAVIOR — wrong output, crash, error, regression. NOT for visual polish, enhancement, or new features.

**Universal keyword routing** (add / enhance / audit / …): see [`templates/snippets/intent-gate-skeleton.md`](../templates/snippets/intent-gate-skeleton.md).

| User description contains | Right command | Action |
|---|---|---|
| "broken" / "crash" / "error" / "wrong output" / "regression" / "doesn't work" — actual bug | `/fix-bug` (this command) | Proceed |

If ambiguous: ASK "is this incorrect behavior, or a quality / enhancement task?" Route based on answer.

If user insists on `/fix-bug` for a non-bug task, proceed but flag in the run summary that a redirect was suggested but overridden.

### Standard inputs

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

**MUST read** [`templates/governance/core-discipline.md`](../templates/governance/core-discipline.md) before generating code fixes.

Read in order:
1. The reproducer steps + any attached evidence (logs, screenshots, traces).
2. `CLAUDE.md` — declared stack + anti-patterns.
3. `ai/architecture.md` — module boundaries.
4. `ai/failures/` *(if the project maintains a failure catalog)* — has this class shipped before? Cite the failure entry if so; skip silently if the directory doesn't exist.
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

### 4c. Failing test FIRST (TDD — mandatory, before any fix)

Write the regression test **before** touching the fix. Dispatch the project's test specialist (or write inline if none) with the diagnosed root cause + a spec for a test that REPRODUCES the bug:

```
@bug-investigator named the root cause; now write a test that fails BECAUSE of it.
```

Requirements:
- The test currently **FAILS** — and fails for the diagnosed reason, proving it catches *this* bug (not some unrelated assertion).
- **Deterministic** — no `sleep`, seeded randomness, real clock; fake time / fixed seeds only.
- **Right level** — unit for pure logic; integration for DB; e2e for HTTP; widget/render test for UI.

**Do not proceed to the fix until the test reliably fails.** A fix written before a failing test is a hypothesis, not a verified repair — this ordering is the whole point of the command.

### 4d. Fix (minimal)

The fix should be:
- **Minimal** — change only what makes the failing test pass.
- **Targeted** — at the root cause, not a workaround.
- **Reversible** — safe to revert if the fix has unintended consequences.
- **Anchored** to existing conventions (don't introduce new patterns to fix one bug).

If the fix requires a new pattern → flag for ADR before merging.

### 4e. Verify

Three layers of verification:
1. **The failing test from 4c now passes.** (Same test, flipped red → green by the fix.)
2. **The regression test generalizes** beyond the exact reproducer to the whole bug class — broaden it if it only pins the single reported input.
3. **No new regressions in surrounding tests.** Run the full test suite; no new lint / type errors.

For UI bugs: visual verification (screenshot or video).
For mobile bugs: verify on iOS + Android.
For backend bugs: verify with production-shaped data.

Dispatch reviewers:
- `@code-reviewer` — fix quality + convention adherence.
- `@test-reviewer` — does the regression test genuinely catch the bug class, not just the one input?
- `@bug-investigator` — verify the diagnosis was correct.
- `@security-auditor` if the bug class touches auth / tenant / data integrity.

## Phase 5 — Update

- `ai/failures/<NNNN>-<slug>.md` — append-only failure entry. Captures: what we tried, why it failed (if previous attempts), root cause, what we did, don't-retry conditions.
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
- ai/failures/<file> — root cause documented
- ai/dynamic/changelog.md — entry added
- ADR <NNNN> (if applicable)

Open follow-ups:
- <thing flagged>
```

## Hard rules

- **Reproduce first, failing test second, fix third.** A fix without a reproducer is a hypothesis; a fix without a *failing* test is unverified.
- **Failing test BEFORE fix. Always.** The test must fail for the diagnosed reason before a single line of the fix is written (matches the backend pack sibling and the canonical Phase-4-=-TDD rule).
- **Root cause, not symptom.** Don't paper over with try/catch + log.
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
- `ai/failures/_index.md` — read first **if present**; the bug class may already be cataloged. Absent on projects without a failure catalog — skip silently, don't fabricate the path.
