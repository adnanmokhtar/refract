---
description: Identify flaky tests by running suite N times, then root-cause and fix non-determinism.
---

# /flaky-test-hunt [pattern]

## The Premise (read this first, internalize, do not deviate)

**Flake is real. The pattern almost always repeats — same async race / same shared state / same timing dependency.** A test that forgets to await an async call is one of N tests in the suite that forgot to await something. A test that depends on the system clock without using the project's fake-clock primitive is one of N tests with the same naked clock. A test that leaks DB rows into the next test is one of N tests sharing the same fixture without isolation. The hunt's job is to find ONE concrete root cause with measurement (5-run pass/fail diff), then **scan for the same shape across the rest of the suite** before declaring done.

**The agent's job is exactly this:**
1. Run the suite N=5 times serially, with `--shuffle` if supported, capturing pass/fail per test.
2. For each flaky test, identify the canonical cause (time / randomness / async race / shared state / order-dependence / external I/O).
3. **Scan for the same pattern.** `grep` for unawaited promises, naked `Date.now()`, unisolated DB writes, real-network calls. Count occurrences. Report N — not 1.
4. Fix root causes (never `retryTimes` / `retries: 2` masking) and re-run 5×. Must hit 0/5.

**The agent does NOT:**
- Add the project's runner-level retry primitive (`jest.retryTimes(3)` / Playwright `retries: 2` / `pytest --reruns` / `--retry` / framework-equivalent). Masking ≠ fixing. Forbidden.
- Mark a test `.skip` "for now". Avoidance ≠ fix. Forbidden.
- Stop at the one flaky test that's currently failing. The pattern almost certainly exists in 3-10 more tests that flake at lower frequency.
- Accept "passes 99% of the time" as good enough. Non-zero flake = broken.

**Closure verbs (mandatory per flaky test):**
- `fix-root-cause` — root cause identified + deterministic rewrite applied + 5/5 verification green; sibling-occurrence count cited.
- `fix-isolation` — root cause is shared state / order-dependence; fixture isolation applied (per-test transaction, fresh container, env reset) + 5/5 green.
- `escalate-systemic` — root cause recurs in 5+ tests; per-test fix is not the right closure; surfaced as lint-rule / ADR / shared-fixture proposal in `Phase 7`.
- `flag-external` — flake traced to a real external dependency (third-party API, real network, real clock); fix is to introduce mock boundary; cite `<file:line>` of the boundary added.

**Mechanical halt (similar-pattern scan accounting):**

Before declaring the hunt done, the agent MUST resolve this equation for every root-cause class:

```
N_found  ==  N_fixed  +  N_explained  +  N_followup
```

- `N_found` — every test where the root-cause pattern (unawaited promise / naked clock / shared singleton / real network / order-dependent fixture) appears.
- `N_fixed` — tests the hunt's deterministic rewrites cover.
- `N_explained` — tests legitimately exempt (e.g., test of the timer itself, test of the real-network adapter behind a tag).
- `N_followup` — tests parked to a follow-up ticket with rationale (e.g., systemic class escalated to lint-rule).

If the equation does not balance, HALT and re-scan. **Hand-wave assertion ("probably the same elsewhere") is forbidden** — every count is an actual occurrence list with file paths.

**Lightweight default:** if exactly 1 test is flaky and the pattern doesn't repeat (`N_found == 1`), close with `fix-root-cause` and skip the systemic-escalation step. Don't propose a lint rule for a one-off. Conversely, if `N_found ≥ 5` for the same root cause, default closure is `escalate-systemic` — per-test fixes don't scale.

Fix command (specialized — fix non-determinism, not features). Runs the suite repeatedly to expose flakiness, then fixes root causes (no retry-loop masking). All 7 phases apply.

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
  - **Time** — `setTimeout` / `sleep` / language-equivalent timer / `Date.now()` (or language-equivalent) without freezing via the project's fake-clock primitive (`vi.useFakeTimers()` / `jest.useFakeTimers()` / `freezegun.freeze_time(...)` / `Timecop.freeze` / `Clock.fixed(...)` / framework-equivalent).
  - **Randomness** — RNG / UUID generators called without a fixed seed (`Math.random()` / `crypto.randomUUID()` / `random.random()` / `SecureRandom.uuid` / language-equivalent).
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
- If same root-cause recurs (e.g. multiple tests forget to await) → queue a lint / static-analysis rule from the project's tooling (`eslint-plugin-jest/expect-expect`, `no-floating-promises`, `pylint async-no-await`, `RuboCop` rule, framework-equivalent).
- If shared DB state recurs → queue ADR: per-test transactional fixture.
- If real-network usage caused flakiness → queue rule update: ban real HTTP in unit tests.

## Output format
```
## /flaky-test-hunt — <N> flaky → fixed, 0/5 on re-run

Phase 1 (Understand): suite otherwise green; pattern = <arg|all>
Phase 3 (Retrieved): runner = <name>; CI parallelism replicated
Phase 4 (Generated):
  Detected (3 of 245):
    orders.spec.<ext> > "creates order"   3/5 fails
      Cause: system clock used in seedOrder() not frozen
      Fix:   freeze via the project's fake-clock helper
    cart.spec.<ext> > "applies discount"  1/5 fails
      Cause: cart.refresh() not awaited
      Fix:   await the call (line 42)
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
- E2E with real browser networking → use the project's HTTP-faking primitive (`route.fulfill` / `nock` / `msw` / `WireMock` / `responses` / framework-equivalent) to remove network variance.
- Test depending on test order → bug in setup/teardown, not in test body.
- Same root cause in 5+ tests → systemic; escalate to lint rule rather than per-test fixes.

## Related

### Sibling commands in testing pack
- `/add-test` — sibling command in testing pack

### Patterns
- `ai/patterns/test-doubles.md`
- `ai/patterns/test-strategy.md`

### Rules
- `.claude/rules/testing-principles.md`
