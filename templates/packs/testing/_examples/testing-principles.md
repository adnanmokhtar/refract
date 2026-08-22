---
name: testing-principles
kind: example
pack: testing
---

# Testing Principles

Prevents flaky suites, false-confidence coverage, and tests that pass when the code is broken. The always-loaded floor; depth lives in the pack's skills and patterns.

> **Hard rule.** Every fixed bug MUST ship with a regression test that fails on the buggy code and passes after the fix. Tests MUST be deterministic. `.only` in main, and `.skip` without owner + delete-by date, fail CI.

## Must

- No fixed layer ratio. Prove each behaviour at the **lowest level that can prove it**, and add a level only for what the level below cannot reach (real wiring, real transaction, real browser). Domain-heavy code lands unit-heavy, glue-heavy code integration-heavy — both correct. A suite whose bulk is e2e is slow and brittle whatever the code looks like.
- Budget each layer's runtime and read a breach as **mis-classification, not slowness**: a "unit" test taking ~a second is touching I/O and belongs a layer up.
- Auth, authorization, and tenant isolation have explicit tests — "wrong user" + "wrong tenant" cases, not just "happy path".
- Test names describe behaviour, not implementation: `returns 404 when order belongs to another tenant`, not `calls findOne with tenantId`.
- Arrange / Act / Assert structure visible. One concept per test.
- Freeze time with the project's fake-clock helper; never assert against the real clock. Seed RNG with a fixed value.
- Reset state between tests: clean DB, clear caches, restore mocks via the project's mock-restore primitive.

## Must not

- `.skip` without a linked issue + owner + delete-by date. Skipped tests rot.
- `.only` checked into main — fails CI, hides coverage gaps.
- Sleep-based waits: `await sleep(500)`. Use polling with `waitFor`, fake timers, or event-driven hooks.
- Real network calls in unit/integration tests. Use the project's HTTP-faking primitive / fixtures / testcontainers.
- Mocking types you own to dodge a bad API — fix the API instead. Mocks of your own code = design smell.
- Tests that pass regardless of code change. Verify with a mutation: corrupt the production logic — the test must fail.
- Snapshot tests on entire DOM trees / large objects — they catch nothing and update reflexively.
- Asserting on the same behaviour at multiple pyramid levels. Pick the lowest level that proves it.

## Should

- Prefer fakes over mocks for stateful collaborators: an in-memory repo implementing the real interface beats a per-call canned return.
- Mock at port boundaries (HTTP client, DB driver, message bus) only — never at every internal class.
- Build test data through a factory/builder — only the field under test differs from the default. No copy-pasted literals, and no shared mutable fixture (state tests write to passes in suite order, fails in isolation). Give unique fields a sequence so built instances never collide.
- Pure/total functions get property tests over their input space, not a handful of hand-picked examples — the bug is in the input you didn't type. Confirm the generator has a shrinker and the failing seed is pinned, or a counterexample is unusable.
- Use Testcontainers / docker-compose for integration tests that need a real DB / Redis — faster and more honest than mocking SQL.
- Treat coverage as a signal of **presence**, never a goal: it proves the branch RAN, and a high number carrying weak assertions is worse than a lower one carrying sharp ones, because it buys confidence the suite has not earned. What proves *strength* is a killed mutant — mutation-test the changed scope. **No fixed score is the bar**: baseline what your harness reports on a module already agreed well-tested, then ratchet; the changed scope may not land under it.

## Enforcement

- The runner's own `.only` guard, on — **check before adding one, because it is often already there**: Vitest's key is `allowOnly` and it defaults to `!process.env.CI`, so `.only` fails CI out of the box. Jest ships no equivalent config key; use a focused-test lint rule. Add a pre-commit reject where the runner has neither.
- Coverage threshold gates in CI — as a floor that may not drop, never as the definition of done.
- Mutation testing on critical modules on a cadence the suite's runtime can afford, ratcheted against its own recorded baseline.
