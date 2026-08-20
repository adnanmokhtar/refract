---
name: testing-principles
description: Testing Principles
kind: rule
pack: testing
severity: must
applies-to: testing-track, every-code-writing-task-in-testing
---

# Testing Principles

> **Hard rule.** Every fixed bug MUST ship with a regression test that fails on the buggy code and passes after the fix. Tests MUST be deterministic — no `sleep`-based waits, no real network in unit/integration tests, no `Date.now()` assertions without fake timers. `.only` in main and `.skip` without owner + delete-by date are forbidden and fail CI.

Prevents flaky suites, false-confidence coverage, and tests that pass when the code is broken.

## Must

- Test pyramid by count: many unit (~70%), fewer integration (~20%), very few e2e (~10%). Inverted pyramid = slow CI, brittle tests.
- Time budgets: unit < 100ms each, integration < 1s, e2e < 30s. A unit test hitting the network is mis-classified.
- Every fixed bug ships with a regression test that fails on the buggy code and passes after the fix.
- Auth, authorization, and tenant isolation have explicit tests — "wrong user" + "wrong tenant" cases, not just "happy path".
- Test names describe behavior, not implementation: `it('returns 404 when order belongs to another tenant')`, not `it('calls findOne with tenantId')`.
- Arrange / Act / Assert structure visible — blank lines between phases or comments. One concept per test.
- Freeze time deterministically with the project's fake-clock helper (`jest.useFakeTimers({ now: ... })` / `vi.useFakeTimers()` / `freezegun.freeze_time(...)` / `Timecop.freeze` / `Clock.fixed(...)` / `clockwork` / framework-equivalent). Never assert on `Date.now()` / language equivalent directly.
- Seed RNG with a fixed value when randomness is involved.
- Reset state between tests: clean DB, clear caches, restore mocks via the project's mock-restore primitive (`jest.restoreAllMocks()` / `vi.restoreAllMocks()` / `unittest.mock.patch.stopall` / framework-equivalent).

## Must not

- `.skip` without a linked issue + owner + delete-by date. Skipped tests rot.
- `.only` checked into main — fails CI, hides coverage gaps. Pre-commit hook should reject.
- Sleep-based waits: `await sleep(500)`. Use polling with `waitFor`, fake timers, or event-driven hooks.
- Real network calls in unit/integration tests. Use the project's HTTP-faking primitive (`nock` / `msw` / `responses` / `httpx_mock` / `WireMock` / `httptest` / `WebMock` / framework-equivalent) / fixtures / testcontainers for the dependency.
- Mocking types you own to dodge a bad API — fix the API instead. Mocks of your own code = design smell.
- Tests that pass regardless of code change. Verify with a mutation: comment out the production logic — test must fail.
- Snapshot tests on entire DOM trees / large objects — they catch nothing and update reflexively. Snapshot small, intentional shapes.
- Asserting on the same behavior at multiple pyramid levels. Pick the lowest level that proves it.

## Should

- Prefer fakes over mocks for stateful collaborators: an in-memory repository implementing the real interface beats `mockRepository.findOne.mockResolvedValue(...)`.
- Mock at port boundaries (HTTP client, DB driver, message bus) only — never at every internal class.
- Build test data through a factory/builder with sensible defaults + per-test overrides (`FactoryBot`, `Fishery` + faker, `factory_boy`, `Instancio`, Laravel factories, hand-rolled Go builders) — only the field under test should differ from the default. No copy-pasted object literals across tests, and no shared mutable fixture (module-level / `beforeEach` state that tests write to couples them: they pass in suite order and fail in isolation). Give unique fields (email, slug, external id) a sequence so built instances never collide. See `../skills/test-factories/SKILL.md`.
- Test properties and invariants that must hold for *all* inputs — round-trip (`decode(encode(x)) == x`), idempotence, commutativity, sorted/no-dupes postconditions, or agreement with a reference oracle — with property-based tests (`fast-check` JS/TS, `hypothesis` Python, `jqwik` Java, `proptest` Rust, `rapid` Go), not a handful of hand-picked examples. A pure/total function tested only by example under-tests its input space; the bug is in the input you didn't type. Confirm the generator has a shrinker and the failing seed is pinned so counterexamples reduce and reproduce. See `../skills/property-invariants/SKILL.md`.
- Use Testcontainers / docker-compose for integration tests that need a real DB / Redis — faster + more honest than mocking SQL.
- Treat coverage as a signal, not a goal: 80% line coverage with bad asserts is worse than 50% with sharp ones.
- Measure test *strength*, not just presence, on critical code: mutation-test the changed scope (see `../skills/mutation-probe/SKILL.md`) — a survived mutant (source corrupted, suite still green) is an assertion gap, not a coverage gap. Coverage proves the branch RAN; a killed mutant proves a test would CATCH it breaking. Scope to the diff / critical modules — mutation runs are expensive.

## Review checklist

- [ ] Test fails when the production logic is reverted (mutation check).
- [ ] No `.only`, `.skip`, `xit`, `xdescribe` left in.
- [ ] No `setTimeout` / `sleep` for synchronization.
- [ ] No real HTTP, real DB, or real clock without explicit setup.
- [ ] Names describe behavior, not function calls.
- [ ] Test for the bug being fixed (if this is a bug-fix PR).
- [ ] Tenant / auth negative case present (if this is a multi-tenant project).

## Enforcement

- Jest / Vitest config: `forbidOnly: true` in CI mode.
- ESLint rules: `jest/no-focused-tests`, `jest/no-disabled-tests` (or vitest equivalents).
- Coverage threshold gates in CI (`--coverage --coverageThreshold`).
- Mutation testing periodically with Stryker (JS/TS) / mutmut (Python) on critical modules.
- Pre-commit hook rejects commits adding `.only`.
