---
name: testing-principles
kind: example
pack: testing
---

# Testing Principles

Prevents flaky suites, false-confidence coverage, and tests that pass when the code is broken.

## Must

- Test pyramid by count: many unit (~70%), fewer integration (~20%), very few e2e (~10%). Inverted pyramid = slow CI, brittle tests.
- Time budgets: unit < 100ms each, integration < 1s, e2e < 30s. A unit test hitting the network is mis-classified.
- Every fixed bug ships with a regression test that fails on the buggy code and passes after the fix.
- Auth, authorization, and tenant isolation have explicit tests — "wrong user" + "wrong tenant" cases, not just "happy path".
- Test names describe behavior, not implementation: `it('returns 404 when order belongs to another tenant')`, not `it('calls findOne with tenantId')`.
- Arrange / Act / Assert structure visible — blank lines between phases or comments. One concept per test.
- Freeze time deterministically: `jest.useFakeTimers({ now: new Date('2026-01-01') })` / `vi.useFakeTimers()` / `freezegun` (Python). Never assert on `Date.now()` directly.
- Seed RNG with a fixed value when randomness is involved.
- Reset state between tests: clean DB, clear caches, restore mocks (`afterEach(() => jest.restoreAllMocks())`).

## Must not

- `.skip` without a linked issue + owner + delete-by date. Skipped tests rot.
- `.only` checked into main — fails CI, hides coverage gaps. Pre-commit hook should reject.
- Sleep-based waits: `await sleep(500)`. Use polling with `waitFor`, fake timers, or event-driven hooks.
- Real network calls in unit/integration tests. Use `nock` / `msw` / fixtures / testcontainers for the dependency.
- Mocking types you own to dodge a bad API — fix the API instead. Mocks of your own code = design smell.
- Tests that pass regardless of code change. Verify with a mutation: comment out the production logic — test must fail.
- Snapshot tests on entire DOM trees / large objects — they catch nothing and update reflexively. Snapshot small, intentional shapes.
- Asserting on the same behavior at multiple pyramid levels. Pick the lowest level that proves it.

## Should

- Fakes over mocks for stateful collaborators: in-memory repository implementing the real interface beats `mockRepository.findOne.mockResolvedValue(...)`.
- Mock at port boundaries (HTTP client, DB driver, message bus) — not at every internal class.
- Property-based tests (`fast-check` JS, `hypothesis` Python) for pure logic with many input shapes.
- Testcontainers / docker-compose for integration tests that need a real DB / Redis. Faster + more honest than mocking SQL.
- Coverage as a signal, not a goal: 80% line coverage with bad asserts is worse than 50% with sharp ones.

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
