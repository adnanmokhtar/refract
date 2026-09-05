---
description: "Expose flaky tests by re-running the suite N times (N chosen for the flake rate you need to detect, not a fixed 5), root-cause each one, fix the non-determinism, and close with a stated confidence bound rather than the word \"stable\". Never masks with retries or .skip. Anti-triggers: authoring new tests is `/add-test`; a genuinely failing test is `/fix-bug`; running the suite once is `/run-tests`."
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /flaky-test-hunt [pattern]

## The Premise (read this first, internalize, do not deviate)

**Flake is real. The pattern almost always repeats — same async race / same shared state / same timing dependency.** A test that forgets to await an async call is one of N tests in the suite that forgot to await something. A test that depends on the system clock without using the project's fake-clock primitive is one of N tests with the same naked clock. A test that leaks DB rows into the next test is one of N tests sharing the same fixture without isolation. The hunt's job is to find ONE concrete root cause with measurement (an N-run pass/fail diff, N chosen for the flake rate that matters — see below), then **scan for the same shape across the rest of the suite** before declaring done.

**The agent's job is exactly this:**
1. **Choose N from the flake rate you need to detect** (see below), then run the suite N times serially, with `--shuffle` if supported, capturing pass/fail per test.
2. For each flaky test, identify the canonical cause (time / randomness / async race / shared state / order-dependence / external I/O).
3. **Scan for the same pattern.** `grep` for unawaited promises, naked `Date.now()`, unisolated DB writes, real-network calls. Count occurrences. Report N — not 1.
4. Fix root causes (never `retryTimes` / `retries: 2` masking) and re-run — then report **the bound the re-run actually establishes**, not the word "stable".

**Choosing N — and what 0 failures in N runs is allowed to mean.**

A test that fails with probability `p` survives `N` runs with probability `(1 − p)^N`. So a green sweep is evidence *only* in proportion to N, and the default this command used to ship — five runs — is much weaker than it reads:

| Flake rate | Chance all 5 runs pass (i.e. you see nothing) | Runs needed to see it with ~95% confidence |
|---|---|---|
| 50% | 3% | 5 |
| 20% | 33% | 14 |
| 10% | 59% | 29 |
| 5% | 77% | 59 |
| 1% | 95% | 299 |

(`(1−p)^N`, and `N ≥ ln(0.05) / ln(1−p)`.)

Read the middle column again on the 1% row: **five runs miss a 1%-flaky test 95 times out of 100** — and this command's own "Does NOT" list refuses to accept "passes 99% of the time" as good enough. The detection budget has to match the standard, or the standard is decorative.

