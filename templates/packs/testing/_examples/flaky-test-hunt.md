---
description: Identify flaky tests by running suite N times, then root-cause and fix non-determinism.
---

# /flaky-test-hunt [pattern]

Fix command (specialized — fix non-determinism, not features). Runs the suite repeatedly to expose flakiness, then fixes root causes (no retry-loop masking). All 7 phases apply.

## The Premise (read this first, internalize, do not deviate)

**Flake is real, and the pattern almost always repeats** — same async race, same shared state, same timing dependency. A test that forgets to await an async call is one of N tests that forgot to await something. The hunt's job is to find ONE concrete root cause with measurement (a 5-run pass/fail diff), then **scan for the same shape across the rest of the suite** before declaring done.

**The agent's job is exactly this:** run the suite 5 times serially, with shuffling if the runner supports it, capturing pass/fail per test; for each flaky test identify the canonical cause (time / randomness / async race / shared state / order-dependence / external I/O); **scan for the same pattern** across the suite and report the occurrence count, not 1; fix root causes and re-run 5× — it must hit 0/5.

**The agent does NOT:** add the runner's retry primitive (masking ≠ fixing — forbidden); mark a test `.skip` "for now" (avoidance ≠ fix — forbidden); stop at the one test that is currently failing; or accept "passes 99% of the time". Non-zero flake = broken.

**Closure verbs (mandatory per flaky test):** `fix-root-cause` (deterministic rewrite + 5/5 green + sibling-occurrence count cited), `fix-isolation` (shared state / order-dependence — fixture isolation applied + 5/5 green), `escalate-systemic` (the cause recurs in 5+ tests, so the closure is a lint rule / ADR / shared-fixture proposal), `flag-external` (flake traced to a real external dependency; the fix is a mock boundary, cited at `<file:line>`).

**Mechanical halt (similar-pattern scan accounting).** Before declaring the hunt done, this equation must balance for every root-cause class: `N_found == N_fixed + N_explained + N_followup`, where `N_found` is every test where the pattern appears, `N_explained` is the legitimately exempt (a test of the timer itself), and `N_followup` is parked with a rationale. If it does not balance, HALT and re-scan. **Hand-wave assertion ("probably the same elsewhere") is forbidden** — every count is an actual occurrence list with file paths.

**Lightweight default:** if exactly 1 test is flaky and the pattern does not repeat, close with `fix-root-cause` and skip the systemic escalation. If `N_found ≥ 5` for the same cause, default closure is `escalate-systemic` — per-test fixes don't scale.

## When to use / NOT to use
- USE: CI failures correlate weakly with code changes (intermittent reds).
- USE: new test passes once locally but fails in CI.
- USE: pre-merge sanity if a flaky test almost slipped past review.
- NOT: immediately after a real bug fix — wait until suite is otherwise green; otherwise can't tell signal from noise.
- NOT: for tests known to depend on real external services that are temporarily down — fix the test isolation first.

## Phase 1 — Understand
- Pattern arg (optional) → scopes which tests to re-run.
- Confirm: suite is otherwise green; flakiness is the only variable.

## Phase 2 — Organize
- Detect runner (`jest`, `vitest`, `pytest`, `go test`, `mocha`, `playwright`).
- Plan: 5 serial runs → diff pass/fail → for each flaky test, identify root cause → fix → 5 verification runs (must hit 0/5).

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Test-specific:
- Test config + setup files (singleton resets, env mutations, DB cleanup).
- CI config (`--maxWorkers`, parallel shards) — replicate locally for the hunt.
- 1-2 sibling tests that are stable — compare patterns.

## Phase 4 — Generate (the hunt + the fix)
- Run suite 5 times serially with `--shuffle` if supported:
  ```bash
  for i in 1 2 3 4 5; do <runner> --reporter json > run-$i.json || true; done
  ```
- Diff pass/fail sets across runs. Tests that flip state ≥ 1× = flaky.
- For each flaky test, inspect canonical causes:
  - **Time** — `setTimeout`, `sleep`, `Date.now()` without freezing (`vi.useFakeTimers()` / `jest.useFakeTimers()`).
  - **Randomness** — `Math.random()`, `crypto.randomUUID()` without a fixed seed.
  - **Async race** — assertion not awaited, missing `await waitFor(...)`, promise resolved after test exit.
  - **Shared state** — DB rows from prior test, module-level singletons, env vars mutated.
  - **Order dependence** — re-run with `--shuffle` to confirm.
  - **External I/O** — real network, real filesystem, real clock — mock or sandbox.
- Propose deterministic rewrites: faked timers, seeded random, isolated DB transactions per test, explicit awaits.
- Re-run 5 times after fix. **Flakiness rate must hit 0/5.**

## Phase 5 — Update
- `ai/dynamic/changelog.md` — one-line: `Fixed N flaky tests; root causes: <time|race|state|...>`.
- `ai/audits/<YYYYMMDD>-flaky-hunt.md` — record findings + root-cause categorization (helps spot systemic issues over time).
- `ai/dynamic/feedback-learned.md` — append rule if the same root cause keeps appearing.

## Phase 6 — Validate
- 5/5 verification runs pass for every fixed test.
- No `jest.retryTimes` / Playwright `retries: 2` added — masking is forbidden.
- No `.skip` left to "fix later" — that's avoidance, not fix.
- CI parallelism replicated locally (`--maxWorkers` matches CI).

## Phase 7 — Improve
- `/learn-from-task` — capture root-cause categorization.
- If same root-cause recurs (e.g. multiple tests forget `await`) → queue lint rule: `eslint-plugin-jest/expect-expect`, `no-floating-promises`.
- If shared DB state recurs → queue ADR: per-test transactional fixture.
- If real-network usage caused flakiness → queue rule update: ban real HTTP in unit tests.

## Output format
```
## /flaky-test-hunt — <N> flaky → fixed, 0/5 on re-run

Phase 1 (Understand): suite otherwise green; pattern = <arg|all>
Phase 3 (Retrieved): runner = <name>; CI parallelism replicated
Phase 4 (Generated):
  Detected (3 of 245):
    orders.spec.ts > "creates order"   3/5 fails
      Cause: Date.now() in seedOrder() not frozen
      Fix:   vi.setSystemTime(new Date('2026-01-01'))
    cart.spec.ts > "applies discount"  1/5 fails
      Cause: cart.refresh() not awaited
      Fix:   await cart.refresh() (line 42)
  Re-run after fixes: 0/5 fails. Stable.
Phase 5 (Updated): changelog, audits/, feedback-learned (if recurrence)
Phase 6 (Validated): 5/5 green; no retries added; no .skip
Phase 7 (Improved): lint rule + ADR queued

Status: COMPLETE
```

## Failure modes
- Adding `jest.retryTimes(3)` / Playwright `retries: 2` → masking, not fixing; forbidden.
- "Passes locally, fails in CI" → almost always parallelism or shared DB state; replicate CI's `--maxWorkers` locally.
- 99%-pass test left as "good enough" → hides a real bug; treat any non-zero flake rate as broken.
- E2E with real browser networking → use `route.fulfill` / `nock` / `msw` to remove network variance.
- Test depending on test order → bug in setup/teardown, not in test body.
- Same root cause in 5+ tests → systemic; escalate to lint rule rather than per-test fixes.
