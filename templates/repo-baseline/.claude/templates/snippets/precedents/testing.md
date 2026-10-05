# Precedents — testing (assertion strength, execution, determinism, doubles, risk coverage)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **testing** class: tests that cannot fail, tests that never run, CI and config that
mask failures, flake sources, test doubles that lie, seams in production code, and coverage that
misses a risk surface. The oracles that prove them are in
[`proof-oracles.md`](../proof-oracles.md) § Testing. The three cross-domain precedents (tests and
seeds, mechanisms the runtime does not have, numbers no tool produced) are in
`refute-before-report.md § 4`. The first one reads differently here: in this domain the tests
**are** the code under review. A test file is in scope; what is out of scope is a probe script,
a fixture builder or a helper that declares no test case.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening**; the flip evidence makes it a candidate again.
Numbers are stable: detectors cite `precedents/testing.md § <n>`.

## The claim, restated for a test

§ 1 of the protocol takes one of two shapes here. A candidate that fits neither is not a finding.

- **Strength and presence:** "If **[a concrete regression — this mutation or edit at file:line]**
  shipped, **[the tests that execute that line]** would still pass, because **[the missing
  oracle — nothing asserted on X / asserts the mock / never awaited / never collected / masked by
  CI]**, and **[the behaviour callers rely on]** would break unnoticed."
- **Determinism:** "Test **T** fails **k of N** runs under **[shuffle seed S / TZ / faked date /
  workers / alone vs in suite / offline]** because **[the non-deterministic source at
  file:line]**, which **[masks real failures through retries / blocks merges / hides a race]**."

The unit of a finding is a **behaviour**, not a test: a weak assertion in T is not a finding when
T′ pins the same behaviour.

## Reading the seven gates for a test

| Gate | Testing reading |
|---|---|
| 1 Reachability | The test is collected **and** a CI job for this branch runs it. If not, the finding is never-run (`suite-execution-scan` § 3), not a weak oracle. The production line it claims to cover is reachable from an entry point |
| 2 Trigger condition | The regression or perturbation really occurs: the SUT branch can break, the clock or order really varies in CI. **And every layer was searched for another pin** — unit, integration, e2e, contract, the type system — by test name *and* by assertion |
| 3 Engine + runtime version | The runner, plugin and language versions are read from the lockfile (§ 1–12 below change the verdict). Never from memory |
| 4 No existing control | No config already neutralises it: `forbidOnly`, `expect.hasAssertions()` in setup, `xfail_strict`, `--fail-on-risky`, a lint rule **at error level on test files in CI**, a diff-coverage or mutation gate, a flaky gate, a net-disconnect in setup, `restoreMocks` |
| 5 Real impact | A production defect of a named class would ship green, or CI fails with no cause. Never style |
| 6 Proof | The oracle from `proof-oracles.md § Testing` ran: the SUT broken and the test still green, the assertion flipped and still green, absent from the collected list, the canary not failing CI, k/N under a recorded perturbation. Execution beats reading; a self-proving committed flag (`.only`, `continue-on-error` on the test job) is a static fact |
| 7 Deployment and environment | The CI environment, not the laptop: `CI=true` changes runner defaults, the job's `TZ`, worker count, shards, the variables a gated suite needs. A shape CI does not have makes the candidate latent |

## Version precedents — read the installed major before reporting

