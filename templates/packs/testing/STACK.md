# Testing pack — stack assumption

This pack's rules, agents, skills, and patterns assume:

- **A unit-test runner** with fake-timers + spy/mocks (Jest / Vitest / pytest / JUnit / Go testing / RSpec)
- **A mocking layer** — at port boundaries only (HTTP, DB driver, message bus)
- **An integration-test boundary** — real DB via Testcontainers / Docker Compose / sqlite
- **A property-based testing tool** for invariants (`fast-check` / `hypothesis` / `Hypothesis` / `quickcheck`)
- **Coverage tooling** with a ratcheted floor wired to CI (c8 / Istanbul / JaCoCo / coverage.py), and `diff-cover` for changed lines
- **Mutation testing** on changed lines and critical modules (StrykerJS / Stryker.NET / mutmut / PIT / gremlins / cargo-mutants / Infection)
- **Test lint rules at error in CI** — or run with `--max-warnings 0` (§ The lane table)

## Inline examples in this pack

Wherever this pack's files show concrete test syntax, examples use one stack (a JS-family runner + TypeScript) for readability — they are illustrative, not canonical. The principles apply across language families. Substitute per stack:

| Vitest / Jest + TS (illustrated) | pytest (Python) | JUnit / Spring (Java) | Go testing | RSpec (Ruby) | Substitution source |
|---|---|---|---|---|---|
| `describe` / `it` | `class TestX:` / `def test_x` | `@Test` methods | `func TestX(t *testing.T)` | `describe` / `it` | suite + case |
| `expect(x).toBe(y)` | `assert x == y` | `assertEquals(y, x)` | `if x != y { t.Fatalf(...) }` | `expect(x).to eq(y)` | assertion |
| `vi.useFakeTimers({ now: ... })` | `freezegun.freeze_time(...)` | `Clock.fixed(...)` | `clockwork` / DI clock | `Timecop.freeze` | fake clock |
| `vi.fn()` / `jest.fn()` | `MagicMock()` / `monkeypatch` | `Mockito.mock(...)` | gomock / testify mock | `instance_double` | mock primitive |
| `msw` / `nock` | `responses` / `httpx_mock` | WireMock | `httptest.NewServer` | `WebMock` | HTTP-call faking |
| `fast-check` `fc.property` | `hypothesis @given` | jqwik | `pgregory.net/rapid` | `rantly` | property-based tests |
| Testcontainers (Node) | testcontainers-python | Testcontainers (JVM) | `dockertest` | testcontainers-ruby | real-DB integration |
| StrykerJS | mutmut | PIT | gremlins / go-mutesting | mutant | mutation testing |

## The lane table — what catches each class, per stack

The detector skills carry the facts that change a verdict; this table says which lane each stack has, so a project can see what it is missing before an audit runs. Versions were read on 2026-10-05 (research catalog, registry or local run); confirm against the lockfile, never from memory.