Symmetrically, for the verification re-run: zero failures in N runs bounds the flake rate at roughly **3/N** with 95% confidence — the statistical *rule of three* (https://en.wikipedia.org/wiki/Rule_of_three_(statistics)). So:

- **0/5 green → the flake rate could still be as high as 60%.** This is not "stable". It is "not obviously broken".
- 0/30 green → under ~10%.
- 0/100 green → under ~3%.

**The rule:** pick N from the rate that would actually hurt this suite, and *report the bound rather than the adjective*. `Re-run: 0/50 — flake rate < 6% (95% CI)` is a measurement. `Re-run: 0/5. Stable.` is a claim five runs cannot support.

**Defaults, since a number is needed to start:**
- **Detection sweep: N = 20**, shuffled — catches most of what a CI pipeline is already tripping over, at a cost most suites can pay. Raise it when CI shows a red rate the sweep is not reproducing (if CI fails 1 in 40 and 20 local runs are clean, the sweep is under-powered, *not* the test fixed).
- **Verification after a fix: N ≥ 30**, and more when the test guards money, auth, or tenant isolation. Where the suite is too slow for that, run the *fixed test file alone* at high N rather than dropping N for the whole suite — and say which you did.
- **Fixes that remove the source of non-determinism entirely** (a frozen clock replacing a real one, a seeded RNG, an added `await`) are argued from the *mechanism*, not the sample: the flake rate is zero because the race no longer exists. Say that, and N is a sanity check rather than the evidence. This is the strongest close available and should be preferred over any number of green runs.

**The agent does NOT:**
- Add the project's runner-level retry primitive (`jest.retryTimes(3)` / Playwright `retries: 2` / `pytest --reruns` / `--retry` / framework-equivalent). Masking ≠ fixing. Forbidden.
- Mark a test `.skip` "for now". Avoidance ≠ fix. Forbidden.
- Stop at the one flaky test that's currently failing. The pattern almost certainly exists in 3-10 more tests that flake at lower frequency.
- Accept "passes 99% of the time" as good enough. Non-zero flake = broken — and note that detecting a 1% flake takes ~300 runs, so a short green sweep is not evidence against one.

**Closure verbs (mandatory per flaky test):**
- `fix-root-cause` — root cause identified + deterministic rewrite applied + verification closed (either the mechanism argument, or `0/N` with its `< 3/N` bound stated); sibling-occurrence count cited.
- `fix-isolation` — root cause is shared state / order-dependence; fixture isolation applied (per-test transaction, fresh container, env reset) + verification closed the same way, plus the isolation proof (the test now passes run alone AND reordered).
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
- Plan: N serial runs (default 20; justify any lower N against the rate table in the Premise) → diff pass/fail → for each flaky test, identify root cause → fix → N ≥ 30 verification runs, or a mechanism argument that the race no longer exists.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Test-specific:
- Test config + setup files (singleton resets, env mutations, DB cleanup).
- CI config (`--maxWorkers`, parallel shards) — replicate locally for the hunt.
- 1-2 sibling tests that are stable — compare patterns.

## Phase 4 — Generate (the hunt + the fix)
- Run the suite N times serially (N per Phase 2; 20 by default) with shuffle/randomization if the runner supports it, capturing machine-readable output. **The capture flags are runner-specific — `--reporter json` is a JS-runner idiom; pytest / go / cargo use different flags (or none).** Pick the row for the detected runner:

  | Runner | Capture + shuffle invocation (per run) |
  |---|---|
  | jest | `jest --reporters=jest-junit --outputFile=run-$i.xml` (or `--json --outputFile=run-$i.json`); shuffle via `--shuffle` |
  | vitest | `vitest run --reporter=json --outputFile=run-$i.json`; shuffle via `--sequence.shuffle` |
  | mocha | `mocha --reporter json > run-$i.json`. No shuffle flag is used here — order randomisation in mocha comes from a plugin; without one, order dependence is `NOT TESTED` |
  | playwright | `playwright test --reporter=json > run-$i.json`. The CLI ships **no order-randomisation flag** (https://playwright.dev/docs/test-cli); worker/shard interleaving varies but within-file order does not, so order dependence is `NOT TESTED` |
  | pytest | `pytest --junitxml=run-$i.xml` (or `--json-report --json-report-file=run-$i.json` via `pytest-json-report`). pytest has **no built-in shuffle**; with [`pytest-randomly`](https://pypi.org/project/pytest-randomly/) installed it auto-loads and reshuffles with a fresh seed each run, so the plain command above already varies order — add `--randomly-seed=$i` to make each run reproducible. **Never `-p no:randomly` here: that switches the shuffling off.** |
  | go test | `go test -count=1 -shuffle=on -json ./... > run-$i.json`. `-shuffle` is built in from Go 1.17 (https://go.dev/doc/go1.17); it randomizes order *within* a package, not across packages, so cross-package order dependence stays unexercised |
  | cargo test | `cargo test -- -Z unstable-options --format json --shuffle --test-threads=1 > run-$i.json`. Both `--format json` and `--shuffle` are unstable and require `-Z unstable-options` on nightly (https://doc.rust-lang.org/rustc/tests/index.html); `--shuffle-seed <n>` reproduces an order. On stable: parse plain output, order dependence `NOT TESTED` |

  Run the chosen invocation in a loop (N from the Premise's rate table — 20 by default):
  ```bash
  N=20; for i in $(seq 1 $N); do <runner-invocation-from-table-above> || true; done
  ```

  **Failure branch — no shuffle available.** Before looping, confirm the chosen invocation actually randomizes order (pytest without `pytest-randomly`, mocha without a shuffle plugin, `go test` below 1.17, and any sharded Playwright run all fail this). If it does not, the sweep still detects time / randomness / async-race / shared-state / external-I/O flakes, but **order dependence is never exercised and therefore cannot be ruled out**. Report that row as `Order dependence: NOT TESTED (no shuffle available for <runner>)` — never as absent, and never let it be rolled into a clean verdict. Installing the shuffle plugin is the fix; dropping the row is not.
- Diff pass/fail sets across runs (parse the JSON/JUnit artifacts; don't eyeball stdout). Tests that flip state ≥ 1× = flaky.
- For each flaky test, inspect canonical causes:
  - **Time** — `setTimeout` / `sleep` / language-equivalent timer / `Date.now()` (or language-equivalent) without freezing via the project's fake-clock primitive (`vi.useFakeTimers()` / `jest.useFakeTimers()` / `freezegun.freeze_time(...)` / `Timecop.freeze` / `Clock.fixed(...)` / framework-equivalent).
  - **Randomness** — RNG / UUID generators called without a fixed seed (`Math.random()` / `crypto.randomUUID()` / `random.random()` / `SecureRandom.uuid` / language-equivalent).
  - **Async race** — assertion not awaited, missing `await waitFor(...)`, promise resolved after test exit.
  - **Shared state** — DB rows from prior test, module-level singletons, env vars mutated.
  - **Order dependence** — re-run with the runner's shuffle enabled to confirm; if the runner has no shuffle, this cause is `NOT TESTED`, not excluded (see the failure branch above).
  - **External I/O** — real network, real filesystem, real clock — mock or sandbox.
- Propose deterministic rewrites: faked timers, seeded random, isolated DB transactions per test, explicit awaits.
- Re-run after the fix and **report the bound, not the adjective**: `0/<N> — flake rate < <3/N> (95% CI)`. A green re-run at N=5 bounds nothing useful; see the Premise. Where the fix removed the non-determinism outright, state the mechanism instead — that is stronger evidence than any sample.

## Phase 5 — Update
- `ai/dynamic/changelog.md` — one-line: `Fixed N flaky tests; root causes: <time|race|state|...>`.
- `ai/audits/<YYYYMMDD>-flaky-hunt.md` — record findings + root-cause categorization (helps spot systemic issues over time).
- **`ai/test-runs/<YYYY-MM-DD-HHMMSS>.log`, one entry per sweep run** — same format `/run-tests` Phase 5 writes (argv, exit code, scope, wall time, per-test pass/fail set). This sweep produces the richest per-test history the pack can generate — N runs of one scope — and `ai/test-runs/` is the only path `/run-tests` Phase 7 reads for its flake trigger. Writing the sweep *only* to `ai/audits/` strands it: `/run-tests` then reports `insufficient history` forever in exactly the projects that run this command. Same directory, same format, or the two commands keep separate ledgers of the same fact.
- `ai/dynamic/feedback-learned.md` — append rule if the same root cause keeps appearing.

## Phase 6 — Validate
- Verification runs: zero failures at the N chosen in Phase 2, and the resulting `< 3/N` bound stated in the report — or a mechanism argument that the source of non-determinism is gone.
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
## /flaky-test-hunt — <N> flaky → fixed, 0/<N> on re-run (flake rate < <3/N>, 95% CI)

Phase 1 (Understand): suite otherwise green; pattern = <arg|all>; N = 20 (detect ≥10% flake w/ ~88% confidence)
Phase 3 (Retrieved): runner = <name>; CI parallelism replicated
Phase 4 (Generated):
  Detected (3 of 245):
    orders.spec.<ext> > "creates order"   12/20 fails
      Cause: system clock used in seedOrder() not frozen
      Fix:   freeze via the project's fake-clock helper
    cart.spec.<ext> > "applies discount"  1/20 fails
      Cause: cart.refresh() not awaited
      Fix:   await the call (line 42)
  Re-run after fixes: 0/50.
    orders.spec — mechanism: the real clock is gone; the race cannot occur. N is a sanity check.
    cart.spec   — mechanism: the promise is awaited; no unordered completion remains.
    Sample bound, had the mechanism argument been unavailable: flake rate < 6% (95% CI).
Phase 5 (Updated): changelog, audits/, feedback-learned (if recurrence)
Phase 6 (Validated): 0/50 green + mechanism argument per fix; no retries added; no .skip
Phase 7 (Improved): lint rule + ADR queued

Status: ROOT-CAUSED — every fix carries a mechanism argument; N-run re-check green
  # OR
Status: SUPPRESSED-ONLY — <tests> still flake; cause not identified. Never reported as fixed.
  # OR
Status: PARTIAL — <n> root-caused, <m> outstanding (named)
```

## Failure modes
- Adding `jest.retryTimes(3)` / Playwright `retries: 2` → masking, not fixing; forbidden.
- "Passes locally, fails in CI" → almost always parallelism or shared DB state; replicate CI's `--maxWorkers` locally.
- 99%-pass test left as "good enough" → hides a real bug; treat any non-zero flake rate as broken.
- **"Re-ran it 5 times, it's stable"** → 5 green runs are consistent with a 60% flake rate. Report the bound (`< 3/N`), never the adjective.
- E2E with real browser networking → use the project's HTTP-faking primitive (`route.fulfill` / `nock` / `msw` / `WireMock` / `responses` / framework-equivalent) to remove network variance.
- Test depending on test order → bug in setup/teardown, not in test body.
- Same root cause in 5+ tests → systemic; escalate to lint rule rather than per-test fixes.

## Related

### Sibling commands in testing pack
- `/add-test` — authoring vs repair. That command writes tests that do not exist; this one repairs tests that exist and lie. A flaky test is not a coverage gap and must never be closed by writing another test on top of it.
- `/tdd` — test-first feature driver (red→green→refactor)
- `/run-tests` — the universal runner

### Patterns
- `ai/patterns/test-doubles.md`
- `ai/patterns/test-strategy.md`

### Rules
- `.claude/rules/testing-principles.md`