1. **Vitest ≥ 5 fails an un-awaited `.resolves` / `.rejects` / `expect.poll`** — even one that would pass (Vitest 5.0.3, run 2026-10-05). On Vitest 5 the class is a red test, not a hidden one: Hardening. *Flips back:* Vitest ≤ 4 in the lockfile, where it is still silent.
2. **Jest 30 can pass an un-awaited failing `.resolves` with exit 0** — when another test file runs in the same invocation, or under `--forceExit` (Jest 30.5.2, run 2026-10-05). Run alone in one file it crashes after the summary with exit 1, so "it fails when I run that file" is not a refutation.
3. **pytest ≥ 8.4 fails an `async def` test that no plugin runs** (the old silent skip is gone; pytest 9.1.1, run 2026-10-05). "Async test never runs" is a finding only on an older pinned pytest. **`assert coro()` still passes** — a coroutine object is truthy — with only a `RuntimeWarning`; `-W error::RuntimeWarning` alone does not fail it, `-W error::pytest.PytestUnraisableExceptionWarning` does.
4. **pytest does not collect a `Test*` class that defines `__init__`** and says so only as a `PytestCollectionWarning`; `-W error::pytest.PytestCollectionWarning` makes it an error. A non-strict `xfail` that passes is `XPASS`, exit 0; `-o xfail_strict=true` makes it fail (pytest 9.1.1).
5. **CPython ≥ 3.12 rejects mock assertion typos** (`called_once_with`, `assret_*`) with `AttributeError` (verified on 3.14.6). `m.assert_called_once` without the call parentheses is still silent (Ruff `PGH005`), and `Mock(unsafe=True)` turns the guard off.
6. **PHPUnit 13.4 reports an assertion-free test as risky and still exits 0** — `beStrictAboutTestsThatDoNotTestAnything` is on, `failOnRisky` is off by default (`phpunit.xsd` 13.4.0). Only `--fail-on-risky` (or `failOnRisky="true"`) makes it block. PHPUnit 12+ no longer reads the docblock `@test` annotation (research: known, not re-fetched — confirm with `phpunit --list-tests`).
7. **A retry plugin passes a flake as green unless its flaky gate is on.** Maven Surefire 3.6.0 `failOnFlakeCount` defaults to 0, which allows unlimited flakes once `rerunFailingTestsCount` is set; Gradle test-retry 1.6.6 `failOnPassedAfterRetry` defaults to false; cargo-nextest counts `TRY n PASS` as a pass unless `--flaky-result fail`; Playwright 1.63 needs `--fail-on-flaky-tests` (all read 2026-10-05).
8. **Vitest ≥ 5 turns `clearMocks` on by default** (research catalog, verified). Clearing call records is not restoring an implementation; read `restoreMocks` / `mockReset` before clearing an unrestored-spy candidate.
9. **Lint lanes are WARN where it matters.** eslint-plugin-jest 29.16.6 `recommended` sets `expect-expect`, `no-disabled-tests` and `no-commented-out-tests` to warn; @vitest/eslint-plugin 1.6.27 sets `expect-expect` to error; eslint-plugin-mocha 12 sets `no-exclusive-tests` and `no-pending-tests` to warn. "The plugin is installed" is not gate 4 unless CI runs it with `--max-warnings 0` or the rules at error.
10. **Go.** Go ≥ 1.22 gives each loop iteration its own variable; a closure-capture flake on older Go is not one on 1.22+. Go ≥ 1.24 runs the vet `tests` analyzer inside `go test`, which rejects malformed `Testfoo` names (research: known, not run locally — confirm on the repo's toolchain).
11. **Playwright ≥ 1.56 test agents ship a healer that can mark a test skipped.** A skip whose commit came from a healer run is a candidate even with a reason string.
12. **The runner's own CI detection changes defaults** (snapshot writing, `allowOnly`, `forbidOnly` expressions keyed on `process.env.CI`). Read the effective config the CI job gets — `npx jest --showConfig` with the job's env, the config file's `process.env.CI` branches, the `pytest --co -q` header — before ruling on a default.

## Not a finding — assertion strength

13. **A guard followed by a value assertion.** `toBeDefined` / `assertNotNull` / `NotNil` before an assertion on the value is fine; report only the sole-oracle form.
14. **Existence is the behaviour.** A lookup that can miss, a factory that returns a handle, a DI container that resolves; a Testing Library `getBy*` / `findBy*` query, which throws when the element is absent, so `expect(getByText('Saved')).toBeTruthy()` pins presence of that text. *Flips back:* the test name claims a value, an order or a state the presence check does not pin.
15. **An exact empty value is an exact value.** `toBeUndefined()`, `toBeNull()`, `toEqual([])` and `assert x is None` pin one result; only the negated forms (`not.toBeNull`, `is not None`) are weak.
16. **An HTTP status is an oracle.** supertest `.expect(403)`, `.expect(201)`, a status assertion on a refusal test, is the behaviour (measured: 689 of 1,007 whole-suite `oracle-check.py` rows on a real NestJS monorepo were status lines). *Flips back:* a 2xx-only status on a read or list endpoint whose body is the behaviour, with no body assertion.
17. **`not.toThrow` as an acceptance test** paired with a rejection test of the same validator, and named smoke tests ("boots", "renders without crashing") in a suite with behavioural tests elsewhere. A smoke test that is the **only** test of a component is a Medium finding.
18. **The SUT on both sides on purpose.** Round-trip (`decode(encode(x))`), idempotence, determinism (`f(x)` equals `f(x)` across calls) and comparison against an *independent* reference implementation are invariants, not tautologies.
19. **Loops and branches that cannot be empty.** A table-driven loop over a literal case table (`test.each`, `t.Run` over cases, `parametrize`), or a loop preceded by a length assertion on the same collection.
20. **An interaction is the outcome when the side effect is the contract** — publish, send, audit, a call on a port the project owns — provided the arguments are pinned (`toHaveBeenCalledWith`), and `not.toHaveBeenCalled` pins "no side effect". *Flips back:* the SUT returns or persists a checkable value, or the assertion pins only a call count.
21. **A pass-through adapter's echo is its behaviour.** A wrapper whose job is to return the dependency's value may assert the mocked value back. *Flips back:* the SUT transforms the value on the way.
22. **Snapshots of small, deterministic, reviewed output** — CLI help, codegen, an AST, an error message — under about 50 lines (the `no-large-snapshots` default), and characterization snapshots taken before a refactor with scrubbers for ids and times. *Flips back:* the snapshot was rewritten in the same change as the behaviour, or it is the sole oracle of new logic.
23. **Assertions the language runtime keeps.** pytest rewrites `assert` in test modules (Ruff `S101` is a production-code rule); Java `assert` in tests runs when the runner enables `-ea`. Assert-based helpers outside test modules under `PYTHONOPTIMIZE` are the finding.
24. **Oracles in another form.** Property tests whose body is a generator plus a predicate; contract tests a provider verifies; type tests (`expectTypeOf` with Vitest `typecheck`); strict mocks verified at teardown (Mockito strict stubs, gomock `Finish`); custom helpers that assert — read the helper before calling a case assertion-free.

## Not a finding — execution

25. **A skip with a reason, a tracker link and a condition** (`skipIf(platform)`, `importorskip`, `test.todo`, a strict `xfail` with a reason) is intended. The finding is the skip with no owner and no expiry, or one whose condition is always true in CI.
26. **A capability-gated suite runs when the CI job provides the capability.** `runIf(existsSync('dist/…'))` after a build step, `runIf(browser available)` in a job that installs one, `//go:build integration` with a job passing `-tags integration`. Read the job before reporting.
27. **A suite kept out of the pull-request gate on purpose** — fuzz, load, long e2e — is fine when a scheduled or manual workflow runs it and someone owns its result. *Flips back:* no workflow names it at all.
28. **`continue-on-error` on an advisory job** — a new lint rollout, a runtime canary, a coverage upload — with an owner and an end date. Never on the job that runs the required tests.
29. **Retries that are scoped, visible, owned, bounded and error-scoped**: a per-test marker or quarantine tag (or an e2e suite against real browsers), a flaky gate or dashboard on, an owner and a ticket, at most 2 retries with an expiry, and a retry condition where the tool has one. Playwright's scaffold `retries: process.env.CI ? 2 : 0` is a precedent unless flaky results go unreported. `@RepeatedTest`, `--repeat-each` and `--count` are oracles, never findings.
30. **`--forceExit` with a cited upstream reason and no floating assertion in that suite** (`assertion-strength-scan` § 3 clean on it) is Hardening. *Flips back:* any un-awaited assertion in a Jest suite run with `--forceExit` (§ 2).
31. **Coverage exclusions with a reason:** generated code, platform-specific code, `if __name__ == "__main__":`, defensive unreachable branches. A threshold raised (Vitest `thresholds.autoUpdate`) or moved to stricter per-file values is not lowering. **No declared floor** is the QG-9 pre-existing line, not a finding.
32. **Not tests by design:** abstract base test classes, helpers (a Go `testXxx` that calls `t.Helper()`, PHP public non-test methods with parameters), fixture directories, setup files in a test directory that declare no case. A test-directory file with no case declaration is never "assertion-free".
33. **Declared ordering is intended:** `@Order`, `describe.serial`, pytest-order, `@depends`. Note it; do not shuffle-test it.

## Not a finding — determinism, doubles and coverage

34. **Sleep under virtual time** (fake timers, `synctest`, `runTest`, tokio `start_paused`), a yield (`sleep(0)`), a bounded poll helper with a deadline, or a sleep that *is* the behaviour under test with slack on the safe side.
35. **Clock reads for durations and timeouts**, and wall-clock e2e against a real database with explicit margins (QG-6 allows it).
36. **Randomness that is seeded**, opaque ids never asserted, and property-based frameworks that print and persist the seed. pytest-randomly reseeds `random` and Faker per test, which hides an unseeded-faker defect within one seed — vary the seed before clearing it.
37. **Shared fixtures that are immutable** — servers, browsers, pools, containers, read-only reference data, Django `setUpTestData`.
38. **Real network in a tagged e2e or contract suite** outside the unit gate, on loopback, against Testcontainers, or to reserved domains.
39. **Mocks of collaborators are the point of a unit test**; mocking the SUT is the defect. A partial mock that keeps the real export under test (`requireActual` plus one stubbed collaborator) is fine.
40. **Engines.** Testcontainers on the production major is the real engine; PGlite is real Postgres SQL semantics but not locking or concurrency; SQLite in tests is fine when production is SQLite. A monorepo whose frontend compiles a generated client in the same CI has its contract.
41. **Mutation.** Equivalent mutants are dismissed with a stated reason and leave the denominator; logging and telemetry lines are arid unless they are an audit contract; CompileError, Unviable and type-check-killed mutants are not survivors; NoCoverage mutants belong to coverage, not mutation. Do not demand mutation testing for test-only, docs-only, generated-only or rename-only changes, or where no tool or licence exists (`blocked (licence)`). *Not a refutation either way:* **a lane's exit code is not its verdict** — gremlins 0.6.0 run with `--threshold-efficacy 80` at 50% efficacy still exited 0, so read `test_efficacy` in its JSON; and **`npx stryker` without a local `@stryker-mutator/core` fetches the abandoned `stryker` 0.x package**, so a run from it that "found no survivors" is no run (both run 2026-10-05; `mutation-probe` § Adapt to the codebase).
42. **Flakiness the SUT causes means the test is right.** A real production race exposed by a test is a production bug; never "fix" the test with a wait, a retry or a skip.
43. **Style smells are never findings** — Assertion Roulette, Magic Number, Eager or Lazy Test, naming. Many classic smells are common and uncorrelated with real flaws (Panichella et al., EMSE 2022); the defect-relevant ones (empty or unknown test, redundant assertion, conditional test logic, exception handling in tests, ignored test, sleepy test, resource optimism) each map to a class with an oracle.

## Rationalizations to reject (testing)

**Wrongly accepting:** "coverage is low, so the tests are weak" · "it is in the smell catalog" ·
"it uses a mock" · "snapshots are bad" · "an LLM would test more edge cases" (with no regression
named) · "a linter flagged it" · "`oracle-check.py` flagged it" (a candidate generator, § 16).

**Wrongly dismissing:** "it is green in CI" · "coverage is 100%" (executed is not checked) · "it
only flakes 1%" (detection needs about 300 runs at 95%) · "the retry handles it" · "the e2e test
covers it" (name it, and show its assertion) · "the linter is installed" (at error level, on test
files, in CI?) · "it fails when I run the file alone" (§ 2) · "the job is green" (read the log for
failed tests under a masked exit).

---

Sources (2026-10-05 unless dated): the Track A testing research catalog and its notes — local runs
of Jest 30.5.2, Vitest 5.0.3, pytest 9.1.1 with pytest-asyncio 1.4.0, and CPython 3.14.6; the
published tarballs of eslint-plugin-jest 29.16.6, @vitest/eslint-plugin 1.6.27 and
eslint-plugin-mocha 12.0.2; PHPUnit 13.4.0 `phpunit.xsd` and CLI builder; Maven Surefire 3.6.0
`SurefireMojo` (`failOnFlakeCount`); Gradle test-retry 1.6.6 README; cargo-nextest 0.9.146 docs;
Playwright 1.63.0 CLI docs and the 1.56.0 test-agents release; Panichella et al., *Test smells 20
years later* (EMSE 27(7), 2022); Palomba and Zaidman, *The smell of fear* (EMSE 2019). The real-repo
count in § 16 is a 2026-10-05 read-only measurement. Paraphrased; no text reproduced.