| Stack | Test lint lane (run on test files, in CI) | Runtime guards — strictness, order, leaks | Mutation (diff-scoped) | Changed-line coverage |
|---|---|---|---|---|
| Jest 30 | eslint-plugin-jest 29.16.6: `expect-expect`, `no-disabled-tests`, `no-commented-out-tests` are **warn** in `recommended` → `--max-warnings 0` or set them to error; `valid-expect`, `no-conditional-expect`, `no-standalone-expect`, `no-focused-tests`; opt-in `no-restricted-matchers`, `no-large-snapshots` | `--ci` (a missing snapshot fails), `--randomize --seed=N` (within a file only), `--detectOpenHandles`, never `--forceExit`; `restoreMocks: true` | StrykerJS 10.0.0 `--mutate <file:L-L>` (no `--since`) | `--coverage` + `diff-cover` 10.6.0 |
| Vitest 4 / 5 | @vitest/eslint-plugin 1.6.27: `expect-expect` is **error** in `recommended`; `require-awaited-expect-poll` is opt-in | `allowOnly` (default `!process.env.CI`), `--sequence.shuffle --sequence.seed=N`; Vitest 5 fails an un-awaited `.resolves` and turns `clearMocks` on | StrykerJS | `@vitest/coverage-v8` (lcov is not a default reporter) |
| Mocha | eslint-plugin-mocha 12.0.2: `no-exclusive-tests`, `no-pending-tests` **warn**; `no-nested-tests` | `--forbid-only --forbid-pending`; no built-in shuffle | StrykerJS | c8 12.0.0 |
| Playwright 1.63 | eslint-plugin-playwright 2.12.0 (`expect-expect`, `missing-playwright-await`, `no-wait-for-timeout`) | `forbidOnly: !!process.env.CI`, `--fail-on-flaky-tests`; no order flag | — | — |
| TypeScript, any runner | `@typescript-eslint/no-floating-promises` 8.71.0 on test globs (un-awaited `expect(…).resolves`, `expect.poll`, Playwright `expect`; `void` silences it) | — | — | — |
| pytest 9 | ruff 0.16.10: `PT011`, `PT012`, `PT015`, `PT017`, `PT018`, `B011`, `B015`, `B017`, `B018`, `F631`, `PGH005`, `RUF006` | `-o xfail_strict=true`, `-W error::pytest.PytestUnraisableExceptionWarning`, `-W error::pytest.PytestCollectionWarning`, pytest-randomly 5.0.0, pytest-socket 0.8.1 `--disable-socket` | mutmut 3.8.0 (`[tool.mutmut]`; `--paths-to-mutate` is gone), cosmic-ray 8.7.0 | pytest-cov 7.1.0 `--cov-branch` + `diff-cover` |
| Go | golangci-lint 2.14.0 with `testifylint`, `thelper`, `tparallel`, `usetesting` | `-shuffle=on` (within a package), `-count=1`, `-race`, goleak v1.3.0 | gremlins 0.6.0 `--diff` (gate on the JSON, not the exit code), go-mutesting 2.3.1 | `-coverprofile` (no branch coverage) |
| JVM | error-prone 2.50.0 (`JUnit4TestNotRun`, `MissingFail`, `AssertionFailureIgnored`); PMD 7.28.0 (`UnitTestShouldIncludeAssert`, `WrongTestAnnotation`) | JUnit `MethodOrderer$Random` + seed; Surefire `failOnFlakeCount` (default 0 allows unlimited flakes once reruns are on) | PIT 1.30.0 (`scmMutationCoverage` removed in 1.18.0) | JaCoCo 0.8.15 + `diff-cover` |
| Ruby | rubocop-rspec 3.10.2 (`RSpec/NoExpectationExample`, `Focus`, `PendingWithoutReason`) | `--order rand:N`, `--seed N --bisect` | mutant 0.16.2 (commercial licence for private code) | SimpleCov 1.3.2 + undercover |
| PHP | phpstan-phpunit 2.0.21 | PHPUnit 13.4 reports an assertion-free test as risky and exits 0: `--fail-on-risky`; `--order-by=random` | Infection 0.35.6 `--git-diff-lines` | — |
| .NET | xunit.analyzers 2.1.0, MSTest analyzers 4.4.1 (severity per id in `.editorconfig`) | no seeded shuffle switch known | Stryker.NET 5.0.0 `--since:<base>` | coverlet 10.1.0 |
| Rust | clippy (`should_panic_without_expect`, `assertions_on_constants`, `ignore_without_reason`) | `--shuffle` is nightly-only; nextest `--flaky-result fail` | cargo-mutants 27.1.0 `--in-diff` | cargo-llvm-cov 0.9.1 |

**The WARN trap.** A lane that runs a plugin's `recommended` set without `--max-warnings 0` reads clean while the rules that catch a test that cannot fail are firing (eslint-plugin-jest and eslint-plugin-mocha above). An installed plugin is a control only when CI runs it on the test files at error level (`templates/snippets/precedents/testing.md` § 9).

## Per-runner lanes in the detectors

The table above is the overview. Each detector carries the per-stack facts it acts on, and is the place to read them:

- `skills/assertion-strength-scan` § Adapt to the codebase — the oracle-check lane, the lint rules per runner, and the version precedents that turn a hidden failure into a red test.
- `skills/suite-execution-scan` § Adapt to the codebase — the collection list per runner, focus guards, CI masks and retry gates.
- `skills/flake-source-scan` § Adapt to the codebase — the lane table — clock freezing, seed and order, network guards, leak oracles and repeat flags per runner.
- `skills/test-double-scan` § Adapt to the codebase — the lane table — typed doubles, `spec` / `autospec`, real-engine parity per stack.
- `skills/coverage-gap` § Adapt to the codebase — the coverage lane table — the coverage command and report per runner, and `diff-cover`.
- `skills/mutation-probe` § Adapt to the codebase — the lane table — the diff-scoped run, the survivor status and the trap per mutation tool.

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual test runner, mocking library, coverage thresholds, fake-timer helper, property-based runner.
- The project's `_extracted-codebase.md § Testing` — test directory layout, naming pattern (`*.test.ts` / `*_test.go` / `test_*.py`), CI gates.
- The validator script's stack-conditional checks read `PROJECT_KIND` to apply runner-specific lint hooks. **Check the runner's own key before adding one** — the guard is often already on: Vitest's is `allowOnly`, which defaults to `!process.env.CI`, so `.only` fails CI out of the box (https://vitest.dev/config/allowonly). Jest ships no equivalent config key — use `eslint-plugin-jest`'s `no-focused-tests` at error. Mocha has `--forbid-only`; Playwright `forbidOnly`. pytest has no `.only`; its analogue is `-m`/`-k` selection plus `--strict-markers`.

If your project uses a stack with no current substitution row above (e.g., Deno test, Bun test, Elixir ExUnit), add the row to your project's `_extracted-idioms.md` and the universal principles still apply.
